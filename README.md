# Docker compose manager

Un script Bash interactivo para encontrar y administrar proyectos que usan `docker-compose.yml` dentro del directorio HOME. Proporciona un menú de operaciones comunes (start/stop/up/down/restart/build/enter) con salida coloreada, monitoreo de recursos y utilidades de inspección.

## Propósito

Facilitar la administración de proyectos docker-compose desde la terminal sin recordar comandos largos. Ideal para desarrolladores y DevOps que manejan varios proyectos locales y requieren monitoreo de recursos.

## Requisitos

- Linux o macOS con Bash (probado en Bash 4+)
- Docker instalado y funcionando
  - Asegúrate de que el comando `docker` esté disponible en el PATH
  - El script requiere `docker compose` (Docker Compose V2 incluido en el binario `docker`)
- El usuario debe pertenecer al grupo `docker` o ejecutar el script con privilegios que permitan ejecutar Docker
- Herramientas adicionales:
  - `column` y `less` (para formatear salida e inspeccionar archivos)
  - `find` (para descubrir proyectos)

## Ubicación del script

Coloca `docker-manager.sh` en el directorio que prefieras y dale permisos de ejecución:

```bash
chmod +x /ruta/a/docker-manager.sh
```

## Uso

Inicia el script desde la terminal:

```bash
./docker-manager.sh
```

Al ejecutarlo, el script buscará en el directorio HOME (`~`) proyectos que contengan un `docker-compose.yml` y mostrará un **menú principal dinámico** con las siguientes opciones:

### Menú Principal Inicial

**Modos de Operación:**
1. **Gestionar Proyecto Individual** - Seleccionar y gestionar un proyecto específico
2. **Modo Multi-Proyecto** - Gestionar múltiples proyectos simultáneamente

**Información:**
- **l) Listar proyectos disponibles** - Ver todos los proyectos encontrados
- **e) Salir** - Cerrar el script

Una vez seleccionado un modo, el script mostrará el menú correspondiente con todas las acciones disponibles:

### Operaciones de Proyecto Individual

| Opción | Acción | Comando Docker |
|--------|--------|----------------|
| 1 | Start | `docker compose start` |
| 2 | Ejecutar | `docker compose up -d` |
| 3 | Construir | `docker compose up -d --build` |
| 4 | Stop | `docker compose stop` |
| 5 | Detener | `docker compose down` |
| 6 | Limpiar todo | `docker compose down --rmi all --volumes --remove-orphans` |
| 7 | Reiniciar | `docker compose restart` |
| 8 | Reiniciar servicio | `docker compose restart <servicio>` |
| 9 | Detener servicio | `docker compose stop <servicio>` |
| 10 | Entrar a servicio | `docker exec -it <container> bash/sh` |
| 11 | Build + Start servicio | `docker compose up -d --build <servicio>` |
| 12 | Down servicio | `docker compose down <servicio>` |
| 13 | Ver logs | Últimas 100 líneas de logs |
| 14 | Exportar logs | Guardar logs en archivo .log con timestamp |
| 15 | Ver puertos | Mapeo de puertos |
| 16 | Métricas | `docker compose stats` con visualización avanzada |
| 17 | Ver docker-compose.yml | Inspeccionar archivo yml |
| 18 | Escanear seguridad | Trivy - análisis de vulnerabilidades |
| m | Multi-Project | Gestionar múltiples proyectos |
| c | Cambiar proyecto | Volver al menú principal |
| e | Salir | Cerrar el script |

### Navegación

- **m) Modo Multi-Proyecto** - Gestionar múltiples proyectos simultáneamente:
  - Selección interactiva con checkboxes [X] / [ ]
  - Operaciones batch: start, stop, restart, up, down, build
  - Ejecución secuencial con reporte de éxito/fallo
  - Vista de estado agregado de proyectos seleccionados

- **c) Cambiar de proyecto** - Volver al menú principal
- **e) Salir** - Cerrar el script

## Ejemplos rápidos

### Flujo de Trabajo Típico

1. **Inicio**: Ejecutar `./docker-manager.sh`
2. **Menú Principal**: El script busca proyectos y muestra opciones
3. **Seleccionar Modo**:
   - Opción `1` para proyecto individual
   - Opción `2` para multi-proyecto
   - Opción `l` para listar todos los proyectos

### Casos de Uso - Proyecto Individual

**Desarrollo diario:**
- Levantar servicios: Opción `2` (docker compose up -d)
- Ver logs en tiempo real: Opción `13` → seleccionar servicio
- Reiniciar servicio específico: Opción `8` → seleccionar servicio
- Entrar a contenedor: Opción `10` → seleccionar servicio

