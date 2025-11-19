# Docker Manager - gestor de proyectos docker-compose

Un script Bash interactivo para encontrar y administrar proyectos que usan `docker-compose.yml` dentro del directorio HOME. Proporciona un menú de operaciones comunes (start/stop/up/down/restart/build/enter) con salida coloreada y utilidades de inspección.

## Propósito

Facilitar la administración de proyectos docker-compose desde la terminal sin recordar comandos largos. Ideal para desarrolladores que manejan varios proyectos locales.

<img width="1466" height="828" alt="image" src="https://github.com/user-attachments/assets/8a2c95ef-ada8-4ac2-9d16-e41ca5e57611" />



## Requisitos

- Linux o macOS con Bash (probado en Bash 4+).
- Docker instalado y funcionando.
  - Asegúrate de que el comando `docker` esté disponible en el PATH.
  - El script también requiere la subcomando `docker compose` (Docker Compose V2 incluido en el binario `docker`).
- El usuario debe pertenecer al grupo `docker` o ejecutar el script con privilegios que permitan ejecutar Docker (por ejemplo, `sudo`).
- `column` y `less` son opcionales pero recomendados (el script usa `column` para formatear la salida y `less` para inspeccionar `docker-compose.yml`).

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

Al ejecutarlo, el script buscará en el directorio HOME (`~`) proyectos que contengan un `docker-compose.yml` y te pedirá seleccionar uno. Una vez seleccionado, mostrará el estado de los servicios y un menú interactivo con las siguientes acciones:

1) Start (docker compose start)
2) Stop (docker compose stop)
3) Ejecutar (docker compose up -d)
4) Detener (docker compose down)
5) Detener y limpiar todo (docker compose down --rmi all --volumes --remove-orphans)
6) Reiniciar (docker compose restart)
7) Construir (docker compose up -d --build)
8) Ver estadísticas (docker compose stats --no-stream)
9) Inspeccionar `docker-compose.yml` (abre con `less`)
10) Reiniciar servicios específicos (por número o nombre)
11) Detener servicios específicos (por número o nombre)
12) Entrar a un servicio en ejecución (intenta `bash`, sino `sh`)

Además ofrece atajos:
- `c` para cambiar de proyecto.
- `e` para salir.

## Ejemplos rápidos

- Levantar todos los servicios (si no existen, ejecuta `docker compose up -d`):
  - Selecciona la opción 3.

- Reconstruir y levantar (útil tras cambios en Dockerfile):
  - Selecciona la opción 7.

- Entrar a un contenedor en ejecución:
  - Selecciona la opción 12, elige el servicio y el script abrirá una shell dentro del contenedor.

- Limpiar todo (elimina imágenes y volúmenes):
  - Selecciona la opción 5 y confirma con `y` cuando se te pida.

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

## Personalización rápida

- Cambiar la ruta de búsqueda: modifica la llamada `find ~ -name "docker-compose.yml"` en el script.
- Añadir más comandos: edita el menú y añade nuevas opciones ejecutando los comandos Docker que necesites.

## Contribuir

Si quieres mejorar el script:

1. Haz un fork.
2. Crea una rama con un nombre descriptivo.
3. Abre un Pull Request con la descripción de los cambios.
