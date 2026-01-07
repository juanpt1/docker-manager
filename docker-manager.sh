#!/bin/bash
set -euo pipefail

# =============================
# Gestor de proyectos docker-compose
# =============================

# --- Colores ---
greenColor=$'\e[1;32m'
redColor=$'\e[1;31m'
blueColor=$'\e[1;34m'
yellowColor=$'\e[1;33m'
purpleColor=$'\e[1;35m'
turquoiseColor=$'\e[1;36m'
endColor=$'\e[0m'

# --- Verificar dependencias ---
for cmd in docker "docker compose"; do
  if ! command -v ${cmd%% *} &>/dev/null; then
    echo -e "${redColor}❌ Error: '${cmd}' no está instalado o no está en el PATH.${endColor}"
    exit 1
  fi
done

# --- Verificar grupo docker ---
if ! id -nG "$USER" | grep -qw "docker"; then
  echo -e "${redColor}❌ El usuario '$USER' no pertenece al grupo 'docker'.${endColor}"
  echo "👉 Agrega con: sudo usermod -aG docker $USER"
  exit 1
fi

# =============================
# VARIABLES GLOBALES
# =============================
declare -a PROJECTS=()              # Todos los proyectos descubiertos
declare -a SELECTED_PROJECTS=()     # Proyectos seleccionados para batch ops
declare -A PROJECT_SELECTION=()     # Estado de selección [project_path]=1 o 0
declare -A PROJECT_STATUS_CACHE=()  # Cache de estados
MULTI_PROJECT_MODE=false            # Modo actual
CACHE_TTL=30                        # Segundos (para cache de estados)

# =============================
# FUNCIONES DE UTILIDAD
# =============================