**Diagnóstico y troubleshooting:**
- Ver puertos expuestos: Opción `15`
- Ver métricas de recursos: Opción `16`
- Revisar logs: Opción `13`
- Exportar logs para análisis: Opción `14` → seleccionar servicio o todos

**Monitoreo DevOps:**
- Métricas de recursos (CPU/RAM/Red/I/O): Opción `16`
  - Barras de progreso visuales con colores
  - Umbrales de alerta (verde/amarillo/rojo)
  - Detección automática de servicios críticos
  - Resumen general con promedios

**Mantenimiento:**
- Reconstruir tras cambios: Opción `3` (docker compose up -d --build)
- Limpiar todo: Opción `6` (confirmar con `y`)
- Reiniciar todos los servicios: Opción `7`

### Casos de Uso - Multi-Proyecto

**Gestión batch:**
1. Menú principal → Opción `2`
2. Seleccionar proyectos: Opción `s` → toggle checkboxes → `d` (done)
3. Ejecutar operación:
   - Iniciar todos: Opción `1`
   - Detener todos: Opción `2`
   - Actualizar todos: Opción `5`

**Monitoreo agregado:**
- Ver estado de múltiples proyectos en una tabla
- Identificar proyectos con servicios detenidos
- Operaciones batch con confirmación para acciones destructivas

## Seguridad y permisos

- Ejecutar Docker como root o con `sudo` puede tener implicaciones de seguridad. Preferible añadir tu usuario al grupo `docker`:

```bash
sudo usermod -aG docker $USER
```

Después de eso cierra y vuelve a abrir tu sesión para que el cambio surta efecto.

## Errores comunes y soluciones

- "No está instalado o no está en el PATH": instala Docker o corrige tu PATH.
- "El usuario no pertenece al grupo 'docker'": agrega el usuario al grupo `docker` o ejecuta con `sudo`.
- "No se encontraron proyectos con docker-compose.yml": coloca un `docker-compose.yml` en alguno de tus proyectos dentro de `HOME` o modifica el script para buscar en otra ruta.
- Si `docker compose` no reconoce subcomandos, verifica que estés usando Docker con Compose V2 (integrado en `docker`) o instala `docker-compose` por separado.

## Limitaciones conocidas

- El script busca únicamente archivos llamados `docker-compose.yml` en el HOME. No soporta otros nombres ni rutas personalizadas sin editar el script.
- Asume que los servicios definidos en el `docker-compose.yml` se corresponden con los nombres que `docker compose` reporta.
- La detección de shells dentro del contenedor intenta `bash` y cae a `sh` si `bash` no existe; contenedores muy mínimos podrían no tener ninguna shell interactiva.

## Capacidades para DevOps

### Exportación de Logs (Opción 14)

Exporta logs de servicios a archivos `.log` con timestamp para análisis posterior o respaldo:

```
✅ Logs exportados correctamente
   Archivo: mi-proyecto_web_20240115_143245.log
   Tamaño: 1.2M
   Líneas: 15432
   Ruta: /home/user/proyectos/mi-proyecto/mi-proyecto_web_20240115_143245.log
```

**Características:**
- **Formato de nombre**: `{proyecto}_{servicio}_{timestamp}.log`
- **Timestamp**: Formato `YYYYMMDD_HHMMSS` para ordenamiento cronológico
- **Información post-exportación**: Muestra archivo, tamaño, líneas y ruta completa
- **Selección flexible**: Exportar todos los servicios o uno específico
- **Sin colores**: Usa `--no-color` para logs limpios

**Usos prácticos:**
- Respaldar logs antes de reiniciar contenedores
- Compartir logs con el equipo para debugging
- Análisis offline de errores
- Auditoría

### Escaneo de Seguridad con Trivy (Opción 18)

Análisis de vulnerabilidades en imágenes Docker usando Trivy:

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🔒 ESCÁNER DE SEGURIDAD TRIVY                             ║
╚══════════════════════════════════════════════════════════════════════════════╝

┌──────────────────────────────────────────────────────────────────────────────┐
│ 📦 Escaneando: nginx:latest                                                   │
├──────────────────────────────────────────────────────────────────────────────┤
│  ⚠ Vulnerabilidades encontradas: 45                                          │
│    ■ CRITICAL: 2                                                              │
│    ■ HIGH:     8                                                              │
│    ■ MEDIUM:   20                                                             │
│    ■ LOW:      15                                                             │
└──────────────────────────────────────────────────────────────────────────────┘

