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


  echo -e "\n${blueColor}c) Cambiar de proyecto${endColor}"
  echo -e "${redColor}e) Salir${endColor}\n"

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
      echo -e "\n${greenColor}Selecciona uno o varios servicios a reiniciar (número o nombre, separados por comas):${endColor}\n"
      mapfile -t SERVICES < <(docker compose config --services 2>/dev/null)

      if [ ${#SERVICES[@]} -eq 0 ]; then
        echo "❌ No se encontraron servicios definidos en este proyecto."
      else
        echo "Servicios disponibles:"
        for i in "${!SERVICES[@]}"; do
          echo -e "${blueColor}$((i+1))${endColor}) ${SERVICES[$i]}"
        done
        echo ""
        read -rp "${yellowColor}👉 Ingresa servicios (ej: 1,db,3): ${endColor}" INPUT

        IFS=',' read -ra SELECTED <<< "$(echo "$INPUT" | tr -d ' ')"

        for ITEM in "${SELECTED[@]}"; do
          # Si es número
          if [[ "$ITEM" =~ ^[0-9]+$ ]] && [ "$ITEM" -ge 1 ] && [ "$ITEM" -le ${#SERVICES[@]} ]; then
            SERVICE="${SERVICES[$((ITEM-1))]}"
          else
            SERVICE="$ITEM"
          fi

          if [[ " ${SERVICES[*]} " =~ " $SERVICE " ]]; then
            echo "🔄 Reiniciando servicio: ${blueColor}$SERVICE${endColor}"
            if docker compose restart "$SERVICE"; then
              echo "✅ Servicio $SERVICE reiniciado correctamente."
            else
              echo "❌ Error al reiniciar servicio $SERVICE."
            fi
          else
            echo -e "${redColor}❌ El servicio '$ITEM' no existe en este proyecto.${endColor}"
          fi
        done
      fi
      ;;
    11)
      echo -e "\n${greenColor}Selecciona uno o varios servicios a detener (número o nombre, separados por comas):${endColor}\n"
      mapfile -t SERVICES < <(docker compose config --services 2>/dev/null)

      if [ ${#SERVICES[@]} -eq 0 ]; then
        echo "❌ No se encontraron servicios definidos en este proyecto."
      else
        echo "Servicios disponibles:"
        for i in "${!SERVICES[@]}"; do
          echo -e "${blueColor}$((i+1))${endColor}) ${SERVICES[$i]}"
        done
        echo ""
        read -rp "${yellowColor}👉 Ingresa servicios (ej: 1,redis,2): ${endColor}" INPUT

        IFS=',' read -ra SELECTED <<< "$(echo "$INPUT" | tr -d ' ')"

        for ITEM in "${SELECTED[@]}"; do
          if [[ "$ITEM" =~ ^[0-9]+$ ]] && [ "$ITEM" -ge 1 ] && [ "$ITEM" -le ${#SERVICES[@]} ]; then
            SERVICE="${SERVICES[$((ITEM-1))]}"
          else
            SERVICE="$ITEM"
          fi

          if [[ " ${SERVICES[*]} " =~ " $SERVICE " ]]; then
            echo "🛑 Deteniendo servicio: ${blueColor}$SERVICE${endColor}"
            if docker compose stop "$SERVICE"; then
              echo "✅ Servicio $SERVICE detenido correctamente."
            else
              echo "❌ Error al detener servicio $SERVICE."
            fi
          else
            echo -e "${redColor}❌ El servicio '$ITEM' no existe en este proyecto.${endColor}"
          fi
        done
      fi
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