# --- Función para seleccionar servicios (patrón extraído) ---
select_services() {
  local PROMPT="${1:-Selecciona servicios}"
  local ALLOW_MULTIPLE="${2:-true}"

  mapfile -t SERVICES < <(docker compose config --services 2>/dev/null)

  if [ ${#SERVICES[@]} -eq 0 ]; then
    echo -e "${redColor}❌ No se encontraron servicios definidos.${endColor}" >&2
    return 1
  fi

  # Mostrar lista de servicios (esto va a stderr para no contaminar el output)
  echo -e "\n${greenColor}${PROMPT}:${endColor}\n" >&2
  for i in "${!SERVICES[@]}"; do
    echo -e "${blueColor}$((i+1))${endColor}) ${SERVICES[$i]}" >&2
  done
  echo "" >&2

  if [ "$ALLOW_MULTIPLE" = "true" ]; then
    read -rp "${yellowColor}👉 Ingresa servicios (número o nombre, separados por comas): ${endColor}" INPUT
  else
    read -rp "${yellowColor}👉 Selecciona un servicio: ${endColor}" INPUT
  fi

  # Validar que no esté vacío
  if [ -z "$INPUT" ]; then
    echo -e "${redColor}❌ No seleccionaste ningún servicio.${endColor}" >&2
    return 1
  fi

  IFS=',' read -ra SELECTED <<< "$(echo "$INPUT" | tr -d ' ')"

  local RESULT=""
  local FOUND=false

  for ITEM in "${SELECTED[@]}"; do
    # Limpiar espacios del item
    ITEM=$(echo "$ITEM" | xargs)

    # Saltar items vacíos
    if [ -z "$ITEM" ]; then
      continue
    fi

    # Si es número
    if [[ "$ITEM" =~ ^[0-9]+$ ]] && [ "$ITEM" -ge 1 ] && [ "$ITEM" -le ${#SERVICES[@]} ]; then
      local SERVICE="${SERVICES[$((ITEM-1))]}"
      RESULT="$RESULT $SERVICE"
      FOUND=true
    else
      # Verificar si el nombre coincide exactamente con algún servicio
      local MATCH_FOUND=false
      for SVC in "${SERVICES[@]}"; do
        if [ "$ITEM" = "$SVC" ]; then
          RESULT="$RESULT $ITEM"
          FOUND=true
          MATCH_FOUND=true
          break
        fi
      done

      if [ "$MATCH_FOUND" = false ]; then
        echo -e "${redColor}❌ El servicio '$ITEM' no existe en este proyecto.${endColor}" >&2
      fi
    fi
  done

  # Si no se encontró ningún servicio válido, retornar error
  if [ "$FOUND" = false ]; then
    return 1
  fi

  # SOLO retornar servicios seleccionados (esto es lo único que va a stdout)
  echo "$RESULT" | xargs
}

# =============================
# FUNCIONES DE SELECCIÓN DE PROYECTOS
# =============================

# --- Función para buscar proyectos ---
select_project() {
  echo "🔍 Buscando proyectos con docker-compose.yml en el home..."
  mapfile -t PROJECTS < <(find ~ -name "docker-compose.yml" -exec dirname {} \; 2>/dev/null)

  if [ ${#PROJECTS[@]} -eq 0 ]; then
    echo "❌ No se encontraron proyectos con docker-compose.yml"
    exit 1
  fi

  echo -e "${greenColor}📂 Proyectos encontrados:${endColor}\n"
  for i in "${!PROJECTS[@]}"; do
    echo -e "${blueColor}$((i+1))${endColor}) ${PROJECTS[$i]}"
  done
  echo ""

  while true; do
    read -rp "${yellowColor}👉 Selecciona un proyecto (número): ${endColor}" choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#PROJECTS[@]} )); then
      DIR="${PROJECTS[$((choice-1))]}"
      if ! cd "$DIR"; then
        echo -e "${redColor}❌ No se pudo acceder a $DIR${endColor}"
        exit 1
      fi
      break
    else
      echo -e "${redColor}❌ Opción inválida. Intenta de nuevo.${endColor}"
    fi
  done
}

# --- Validar servicios construidos ---
require_built() {
  local BUILT
  BUILT=$(docker compose ps -a --services 2>/dev/null)

  if [[ -z "$BUILT" ]]; then
    echo -e "${redColor}❌ No hay servicios construidos todavía.${endColor}"
    echo -e "${yellowColor}👉 Ejecuta primero: docker compose up -d --build${endColor}"
    read -rp "🔙 Presiona ENTER para regresar al menú..." dummy
    clear
    return 1
  fi
  return 0
}

# --- Mostrar estado de servicios con colores ---
check_status() {
  echo -e "Estado de los servicios:\n"
  mapfile -t DEFINED_SERVICES < <(docker compose config --services 2>/dev/null)

  if [ ${#DEFINED_SERVICES[@]} -eq 0 ]; then
    echo -e "${redColor}❌ No se encontraron servicios definidos.${endColor}"
    return 1
  fi

  local CONTAINERS
  CONTAINERS=$(docker compose ps -a --format "{{.Service}}\t{{.Image}}\t{{.Status}}")

  local BUILT_SERVICES=()
  local OUTPUT="SERVICE\tIMAGE\tSTATUS\n"

  while IFS=$'\t' read -r SERVICE IMAGE STATUS; do
    BUILT_SERVICES+=("$SERVICE")
    if [[ "$STATUS" == Up* ]]; then
      OUTPUT+="${blueColor}$SERVICE${endColor}\t${blueColor}$IMAGE${endColor}\t${greenColor}$STATUS${endColor}\n"
    elif [[ "$STATUS" == Exited* ]]; then
      OUTPUT+="${blueColor}$SERVICE${endColor}\t${blueColor}$IMAGE${endColor}\t${redColor}$STATUS${endColor}\n"
    else
      OUTPUT+="${blueColor}$SERVICE${endColor}\t${blueColor}$IMAGE${endColor}\t${yellowColor}$STATUS${endColor}\n"
    fi
  done <<< "$CONTAINERS"

  for SVC in "${DEFINED_SERVICES[@]}"; do
    if [[ ! " ${BUILT_SERVICES[*]} " =~ " $SVC " ]]; then
      OUTPUT+="${blueColor}$SVC${endColor}\t${redColor}N/A${endColor}\t${redColor}Not built${endColor}\n"
    fi
  done

  echo -e "$OUTPUT" | column -t -s $'\t'
}

# =============================
# FUNCIONES DE PORT MAPPING
# =============================

# --- Generar URL basada en servicio y puerto ---
generate_service_url() {
  local SERVICE="$1"
  local PORT="$2"
  local PROTOCOL="${3:-tcp}"

  # Pattern matching para servicios comunes
  case "$SERVICE" in
    nginx|apache|httpd|web|frontend|ui|app)
      if [ "$PORT" = "443" ] || [ "$PORT" = "8443" ]; then
        echo "https://localhost:$PORT"
      else
        echo "http://localhost:$PORT"
      fi
      ;;
    postgres|postgresql|db|database)
      echo "postgresql://localhost:$PORT"
      ;;
    mysql|mariadb)
      echo "mysql://localhost:$PORT"
      ;;
    redis|redis-*)
      echo "redis://localhost:$PORT"
      ;;
    mongodb|mongo|mongo-*)
      echo "mongodb://localhost:$PORT"
      ;;
    *)
      # Revisar puertos comunes
      case "$PORT" in
        80|8080|8000|3000|4200|5000|9000)
          echo "http://localhost:$PORT"
          ;;
        443|8443)
          echo "https://localhost:$PORT"
          ;;
        5432)
          echo "postgresql://localhost:$PORT"
          ;;
        3306)
          echo "mysql://localhost:$PORT"
          ;;
        6379)
          echo "redis://localhost:$PORT"
          ;;
        27017)
          echo "mongodb://localhost:$PORT"
          ;;
        *)
          echo "tcp://localhost:$PORT"
          ;;
      esac
      ;;
  esac
}