╔══════════════════════════════════════════════════════════════════════════════╗
║                         📊 RESUMEN GENERAL                                    ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  Imágenes escaneadas:    3                                                    ║
║  Total vulnerabilidades: 127                                                  ║
║  ⚠ ESTADO: CRÍTICO - Se requiere atención inmediata                          ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

**Características:**
- **Detección automática de Trivy**: Muestra instrucciones de instalación si no está instalado
- **Escaneo selectivo**: Todas las imágenes o una específica
- **Tres tipos de reporte**:
  - Resumen: Solo conteo de vulnerabilidades por severidad
  - Detallado: Tabla completa de CVEs con paginación (Library, CVE-ID, Severity, Fixed Version, Title)
  - Solo Críticos: Filtra solo CRITICAL y HIGH para atención inmediata
- **Información de CVE completa**: ID, severidad, versión instalada, versión corregida, descripción
- **Clasificación por severidad**: CRITICAL, HIGH, MEDIUM, LOW, UNKNOWN
- **Estado de seguridad**: Indicador visual del estado general
- **Exportación**: Formato TXT legible o JSON nativo de Trivy

**Opciones de exportación:**
- **TXT**: Reporte legible con resumen y detalles
- **JSON**: Formato nativo de Trivy para integración con CI/CD

**Usos prácticos:**
- Auditoría de seguridad antes de despliegues
- Identificar imágenes que necesitan actualización
- Cumplimiento de políticas de seguridad
- Integración en pipelines de CI/CD

**Requisitos:**
- Trivy instalado (`trivy --version` para verificar)
- Opcional: `jq` para mejor parsing de resultados

### Monitoreo de Recursos (Opción 16)

Visualización avanzada de métricas con colores, umbrales de alerta y modo tiempo real:

**Modos de visualización:**
- **1) Snapshot**: Captura única del estado actual
- **2) Tiempo real**: Actualización automática cada 2 segundos (Ctrl+C para salir)

```
[TIEMPO REAL] 2024-01-15 14:32:45 - Ctrl+C para salir

╔══════════════════════════════════════════════════════════════════════════════╗
║                    📊 MÉTRICAS DE RECURSOS                                   ║
╚══════════════════════════════════════════════════════════════════════════════╝

Leyenda: █ Normal (<50%)  █ Advertencia (50-80%)  █ Crítico (>80%)

┌──────────────────────────────────────────────────────────────────────────────┐
│ 📦 proyecto-web-1                                                            │
├──────────────────────────────────────────────────────────────────────────────┤
│  CPU:    █░░░░░░░░░░░░░░░░░░░░░░░░ 0.27%                                     │
│  RAM:    █░░░░░░░░░░░░░░░░░░░░░░░░ 0.01% (3.78MiB / 31.25GiB)                 │
│  NET:    ↓ 1.42MB ↑ 892kB                                                    │
│  DISK:   R 12.3MB W 0B                                                       │
└──────────────────────────────────────────────────────────────────────────────┘

╔══════════════════════════════════════════════════════════════════════════════╗
║                         📈 RESUMEN GENERAL                                   ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  Servicios monitoreados: 7                                                   ║
║  CPU promedio:           0.45%                                               ║
║  RAM promedio:           0.12%                                               ║
║  CPU total acumulado:    3.15%                                               ║
║  RAM total acumulado:    0.84%                                               ║
║  ✓ Todos los servicios dentro de parámetros normales                        ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

**Características:**
- **Barras de progreso visuales**: Mínimo 1 carácter cuando hay uso (aunque sea 0.01%)
- **Código de colores por umbrales**:
  - Verde: Normal (CPU <50%, RAM <60%)
  - Amarillo: Advertencia (CPU 50-80%, RAM 60-85%)
  - Rojo: Crítico (CPU >80%, RAM >85%)
- **Soporte para decimales**: Muestra valores precisos (0.27%, 0.01%)
- **Modo tiempo real**: Monitoreo continuo con actualización cada 2 segundos
- **Detección automática de servicios críticos**: Alerta cuando un servicio supera umbrales
- **Resumen general**: Promedios, totales acumulados y estado global

**Usos prácticos:**
- Monitoreo en tiempo real durante despliegues o pruebas de carga
- Identificar cuellos de botella de forma visual
- Detectar memory leaks antes de que sean críticos
- Planificar escalamiento basado en datos reales

### Multi-Proyecto para DevOps

Ideal para gestionar entornos completos (dev, staging, prod):

```bash
# Actualizar todos los entornos
Menú principal → 2 (Multi-Proyecto) → s (seleccionar) → a (todos) → 5 (build all)

