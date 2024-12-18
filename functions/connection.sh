# Функция проверки доступности удалённого сервера
function check_connection() {
    log "Проверка доступности удалённого сервера $REMOTE_HOST"
    
    # Проверка доступности сервера по сети через ping
    if ping -c 1 "$REMOTE_HOST" &> /dev/null; then
        log_success "Сервер $REMOTE_HOST доступен в сети."
    else
        log_error "Ошибка: Сервер $REMOTE_HOST недоступен. Проверьте подключение."
        exit 1
    fi

    # Проверка возможности подключения по SSH
    log "Проверка возможности подключения по SSH к серверу \"$REMOTE_HOST\""
    if ssh -o BatchMode=yes -o ConnectTimeout=5 -i "$SSH_KEY_PATH" "$REMOTE_USER@$REMOTE_HOST" exit &> /dev/null; then
        log_success "Успешно выполнено подключение по SSH пользователем \"$REMOTE_USER\" к серверу \"$REMOTE_HOST\"."
    else
        log_error "Не удалось подключиться по SSH к серверу \"$REMOTE_HOST\" пользователем \"$REMOTE_USER\"."
        exit 1
    fi
}