# --- Mostrar mapeo de puertos ---
show_port_mappings() {
  if ! require_built; then
    return 1
  fi

  echo -e "\n${greenColor}═══════════════════════════════════════${endColor}"
  echo -e "${greenColor}        Mapeo de puertos${endColor}"
  echo -e "${greenColor}═══════════════════════════════════════${endColor}\n"

  local OUTPUT="SERVICE\tCONTAINER_PORT\tHOST_PORT\tPROTOCOL\tURL\n"
  local HAS_PORTS=false

  # Obtener servicios con puertos
  while IFS=$'\t' read -r SERVICE PORTS STATUS; do
    if [ -z "$SERVICE" ]; then
      continue
    fi

    # Solo mostrar servicios en ejecución
    if [[ ! "$STATUS" == Up* ]]; then
      OUTPUT+="${blueColor}$SERVICE${endColor}\t${redColor}(stopped)${endColor}\t-\t-\t-\n"
      continue
    fi

    if [ -z "$PORTS" ] || [ "$PORTS" = "" ]; then
      OUTPUT+="${blueColor}$SERVICE${endColor}\t${yellowColor}No ports exposed${endColor}\t-\t-\t-\n"
      continue
    fi

    HAS_PORTS=true

    # Parsear mapeo de puertos: "0.0.0.0:8080->80/tcp, :::8443->443/tcp"
    # Separar por coma si hay múltiples puertos
    IFS=',' read -ra PORT_ARRAY <<< "$PORTS"

    for PORT_MAPPING in "${PORT_ARRAY[@]}"; do
      # Limpiar espacios
      PORT_MAPPING=$(echo "$PORT_MAPPING" | xargs)

      # Extraer usando regex: host:port->container_port/protocol
      if [[ "$PORT_MAPPING" =~ ([0-9]+)-\>([0-9]+)/(tcp|udp) ]]; then
        local HOST_PORT="${BASH_REMATCH[1]}"
        local CONTAINER_PORT="${BASH_REMATCH[2]}"
        local PROTOCOL="${BASH_REMATCH[3]}"

        # Generar URL
        local URL=$(generate_service_url "$SERVICE" "$HOST_PORT" "$PROTOCOL")

        OUTPUT+="${blueColor}$SERVICE${endColor}\t"
        OUTPUT+="${purpleColor}$CONTAINER_PORT${endColor}\t"
        OUTPUT+="${greenColor}$HOST_PORT${endColor}\t"
        OUTPUT+="$PROTOCOL\t"
        OUTPUT+="${turquoiseColor}$URL${endColor}\n"
      fi
    done
  done < <(docker compose ps --format "{{.Service}}\t{{.Ports}}\t{{.Status}}")

  if [ "$HAS_PORTS" = false ]; then
    echo -e "${yellowColor}No hay servicios con puertos expuestos actualmente.${endColor}\n"
  else
    echo -e "$OUTPUT" | column -t -s $'\t'
    echo ""
  fi
}

# =============================
# FUNCIONES DE LOGS
# =============================

