#!/usr/bin/bash
set -euo pipefail

#  configuramos
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.env"   # .env junto al script

# Valores por defecto (pueden sobreescribirse en .env o entorno)
ORIGEN="${ORIGEN:-$HOME/documentos}"
DESTINO="${DESTINO:-$HOME/backups}"
LOGDIR="${LOG:-$HOME/logs}"
SLEEP_SEC="${SLEEP_SEC:-60}"          # pausa entre iteraciones
MAX_ITERS="${MAX_ITERS:-0}"           # 0 = infinito; >0 = número de iteraciones

# Cargar configuración si existe (sobrescribe lo anterior si define variables)
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

# Aseguramos los directorios
mkdir -p "$LOGDIR" "$DESTINO" "$HOME/.cache/locks"

# Lock para evitar instancias simultáneas
LOCKFILE="$HOME/.cache/locks/respaldo.lock"
exec 200>"$LOCKFILE"
if ! flock -n 200; then
  # Usa LOGDIR (ya asegurado) para escribir este error
  echo "$(date '+%F %T') - Otra instancia en ejecución; saliendo." >> "$LOGDIR/cron_backup_errors.log"
  exit 0
fi

#  utilidades de log para no depender de LOG_FILE global
log() {
  local today_log="${LOGDIR}/respaldo_$(date +%F).log"
  echo "$(date '+%F %T') - $1" | tee -a "$today_log"
}

# Validación inicial
if [ ! -d "$ORIGEN" ]; then
  log "ERROR: El directorio de origen '$ORIGEN' no existe."
  exit 1
fi

# Función para saber si A es subruta de B (para exclusiones)
es_subruta() {
  # uso: es_subruta /ruta/hija /ruta/padre
  local h="$1" p="$2"
  [[ "$h" == "$p" ]] && return 1
  [[ "$h" == "$p"* ]] && return 0 || return 1
}

# Función de respaldo (usa timestamp por minuto)
hacer_respaldo() {
  local TS ARCHIVO tmpfile today_log
  TS="$(date +%F_%H-%M)"
  ARCHIVO="${DESTINO}/respaldo_${TS}.tar.gz"
  today_log="${LOGDIR}/respaldo_$(date +%F).log"

  log "Inicio del respaldo (iteración ${TS})"

  # Construir exclusiones si DESTINO/LOGDIR están dentro de ORIGEN
  local extra_excludes=()
  if es_subruta "$DESTINO" "$ORIGEN"; then
    extra_excludes+=( --exclude="./${DESTINO#$ORIGEN/}/*" )
  fi
  if es_subruta "$LOGDIR" "$ORIGEN"; then
    extra_excludes+=( --exclude="./${LOGDIR#$ORIGEN/}/*" )
  fi

  # Crear en /tmp y luego mover para evitar auto-incluir el tar en curso
  tmpfile="$(mktemp /tmp/respaldo_XXXXXX.tar.gz)"
  if tar -czf "$tmpfile" "${extra_excludes[@]}" -C "$ORIGEN" . 2>>"$today_log"; then
    mv "$tmpfile" "$ARCHIVO"
    log "Respaldo exitoso: $ARCHIVO"
  else
    rm -f "$tmpfile" || true
    log "ERROR: Falló la creación del respaldo"
    return 1
  fi

  log "Fin del respaldo"
}

# Manejo de señales
trap 'log "Interrumpido por señal, liberando lock y saliendo."; exit 0' INT TERM

# === BUCLE ===
# Permitir pasar iteraciones por parámetro (0 = infinito)
if [ "${1:-}" != "" ]; then
  MAX_ITERS="$1"
fi

if [ "$MAX_ITERS" -eq 0 ]; then
  while true; do
    hacer_respaldo
    sleep "$SLEEP_SEC"
  done
else
  for ((i=1; i<=MAX_ITERS; i++)); do
    log "Iteración $i de $MAX_ITERS"
    hacer_respaldo
    if [ "$i" -lt "$MAX_ITERS" ]; then
      sleep "$SLEEP_SEC"
    fi
  done
fi

