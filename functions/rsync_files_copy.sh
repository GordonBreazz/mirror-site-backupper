
# Функция для копирования файлов сайта и дампов баз данных на локальный сервер
function run_files_download {
    # Проверка переменных
    if [ -z "$REMOTE_USER" ] || [ -z "$REMOTE_HOST" ] || [ -z "$REMOTE_DIR" ] || [ -z "$BACKUP_DIR" ]; then
        log_error "Одна или несколько переменных не заданы. Проверьте настройки."
        exit 1
    fi

    log "Очистка файла лога RSYNC"
    # Очистка RSYNC log
    > "$RSYNC_LOG_FILE"

    # Получение размера удаленного каталога
    log "Подсчет размера удаленного каталога $REMOTE_DIR..." "INFO"
    REMOTE_SIZE=$(ssh "$REMOTE_USER@$REMOTE_HOST" "du -sb $REMOTE_DIR | cut -f1")
    if [ -z "$REMOTE_SIZE" ]; then
        log_error "Не удалось определить размер удаленного каталога $REMOTE_DIR."
        exit 1
    fi
    log "Размер удаленного каталога: $REMOTE_SIZE байт." "INFO"

    # Копирование файлов
    START_TIME=$(date +%s)
    rsync -avz --progress -e ssh "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/" "$BACKUP_DIR/" --log-file="$RSYNC_LOG_FILE"
    RSYNC_EXIT_CODE=$?

    if [ $RSYNC_EXIT_CODE -ne 0 ]; then
        log_error "Ошибка rsync: $(tail -n 5 "$RSYNC_LOG_FILE")"
        exit 1
    fi

    # Получение размера локального каталога
    log "Подсчет размера локального каталога $BACKUP_DIR..." "INFO"
    LOCAL_SIZE=$(du -sb "$BACKUP_DIR" | cut -f1)
    if [ -z "$LOCAL_SIZE" ]; then
        log_error "Не удалось определить размер локального каталога $BACKUP_DIR."
        exit 1
    fi
    log "Размер локального каталога: $LOCAL_SIZE байт." "INFO"

    # Проверка разницы размеров
    SIZE_DIFFERENCE=$((REMOTE_SIZE - LOCAL_SIZE))
    
    if [ $SIZE_DIFFERENCE -lt 0 ]; then
        SIZE_DIFFERENCE=0
    fi

    if [ ${SIZE_DIFFERENCE#-} -gt $RSYNC_MAX_SIZE_DIFFERENCE ]; then # 10 мегабайт в байтах
        log_error "Копирование прошло неудачно: разница в размерах более 10 MB."
        log "Разница в размере: ${SIZE_DIFFERENCE} байт." "ERROR"
        #exit 1
    fi

    END_TIME=$(date +%s)
    log_success "Бекап завершён успешно за $((END_TIME - START_TIME)) секунд. Файлы сохранены в $BACKUP_DIR"
    log "Список скопированных файлов записан в $RSYNC_LOG_FILE" "INFO"
}