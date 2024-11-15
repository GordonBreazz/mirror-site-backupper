# Функция проверки доступности удалённого сервера
function check_connection() {
    log "Проверка доступности удалённого сервера"
    if ping -c 1 "$REMOTE_HOST" &> /dev/null; then
        log_success "Соединение с сервером $REMOTE_HOST успешно установлено."
    else
        log_error "Ошибка: Сервер $REMOTE_HOST недоступен. Проверьте подключение."
        exit 1
    fi
}