# --- Ver logs de un servicio (simple) ---
quick_tail_logs() {
  if ! require_built; then
    return 1
  fi

  mapfile -t SERVICES < <(docker compose config --services 2>/dev/null)

  if [ ${#SERVICES[@]} -eq 0 ]; then
    echo -e "${redColor}❌ No se encontraron servicios definidos.${endColor}"
    read -rp "🔙 Presiona ENTER para continuar..." dummy
    return 1
  fi

  echo -e "\n${greenColor}Ver logs de un servicio (últimas 100 líneas)${endColor}\n"
  echo -e "${blueColor}0${endColor}) Ver logs de TODOS los servicios"

  for i in "${!SERVICES[@]}"; do
    echo -e "${blueColor}$((i+1))${endColor}) ${SERVICES[$i]}"
  done
  echo ""

  read -rp "${yellowColor}👉 Selecciona un servicio (0 para todos): ${endColor}" CHOICE

  if [ "$CHOICE" = "0" ]; then
    echo -e "\n${greenColor}Mostrando últimas 100 líneas de logs de TODOS los servicios${endColor}"
    echo -e "${yellowColor}(Presiona 'q' para salir)${endColor}\n"
    sleep 1
    docker compose logs --tail=100 2>&1 | less -R
  elif [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le ${#SERVICES[@]} ]; then
    local SELECTED_SERVICE="${SERVICES[$((CHOICE-1))]}"
    echo -e "\n${greenColor}Mostrando últimas 100 líneas de logs de: ${blueColor}$SELECTED_SERVICE${endColor}"
    echo -e "${yellowColor}(Presiona 'q' para salir)${endColor}\n"
    sleep 1
    docker compose logs --tail=100 "$SELECTED_SERVICE" 2>&1 | less -R
  else
    echo -e "${redColor}❌ Opción inválida.${endColor}"
  fi

  read -rp "🔙 Presiona ENTER para continuar..." dummy
}

# =============================
# FUNCIONES MULTI-PROJECT
# =============================

# --- Seleccionar múltiples proyectos (modo toggle interactivo) ---
select_multiple_projects() {
  if [ ${#PROJECTS[@]} -eq 0 ]; then
    echo -e "${redColor}❌ No hay proyectos disponibles.${endColor}"
    return 1
  fi

  while true; do
    clear
    echo -e "${greenColor}═══════════════════════════════════════${endColor}"
    echo -e "${greenColor}   Seleccionar múltiples proyectos (Toggle)${endColor}"
    echo -e "${greenColor}═══════════════════════════════════════${endColor}\n"

    echo "Seleccionados: ${turquoiseColor}${#SELECTED_PROJECTS[@]}${endColor} / ${blueColor}${#PROJECTS[@]}${endColor} proyectos\n"

    # Mostrar lista con checkboxes
    for i in "${!PROJECTS[@]}"; do
      local PROJECT_PATH="${PROJECTS[$i]}"
      local CHECKBOX="[ ]"

      # Verificar si está seleccionado
      if [[ " ${SELECTED_PROJECTS[*]} " =~ " $PROJECT_PATH " ]]; then
        CHECKBOX="${greenColor}[X]${endColor}"
      else
        CHECKBOX="[ ]"
      fi

      echo -e "$CHECKBOX ${blueColor}$((i+1))${endColor}) $PROJECT_PATH"
    done

    echo -e "\n${yellowColor}Comandos:${endColor}"
    echo "  - Número: Toggle selección"
    echo "  - a: Seeleccionar todos"
    echo "  - n: Limpiar selección"
    echo "  - d: Confirmar selección y salir"
    echo ""

    read -rp "${yellowColor}👉 Comando: ${endColor}" CMD

    case "$CMD" in
      [0-9]*)
        # Toggle proyecto específico
        if [ "$CMD" -ge 1 ] && [ "$CMD" -le ${#PROJECTS[@]} ]; then
          local PROJECT_PATH="${PROJECTS[$((CMD-1))]}"

          # Verificar si ya está seleccionado
          if [[ " ${SELECTED_PROJECTS[*]} " =~ " $PROJECT_PATH " ]]; then
            # Deseleccionar: remover del array
            local NEW_SELECTED=()
            for proj in "${SELECTED_PROJECTS[@]}"; do
              if [ "$proj" != "$PROJECT_PATH" ]; then
                NEW_SELECTED+=("$proj")
              fi
            done
            SELECTED_PROJECTS=("${NEW_SELECTED[@]}")
          else
            # Seleccionar: agregar al array
            SELECTED_PROJECTS+=("$PROJECT_PATH")
          fi
        else
          echo -e "${redColor}Número inválido.${endColor}"
          sleep 1
        fi
        ;;
      a|A)
        # Select all
        SELECTED_PROJECTS=("${PROJECTS[@]}")
        ;;
      n|N)
        # Clear selection
        SELECTED_PROJECTS=()
        ;;
      d|D)
        # Done
        if [ ${#SELECTED_PROJECTS[@]} -eq 0 ]; then
          echo -e "${redColor}Debes seleccionar al menos 1 proyecto.${endColor}"
          sleep 2
        else
          break
        fi
        ;;
      *)
        echo -e "${redColor}Comando inválido.${endColor}"
        sleep 1
        ;;
    esac
  done
}

# --- Mostrar estado de proyectos seleccionados ---
multi_project_status() {
  if [ ${#SELECTED_PROJECTS[@]} -eq 0 ]; then
    echo -e "${yellowColor}No hay proyectos seleccionados.${endColor}\n"
    return
  fi

  echo -e "\n${greenColor}Estado de proyectos seleccionados:${endColor}\n"
  local OUTPUT="PROJECT\tSERVICES\tRUNNING\tSTOPPED\tNOT_BUILT\n"

  for PROJECT in "${SELECTED_PROJECTS[@]}"; do
    if ! cd "$PROJECT" 2>/dev/null; then
      OUTPUT+="${blueColor}$PROJECT${endColor}\t${redColor}ERROR${endColor}\t-\t-\t-\n"
      continue
    fi

    local DEFINED_SERVICES=$(docker compose config --services 2>/dev/null)
    local DEFINED_COUNT=$(echo "$DEFINED_SERVICES" | wc -l)

    if [ "$DEFINED_COUNT" -eq 0 ]; then
      OUTPUT+="${blueColor}$PROJECT${endColor}\t0\t0\t0\t0\n"
      continue
    fi

    local RUNNING=0
    local STOPPED=0
    local NOT_BUILT=0

    while IFS=$'\t' read -r SERVICE STATUS; do
      if [ -z "$SERVICE" ]; then
        continue
      fi

      if [[ "$STATUS" == Up* ]]; then
        RUNNING=$((RUNNING + 1))
      elif [[ "$STATUS" == Exited* ]] || [[ "$STATUS" == "Created" ]]; then
        STOPPED=$((STOPPED + 1))
      fi
    done < <(docker compose ps -a --format "{{.Service}}\t{{.Status}}" 2>/dev/null)

    # Calcular not built
    local BUILT=$((RUNNING + STOPPED))
    NOT_BUILT=$((DEFINED_COUNT - BUILT))

    OUTPUT+="${blueColor}$PROJECT${endColor}\t"
    OUTPUT+="$DEFINED_COUNT\t"
    OUTPUT+="${greenColor}$RUNNING${endColor}\t"
    OUTPUT+="${yellowColor}$STOPPED${endColor}\t"
    OUTPUT+="${redColor}$NOT_BUILT${endColor}\n"
  done

  echo -e "$OUTPUT" | column -t -s $'\t'
  echo ""
}

# --- Ejecutar operación batch en múltiples proyectos ---
batch_operation() {
  local OPERATION="$1"
  shift
  local FLAGS="$@"

  if [ ${#SELECTED_PROJECTS[@]} -eq 0 ]; then
    echo -e "${redColor}❌ No hay proyectos seleccionados.${endColor}"
    return 1
  fi

  # Confirmación para operaciones destructivas
  if [ "$OPERATION" = "down" ]; then
    echo -e "${redColor}⚠ WARNING: Esta acción detendrá y eliminará contenedores${endColor}"
    echo -e "Proyectos afectados: ${yellowColor}${#SELECTED_PROJECTS[@]}${endColor}"
    read -rp "Escribe 'yes' para confirmar: " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
      echo -e "${yellowColor}Operación cancelada.${endColor}"
      return 1
    fi
  fi

  echo -e "\n${yellowColor}Ejecutando '$OPERATION' en ${#SELECTED_PROJECTS[@]} proyectos...${endColor}\n"

  local SUCCESS_COUNT=0
  local FAILED_COUNT=0
  declare -a SUCCESS_LIST=()
  declare -a FAILED_LIST=()

  for PROJECT in "${SELECTED_PROJECTS[@]}"; do
    echo -e "${blueColor}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${endColor}"
    echo -e "${turquoiseColor}Processing: $PROJECT${endColor}"

    if ! cd "$PROJECT" 2>/dev/null; then
      FAILED_COUNT=$((FAILED_COUNT + 1))
      FAILED_LIST+=("$PROJECT")
      echo -e "${redColor}  ✗ Cannot access directory${endColor}\n"
      continue
    fi

    if docker compose $OPERATION $FLAGS 2>&1; then
      SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
      SUCCESS_LIST+=("$PROJECT")
      echo -e "${greenColor}  ✓ Success${endColor}\n"
    else
      FAILED_COUNT=$((FAILED_COUNT + 1))
      FAILED_LIST+=("$PROJECT")
      echo -e "${redColor}  ✗ Failed${endColor}\n"
    fi
  done

  # Summary
  echo -e "${blueColor}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${endColor}"
  echo -e "${turquoiseColor}Resumen${endColor}"
  echo -e "${blueColor}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${endColor}"
  echo -e "${greenColor}Success: $SUCCESS_COUNT${endColor}"
  echo -e "${redColor}Failed:  $FAILED_COUNT${endColor}"

  if [ ${#FAILED_LIST[@]} -gt 0 ]; then
    echo -e "\n${redColor}Failed projects:${endColor}"
    for PROJ in "${FAILED_LIST[@]}"; do
      echo -e "  ${redColor}✗${endColor} $PROJ"
    done
  fi
  echo ""
}

# --- Menú de Multi-Project ---
multiproject_menu() {
  while [ "$MULTI_PROJECT_MODE" = "true" ]; do
    clear
    echo -e "${purpleColor}═══════════════════════════════════════${endColor}"
    echo -e "${purpleColor}         MODO MULTIPROYECTO${endColor}"
    echo -e "${purpleColor}═══════════════════════════════════════${endColor}"

    multi_project_status

    echo -e "${turquoiseColor}=== SELECCIÓN DE PROYECTOS ===${endColor}"
    echo -e "${blueColor}s${endColor}) Seleccionar/Deseleccionar Proyectos (alternar)"
    echo -e "${blueColor}a${endColor}) Seleccionar Todos los Proyectos"
    echo -e "${blueColor}n${endColor}) Limpiar Selección"

    echo -e "\n${turquoiseColor}=== OPERACIONES MASIVAS ===${endColor}"
    echo -e "${blueColor}1${endColor}) Iniciar Todos los Seleccionados"
    echo -e "${blueColor}2${endColor}) Detener Todos los Seleccionados"
    echo -e "${blueColor}3${endColor}) Reiniciar Todos los Seleccionados"
    echo -e "${blueColor}4${endColor}) Levantar Todos los Seleccionados ${purpleColor}(docker compose up -d)${endColor}"
    echo -e "${blueColor}5${endColor}) Construir Todos los Seleccionados  ${purpleColor}(docker compose up -d --build)${endColor}"
    echo -e "${blueColor}6${endColor}) Bajar Todos los Seleccionados ${purpleColor}(docker compose down)${endColor}"

    echo -e "\n${blueColor}b${endColor}) Volver al Modo Proyecto Individual"
    echo ""

    read -rp "${yellowColor}👉 Elige una opción: ${endColor}" MP_ACTION

    case "$MP_ACTION" in
      s)
        select_multiple_projects
        ;;
      a)
        SELECTED_PROJECTS=("${PROJECTS[@]}")
        echo -e "${greenColor}✓ Todos los proyectos seleccionados.${endColor}"
        sleep 1
        ;;
      n)
        SELECTED_PROJECTS=()
        echo -e "${yellowColor}Selección limpiada.${endColor}"
        sleep 1
        ;;
      1)
        batch_operation start
        read -rp "🔙 Presiona ENTER para continuar..." dummy
        ;;
      2)
        batch_operation stop
        read -rp "🔙 Presiona ENTER para continuar..." dummy
        ;;
      3)
        batch_operation restart
        read -rp "🔙 Presiona ENTER para continuar..." dummy
        ;;
      4)
        batch_operation up -d
        read -rp "🔙 Presiona ENTER para continuar..." dummy
        ;;
      5)
        batch_operation up -d --build
        read -rp "🔙 Presiona ENTER para continuar..." dummy
        ;;
      6)
        batch_operation down
        read -rp "🔙 Presiona ENTER para continuar..." dummy
        ;;
      b|B)
        MULTI_PROJECT_MODE=false
        ;;
      *)
        echo -e "${redColor}Opción inválida.${endColor}"
        sleep 1
        ;;
    esac
  done
}

