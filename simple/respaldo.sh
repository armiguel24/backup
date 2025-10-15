#!/usr/bin/bash

# Cargar configuración desde archivo .env si existe
CONFIG_FILE="./.env"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

# Asignar valores por defecto si no están en el .env
FECHA=$(date +%F%T)
ORIGEN="${ORIGEN:-$HOME/documentos}"
DESTINO="${DESTINO:-$HOME/backups}"
ARCHIVO="$DESTINO/respaldo_$FECHA.tar.gz"

# Crear carpeta destino si no existe
mkdir -p "$DESTINO"

# Crear respaldo
tar -czf "$ARCHIVO" -C "$ORIGEN" .

# Mensaje de salida
echo "Respaldo creado en: $ARCHIVO"

