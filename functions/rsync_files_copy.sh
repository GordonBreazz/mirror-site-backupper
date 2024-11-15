
# Функция для копирования файлов сайта и дампов баз данных на локальный сервер
function run_files_download {
    log "Начинается копирование файлов сайтов и дампов баз данных..." "START"

    #rsync -avz --progress -e ssh "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/" "$BACKUP_DIR/" 2>&1 | while IFS= read -r line; do
    #    log_rsync "$line"
    #done

    rsync -avz --progress -e ssh "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/" "$BACKUP_DIR/" --log-file="$RSYNC_LOG_FILE"

    # Проверка успешности копирования
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log_success "Бекап завершён успешно. Файлы и дампы сохранены в $BACKUP_DIR"
        log "Список скопированных файлов записан в $RSYNC_LOG_FILE" "INFO"
        $ISFIRST=0
    else
        #echo "Ошибка: бекап не выполнен." | tee -a "$LOGS_FILE"
        log_error "Ошибка: бекап не выполнен."
        exit 1
    fi
    log "Завершение копирования файлов" "END"
}