# =============================
# PROGRAMA PRINCIPAL
# =============================

select_project

# --- Menú de acciones ---
while true; do
  echo -e "\nProyecto:${blueColor} $DIR ${endColor}"
  check_status
  echo -e "\n${greenColor}⚡ Acciones disponibles:${endColor}\n"

  echo -e "${blueColor} 1${endColor}) Start ${purpleColor}(docker compose start)${endColor}"
  echo -e "${blueColor} 2${endColor}) Stop ${purpleColor}(docker compose stop)${endColor}"
  echo -e "${blueColor} 3${endColor}) Ejecutar ${purpleColor}(docker compose up -d)${endColor}"
  echo -e "${blueColor} 4${endColor}) Detener ${purpleColor}(docker compose down)${endColor}"
  echo -e "${blueColor} 5${endColor}) Detener y limpiar todo ${purpleColor}(docker compose down --rmi all --volumes --remove-orphans)${endColor}"
  echo -e "${blueColor} 6${endColor}) Reiniciar ${purpleColor}(docker compose restart)${endColor}"
  echo -e "${blueColor} 7${endColor}) Construir ${purpleColor}(docker compose up -d --build)${endColor}"
  echo -e "${blueColor} 8${endColor}) Ver estadísticas de docker ${purpleColor}(docker compose stats)${endColor}"
  echo -e "${blueColor} 9${endColor}) Inspeccionar contenido del docker-compose.yml"
  echo -e "${blueColor}10${endColor}) Reiniciar un servicio específico ${purpleColor}(docker compose restart <servicio>)${endColor}"
  echo -e "${blueColor}11${endColor}) Detener un servicio específico ${purpleColor}(docker compose stop <servicio>)${endColor}"
  echo -e "${blueColor}12${endColor}) Entrar a un servicio ${purpleColor}(docker exec -it <servicio> /bin/sh | /bin/bash)${endColor}"
  echo -e "${blueColor}13${endColor}) Ver logs ${purpleColor}(ultimas 100 lineas)${endColor}"
  echo -e "${blueColor}14${endColor}) Ver puertos ${purpleColor}(visualización de puertos con URL)${endColor}"

  echo -e "\n${turquoiseColor}=== Navegación ===${endColor}"
  echo -e "${blueColor}m${endColor}) Multi-Project ${purpleColor}(gestionar múltiples proyectos)${endColor}"
  echo -e "${blueColor}c${endColor}) Cambiar de proyecto"
  echo -e "${redColor}e${endColor}) Salir\n"

  read -rp "${yellowColor}👉 Elige una opción: ${endColor}" ACTION


  case $ACTION in
    1)
      echo "🛠️ Iniciando servicios detenidos..."
      if require_built && docker compose start; then
        echo "✅ Servicios iniciados correctamente."
      else
        echo "❌ Error al iniciar servicios."
      fi
      ;;
    2)
      echo "🛠️ Deteniendo servicios sin eliminarlos..."
      if require_built && docker compose stop; then
        echo "✅ Servicios detenidos correctamente."
      else
        echo "❌ Error al detener servicios."
      fi
      ;;
    3)
      echo "🛠️ Verificando si ya están levantados..."
      RUNNING=$(docker compose ps --status running --services 2>/dev/null)
      CREATED=$(docker compose ps --all --services 2>/dev/null)

      if [ -n "$RUNNING" ]; then
        echo "✅ Los servicios ya están en ejecución."
      elif [ -n "$CREATED" ]; then
        echo "⚠️ Los servicios existen pero están detenidos. Usando 'start'..."
        if docker compose start; then
          echo "✅ Servicios iniciados correctamente."
        else
          echo "❌ Error al iniciar servicios."
        fi
      else
        echo "🛠️ Levantando servicios por primera vez..."
        if docker compose up -d; then
          echo "✅ Servicios levantados correctamente."
        else
          echo "❌ Error al levantar servicios."
        fi
      fi
      docker compose ps
      ;;
    4)
      echo "🛠️ Deteniendo servicios..."
      if docker compose down; then
        echo "✅ Servicios detenidos correctamente."
      else
        echo "❌ Error al detener servicios."
      fi
      ;;
    5)
      echo "⚠️ Esta acción eliminará contenedores, volúmenes, imágenes y redes."
      read -rp "¿Estás seguro? (y/N): " CONFIRM
      if [[ "$CONFIRM" =~ ^[yY]$ ]]; then
        echo "🛠️ Limpiando todo..."
        if docker compose down --rmi all --volumes --remove-orphans; then
          echo "✅ Proyecto limpiado completamente."
        else
          echo "❌ Error al limpiar proyecto."
        fi
      else
        echo "❌ Operación cancelada."
      fi
      ;;
    6)
      echo "🛠️ Reiniciando servicios..."
      if require_built && docker compose restart; then
        echo "✅ Servicios reiniciados correctamente."
      else
        echo "❌ Error al reiniciar servicios."
      fi
      docker compose ps
      ;;
    7)
      echo "🛠️ Reconstruyendo y levantando servicios..."
      if docker compose up -d --build; then
        echo "✅ Servicios reconstruidos y levantados."
      else
        echo "❌ Error al reconstruir servicios."
      fi
      docker compose ps
      ;;
    8)
      docker compose stats --no-stream
      ;;
    9)
      echo -e "\n🛠️ Inspeccionando docker-compose.yml en $DIR:\n"
      less docker-compose.yml
      ;;
    10)
      SELECTED_SERVICES=$(select_services "Selecciona uno o varios servicios a reiniciar" true)
      if [ $? -eq 0 ] && [ -n "$SELECTED_SERVICES" ]; then
        for SERVICE in $SELECTED_SERVICES; do
          echo "🔄 Reiniciando servicio: ${blueColor}$SERVICE${endColor}"
          if docker compose restart "$SERVICE"; then
            echo "✅ Servicio $SERVICE reiniciado correctamente."
          else
            echo "❌ Error al reiniciar servicio $SERVICE."
          fi
        done
      fi
      read -rp "🔙 Presiona ENTER para continuar..." dummy
      ;;
    11)
      SELECTED_SERVICES=$(select_services "Selecciona uno o varios servicios a detener" true)
      if [ $? -eq 0 ] && [ -n "$SELECTED_SERVICES" ]; then
        for SERVICE in $SELECTED_SERVICES; do
          echo "🛑 Deteniendo servicio: ${blueColor}$SERVICE${endColor}"
          if docker compose stop "$SERVICE"; then
            echo "✅ Servicio $SERVICE detenido correctamente."
          else
            echo "❌ Error al detener servicio $SERVICE."
          fi
        done
      fi
      read -rp "🔙 Presiona ENTER para continuar..." dummy
      ;;
    12)
      if require_built; then
        echo -e "\n${greenColor}Selecciona un servicio para entrar:${endColor}\n"
        mapfile -t SERVICES < <(docker compose ps --services --status running 2>/dev/null)

        if [ ${#SERVICES[@]} -eq 0 ]; then
          echo -e "${redColor}❌ No hay servicios en ejecución para entrar.${endColor}"
        else
          PS3="${yellowColor}👉 Elige un servicio:${endColor} "
          select SERVICE in "${SERVICES[@]}"; do
            if [ -n "$SERVICE" ]; then
              CONTAINER_ID=$(docker compose ps -q "$SERVICE")
              if [ -n "$CONTAINER_ID" ]; then
                echo "🔐 Entrando al servicio: ${blueColor}$SERVICE${endColor}"
                # Intentamos bash, si no existe usamos sh
                docker exec -it "$CONTAINER_ID" bash 2>/dev/null || docker exec -it "$CONTAINER_ID" sh
              else
                echo -e "${redColor}❌ No se encontró el contenedor del servicio $SERVICE.${endColor}"
              fi
              break
            else
              echo "Opción inválida."
            fi
          done
        fi
      fi
      ;;
    13)
      quick_tail_logs
      ;;
    14)
      show_port_mappings
      read -rp "🔙 Presiona ENTER para continuar..." dummy
      ;;
    m)
      MULTI_PROJECT_MODE=true
      multiproject_menu
      ;;
    c)
      select_project
      ;;
    e)
      echo "👋 Saliendo..."
      exit 0
      ;;
    *)
      echo "Opción inválida."
      ;;
  esac
done