# Verificar estado de todos los proyectos
Menú principal → 2 → Estado agregado automático
```

## Personalización rápida

- **Ruta de búsqueda**: Modifica la función `discover_projects()` para cambiar dónde buscar proyectos
- **Colores**: Modifica las variables de color al inicio del script
- **Comandos adicionales**: Agrega nuevas opciones al menú editando `project_menu()`

## Referencia de Comandos Docker

El script utiliza los siguientes comandos de Docker Compose. Esta sección sirve como referencia rápida para entender qué hace cada comando internamente.

### Comandos de Gestión del Ciclo de Vida

```bash
# Iniciar servicios existentes (contenedores ya creados pero detenidos)
docker compose start
docker compose start <servicio>      # Iniciar servicio específico

# Detener servicios sin eliminar contenedores
docker compose stop
docker compose stop <servicio>       # Detener servicio específico

# Reiniciar servicios (stop + start)
docker compose restart
docker compose restart <servicio>    # Reiniciar servicio específico

# Crear y arrancar contenedores en modo detached (background)
docker compose up -d

# Detener y eliminar contenedores, redes creadas por 'up'
docker compose down

# Detener y eliminar un servicio específico
docker compose down <servicio>

# Limpieza completa: eliminar contenedores, imágenes, volúmenes y huérfanos
docker compose down --rmi all --volumes --remove-orphans
```

### Comandos de Construcción

```bash
# Construir imágenes de todos los servicios
docker compose build

# Construir imagen de un servicio específico
docker compose build <servicio>

# Construir y levantar servicios (reconstruir si hay cambios)
docker compose up -d --build

# Construir y levantar un servicio específico
docker compose up -d --build <servicio>
```

### Comandos de Información y Estado

```bash
# Listar servicios definidos en docker-compose.yml
docker compose config --services

# Listar contenedores del proyecto (todos los estados)
docker compose ps -a

# Listar contenedores en ejecución
docker compose ps

# Listar solo servicios en ejecución
docker compose ps --services --status running

# Obtener información formateada de contenedores
docker compose ps --format "{{.Service}}\t{{.Image}}\t{{.Status}}"
docker compose ps --format "{{.Service}}\t{{.Ports}}\t{{.Status}}"

# Obtener ID de contenedor de un servicio
docker compose ps -q <servicio>
```

### Comandos de Logs

```bash
# Ver logs de todos los servicios (últimas N líneas)
docker compose logs --tail=100

# Ver logs de un servicio específico
docker compose logs --tail=100 <servicio>

# Seguir logs en tiempo real
docker compose logs -f
docker compose logs -f <servicio>
```

### Comandos de Monitoreo

```bash
# Ver estadísticas en tiempo real (interactivo)
docker compose stats

# Ver estadísticas una sola vez (snapshot)
docker compose stats --no-stream
```

### Comandos de Ejecución

```bash
# Ejecutar comando en contenedor existente (interactivo con TTY)
docker exec -it <container_id> bash
docker exec -it <container_id> sh

# Ejemplo: entrar a shell del contenedor
docker exec -it $(docker compose ps -q web) /bin/bash
```

### Descripción de Flags Comunes

| Flag | Descripción |
|------|-------------|
| `-d` | Detached mode: ejecutar en background |
| `-a` | All: incluir contenedores detenidos |
| `-q` | Quiet: solo mostrar IDs |
| `-f` | Follow: seguir output en tiempo real |
| `--build` | Reconstruir imágenes antes de iniciar |
| `--no-stream` | Snapshot único (no actualizar en tiempo real) |
| `--tail=N` | Mostrar últimas N líneas de logs |
| `--rmi all` | Eliminar todas las imágenes |
| `--volumes` | Eliminar volúmenes asociados |
| `--remove-orphans` | Eliminar contenedores huérfanos |
| `-it` | Interactive + TTY (para shells interactivas) |
| `--format` | Formato personalizado de salida (Go templates) |

### Notas Importantes

- **Docker Compose V2**: El script requiere `docker compose` (V2, integrado) NO `docker-compose` (V1, standalone)
- **Proyecto**: Docker Compose determina el proyecto por el directorio donde se ejecuta
- **Servicios vs Contenedores**: Un servicio puede tener múltiples contenedores (replicas)
- **Formato de Puertos**: Docker reporta puertos como `0.0.0.0:8080->80/tcp`

## Contribuir

Si quieres mejorar el script:

1. Haz un fork.
2. Crea una rama con un nombre descriptivo.
3. Abre un Pull Request con la descripción de los cambios.
