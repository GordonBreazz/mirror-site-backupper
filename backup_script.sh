#!/bin/bash
set -uo pipefail

### ============================================================
### БЛОК НАСТРОЕК СКРИПТА
### ============================================================

## Параметры на локальной машине
LOCAL_DIR_PATH="$HOME/backup"              # Корень для бэкапов — домашняя папка
                                            # ТЕКУЩЕГО пользователя, под которым
                                            # запущен скрипт (переносимо между
                                            # серверами/пользователями без правки)
NAME_LOCAL_DIR="production-backup"         # Название локальной папки бэкапа

## Путь к приватному SSH-ключу.
## Оставьте пустым (""), чтобы скрипт нашёл ключ сам (см. detect_ssh_key
## в functions/connection.sh) — так безопаснее для переносимого скрипта,
## который разные люди будут ставить под разными пользователями.
## Если нужен конкретный ключ — ЛУЧШЕ указать его в credentials.conf
## (это конфиг конкретного развёртывания), а не здесь.
SSH_KEY_PATH="${SSH_KEY_PATH:-}"

NAME_MIRROR_DIR="site-mirror"              # Зеркало сайтов; дампы БД (REMOTE_DUMP_DIR)
                                            # приезжают сюда же, т.к. лежат внутри REMOTE_ROOT_DIR
NAME_LOGS_DIR="logs"                       # Логи
NAME_MAIN_LOG_FILE="backup.log"
NAME_ERROR_LOG_FILE="backup_error.log"
NAME_RSYNC_LOG_FILE="rsync.log"
NAME_CREDENTIALS_FILE="credentials.conf"

## Производные пути (не менять руками)
LOCAL_DIR="$LOCAL_DIR_PATH/$NAME_LOCAL_DIR"
BACKUP_DIR="$LOCAL_DIR/$NAME_MIRROR_DIR"
LOGS_DIR="$LOCAL_DIR/$NAME_LOGS_DIR"
MAIN_LOG_FILE="$LOGS_DIR/$NAME_MAIN_LOG_FILE"
ERROR_LOG_FILE="$LOGS_DIR/$NAME_ERROR_LOG_FILE"
RSYNC_LOG_FILE="$LOGS_DIR/$NAME_RSYNC_LOG_FILE"
CREDENTIALS_FILE="./$NAME_CREDENTIALS_FILE"
DATE=$(date +"%Y%m%d_%H%M%S")

## SSH-мультиплексирование: ключ ко всей переделке.
## Все ssh/rsync вызовы ниже переиспользуют ЭТО ОДНО соединение
## вместо того, чтобы каждый раз стучаться на сервер заново.
SSH_CONTROL_DIR="/tmp/backup-ssh-ctrl"
SSH_CONTROL_PATH="$SSH_CONTROL_DIR/%r@%h:%p"
SSH_CONNECT_TIMEOUT=15

source "$CREDENTIALS_FILE"   # REMOTE_USER, REMOTE_HOST, REMOTE_PORT,
                              # REMOTE_ROOT_DIR, DATABASES[] (declare -A)

## Папка под дампы БД на удалённом сервере — ВСЕГДА подпапка
## REMOTE_ROOT_DIR, вычисляется автоматически. Указывать её отдельно
## в credentials.conf не нужно и не нужно следить, что она "внутри"
## корня — так и так будет внутри.
NAME_REMOTE_DUMP_DIR="_db_dumps_tmp"
REMOTE_DUMP_DIR="${REMOTE_ROOT_DIR%/}/$NAME_REMOTE_DUMP_DIR"

## Подключение функций
source ./functions/logging.sh
source ./functions/connection.sh
source ./functions/databases_dump_create.sh
source ./functions/rsync_files_copy.sh

### ============================================================
### ИНИЦИАЛИЗАЦИЯ
### ============================================================

function init() {
    mkdir -p "$LOCAL_DIR" "$BACKUP_DIR" "$LOGS_DIR" "$SSH_CONTROL_DIR"
    : > "$MAIN_LOG_FILE"

    if [ ! -f "$CREDENTIALS_FILE" ]; then
        log_error "Не найден файл \"$CREDENTIALS_FILE\" с настройками подключения."
        exit 1
    fi

    if [ "${#DATABASES[@]}" -eq 0 ]; then
        log_error "Массив DATABASES пуст — нечего дампить."
        exit 1
    fi

    # Если SSH_KEY_PATH не задан явно (ни в этом файле, ни в
    # credentials.conf) — пытаемся определить ключ автоматически.
    if [ -z "$SSH_KEY_PATH" ]; then
        SSH_KEY_PATH=$(detect_ssh_key) || exit 1
        log "SSH_KEY_PATH не задан явно, автоопределён: $SSH_KEY_PATH"
    fi

    if [ ! -f "$SSH_KEY_PATH" ]; then
        log_error "Приватный ключ не найден по пути \"$SSH_KEY_PATH\". Укажите верный путь в SSH_KEY_PATH (в credentials.conf)."
        exit 1
    fi
}

### ============================================================
### ЗАПУСК
### ============================================================

init

log "Открываю управляющее SSH-соединение (ControlMaster)" "START"
open_ssh_master
# Гарантируем закрытие соединения при любом выходе из скрипта,
# в т.ч. по ошибке — чтобы сокеты не копились.
trap close_ssh_master EXIT

check_connection || { log_error "Удалённый сервер недоступен, прерываю."; exit 1; }
log "Соединение установлено, будет переиспользовано для всех операций" "END"

log "Дамп баз данных (все БД одним удалённым сеансом)" "START"
run_db_backup
log "Дамп баз данных завершён" "END"

log "Копирование корня сайтов, включая дампы БД (rsync поверх того же соединения)" "START"
run_files_download
log "Копирование файлов завершено" "END"

log "Бэкап завершён успешно: $DATE"
exit 0
