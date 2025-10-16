#!/usr/bin/bash
set -euo pipefail

# aquí se muestra la configuración
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.env"         # .env al lado del script
ORIGEN="${ORIGEN:-$HOME/documentos}"
DESTINO="${DESTINO:-$HOME/backups}"
LOGDIR="${LOG:-$HOME/logs}"

# Cargamos la configuración si existe
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

# Aseguramos los directorios
mkdir -p "$LOGDIR" "$DESTINO" "$HOME/.cache/locks"

# Lock (sin root). (en dado caso de usar root), se usara /var/lock/respaldo.lock
LOCKFILE="$HOME/.cache/locks/respaldo.lock"
exec 200>"$LOCKFILE"
if ! flock -n 200; then
  echo "$(date '+%F %T') - Otra instancia en ejecución; saliendo." >> "$LOGDIR/cron_backup_errors.log"
  exit 0
fi
# Desde aquí ya funciona el lock. y se libera al salir/cerrar FD 200.

FECHA="$(date +%F)"
LOG_FILE="${LOGDIR}/respaldo_${FECHA}.log"
ARCHIVO="${DESTINO}/respaldo_${FECHA}.tar.gz"

log() { echo "$(date '+%F %T') - $1" | tee -a "$LOG_FILE"; }

log "Inicio del respaldo"

# Validamos el origen
if [ ! -d "$ORIGEN" ]; then
  log "ERROR: El directorio de origen '$ORIGEN' no existe."
  exit 1
fi

# Crear el tar sin prefijos de ruta y se imprimira si se hizo correctamente
if tar -czf "$ARCHIVO" -C "$ORIGEN" . 2>>"$LOG_FILE"; then
  log "Respaldo exitoso: $ARCHIVO"
else
  log "ERROR: Falló la creación del respaldo"
  exit 1
fi

log "Fin del respaldo"
