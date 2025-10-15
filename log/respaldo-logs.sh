#!/usr/bin/bash

# === CONFIGURACIÓN ===
CONFIG_FILE="./.env"


# Cargar configuración si existe
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

# Variables con valores por defecto si no están definidas
ORIGEN="${ORIGEN:-$HOME/documentos}"
DESTINO="${DESTINO:-$HOME/backups}"
LOG="${LOG:-$HOME/logs}"


FECHA=$(date +%F)
LOG_FILE="${LOG}/respaldo_$FECHA.log"
ARCHIVO="$DESTINO/respaldo_$FECHA.tar.gz"

# Función de log
log() {
    echo "$(date '+%F %T') - $1" | tee -a "$LOG_FILE"
}

# === INICIO DEL SCRIPT ===
log "Inicio del respaldo"

# Verificar si el directorio de origen existe
if [ ! -d "$ORIGEN" ]; then
    log "ERROR: El directorio de origen '$ORIGEN' no existe."
    exit 1
fi

# Crear destino si no existe
mkdir -p "$LOG" || {
    log "ERROR: No se pudo crear el directorio log '$LOG'."
    exit 1
}


# Crear destino si no existe
mkdir -p "$DESTINO" || {
    log "ERROR: No se pudo crear el directorio destino '$DESTINO'."
    exit 1
}

# Crear el respaldo sin ruta completa
tar -czf "$ARCHIVO" -C "$ORIGEN" . 2>>"$LOG_FILE"

# Verificar si el archivo se creó
if [ $? -eq 0 ]; then
    log "Respaldo exitoso: $ARCHIVO"
else
    log "ERROR: Falló la creación del respaldo"
    exit 1
fi

log "Fin del respaldo"

