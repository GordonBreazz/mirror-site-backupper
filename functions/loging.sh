# Функция логирования
function log() {
    # Если статус не указан, используем INFO по умолчанию
    local status="${2:-INFO}"

    # Формируем сообщение с меткой времени
    local message="$(date +"%Y-%m-%d %H:%M:%S") - $status - $1"

    # Отправляем сообщение в лог-файл и на экран
    echo "$message" | tee -a "$MAIN_LOG_FILE"
}

# Функция для записи успехов в лог
function log_success() {
    log "$1" "SUCCESS"
}

# Функция для записи ошибок в лог
function log_error() {
    local message="$(date +"%Y-%m-%d %H:%M:%S") - ERROR - $1"     # Формируем сообщение с меткой времени
    echo "$message" | tee -a "$ERROR_LOG_FILE" "$MAIN_LOG_FILE"   # Отправляем сообщение в лог-файл и на экран    
}

# Функция для записи работы RSYNC в лог
function log_rsync() {
    local message="$(date +"%Y-%m-%d %H:%M:%S") - RSYNC - $1"     # Формируем сообщение с меткой времени
    echo "$message" | tee -a "$RSYNC_LOG_FILE"                    # Отправляем сообщение в лог-файл и на экран    
}