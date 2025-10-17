#Scripts para entrega de los tres ejercicios
# Script respaldo-cron.sh

Primer paso, para poder ubicar el archivo correspondiente, es entrar en backup que esta dentro del bash; se que se debió posicionar en el bash pero al momento de trabajar en crear el script de respaldo-log.sh lo hice en la ruta final del backup.

Segundo paso, se tomo como respaldo el script respaldo-log.sh y se hicieron ciertas modificaciones:
* lockfile (~/.cache/locks/respaldo.lock) esta parte la usamos para impedir instancias simultáneas.
* .env externo: se carga la configuración opción desde ./.env (junto al script) para ORIGEN/DESTINO/LOGDIR  sin editar el código.
* Rutas por defecto: define valores por defecto si .env no existe ($HOME/documentos, $HOME/backups, $HOME/logs).
* La creación de carpetas:asegura LOGDIR, DESTINO y la carpeta de locks.
* Loggins consistente: crea LOF_FILE por día ()respaldo_YYYY_MM-DD.log) y usamos tee -a para mostrar mensajes en pantalla y archivo.

#Funciona de esta manera

Modo seguro
set -euo pipefail
-e: si un comando falla, sale.
-u: usar variable no definida = error.
pipefail: si cualquier comando de un pipe falla, cuenta como fallo.
Descubre su carpeta y carga .env
SCRIPT_DIR=… y CONFIG_FILE="$SCRIPT_DIR/.env"
Si existe .env, hace source (sobrescribiendo ORIGEN/DESTINO/LOGDIR con lo que pongas ahí).
Valores por defecto
Si .env no define algo, usa:
ORIGEN=$HOME/documentos, DESTINO=$HOME/backups, LOGDIR=$HOME/logs.
Crea las carpetas necesarias
mkdir -p "$LOGDIR" "$DESTINO" "$HOME/.cache/locks"
Prevención de instancias simultáneas
Abre FD 200 sobre el lockfile y ejecuta flock -n 200.
Si ya hay otra ejecución, escribe un aviso en cron_backup_errors.log y sale.
Nombres de log y respaldo
FECHA=$(date +%F) (solo día)
LOG_FILE="$LOGDIR/respaldo_$FECHA.log"
ARCHIVO="$DESTINO/respaldo_$FECHA.tar.gz" (ojo: se sobreescribe en el mismo día).
Función log()
Imprime timestamp + mensaje en pantalla y lo anexa al log del día (tee -a "$LOG_FILE").
Valida el origen
Si ORIGEN no existe → registra error y termina.
Crea el respaldo
tar -czf "$ARCHIVO" -C "$ORIGEN" .
(empaqueta el contenido de ORIGEN sin prefijos de ruta).
Si tar sale bien → “Respaldo exitoso”. Si falla → “ERROR” y termina.
Fin

Registra “Fin del respaldo” y sale.
El lock se libera automáticamente al salir (cierre de FD 200).

añadimos esta parte en el script abrimos con nano. * * * * * /usr/bin/bash -lc '/home/mig78debian/ejemplos-basicos/bash/backup/ejercicio/respaldo-cron.sh >> /home/mig78debian/logs/cron_backup_runner.log 2>&1'

le damos permisos chmod +x respaldo-cron.sh
lo ejecutamos con ./respaldo-cron.sh

Para ver si se esta ejecutando crontab -l y 


# Script ciclo-respaldo.sh

para que funcuone el cron incluimos algo como esto al usar crontab -e como en el anterior
* * * * * /usr/bin/bash -lc '/ruta/completa/ciclo-respaldo.sh >> /home/mig78debian/logs/cron_backup_runner.log 2>&1'

Bucle controlado por variables:
MAX_ITERS=0 → bucle infinito (cada SLEEP_SEC seg).
MAX_ITERS>0 → corre N veces y termina.
También acepta el número por parámetro (p. ej. ./ciclo-respaldo.sh 3).

flock anti-reentrancia: evita múltiples instancias simultáneas con ~/.cache/locks/respaldo.lock.

.env: variables externas (ORIGEN, DESTINO, LOG, SLEEP_SEC, MAX_ITERS) sin tocar el código.

Logging robusto: log() calcula el archivo del día en cada llamada (ya no depende de LOG_FILE, así evitas el error “variable sin asignar” con set -u).

Respaldo con timestamp por minuto: respaldo_YYYY-MM-DD_HH-MM.tar.gz (no se sobreescribe dentro del mismo día).
Evita auto-incluir el .tar en curso: crea en /tmp con mktemp y luego mv al destino.

Exclusiones automáticas si DESTINO o LOGDIR están dentro de ORIGEN (usa es_subruta y --exclude relativos).
Manejo de señales (trap) para loguear interrupciones y liberar el lock limpiamente.
Modo estricto: set -euo pipefail en todo el script.


Funciona de la siguiente manera:

Modo seguro
set -euo pipefail: cualquier error aborta; variables no definidas fallan; los pipes respetan fallos intermedios.

Carga de configuración

Detecta su carpeta: SCRIPT_DIR=….

Si existe ./.env, lo sourcea: puede sobreescribir ORIGEN, DESTINO, LOGDIR, SLEEP_SEC, MAX_ITERS.

Prepara directorios
mkdir -p "$LOGDIR" "$DESTINO" "$HOME/.cache/locks" para que nada falle por rutas inexistentes.

Antidoble-ejecución (flock)

Abre el lockfile en FD 200 y hace flock -n 200.

Si ya hay otra instancia, registra en cron_backup_errors.log y sale.

El lock se libera al terminar el proceso (o por trap).

Logger

log() no depende de variables globales frágiles; siempre escribe en "$LOGDIR/respaldo_YYYY-MM-DD.log" y también imprime en pantalla (tee -a).

Validación

Si ORIGEN no existe, lo reporta y termina.

Detección de subrutas

es_subruta hijo padre comprueba si DESTINO o LOGDIR están dentro de ORIGEN para armar exclusiones relativas correctas.

Función hacer_respaldo()

Arma un timestamp a minuto: TS="$(date +%F_%H-%M)".

Define ARCHIVO="${DESTINO}/respaldo_${TS}.tar.gz".

Construye extra_excludes si corresponde (por ejemplo --exclude ./destino/*).

Crea el tar en /tmp (mktemp) para que no se auto-incluya aunque DESTINO esté bajo ORIGEN.

Si tar OK → mv al destino y log “Respaldo exitoso”. Si falla → borra temporal y log “ERROR”.

trap de señales

Ante INT/TERM, registra mensaje y sale limpiamente (liberando el lock).

Bucle de ejecución

Si pasas un número como parámetro, sobreescribe MAX_ITERS.

MAX_ITERS=0 → while true; do …; sleep SLEEP_SEC; done.

MAX_ITERS>0 → for ((i=1;i<=MAX_ITERS;i++)) con sleep entre iteraciones (menos en la última).

De igual manera le damos permisos a chmod +x ciclo-respaldo.sh
y ejecutamos ./ciclo-respaldo.sh

usamos crontab -e y crontab -l
