
function scan_file_list {
    log "Начинается проверка файлов в $BACKUP_DIR на вирусы..."

    # Путь к файлу лога для результатов сканирования
    VIRUS_SCAN_LOG="$LOGS_DIR/virus_scan_$DATE.log"

    # Создаём директорию для бэкапов, если её нет
    mkdir -p "$LOCAL_DIR/infected_files"

    # Обновление баз данных ClamAV (если необходимо)
    freshclam

    # Параллельное сканирование файлов из UPDATED_FILES_LIST
    cat "$UPDATED_FILES_LIST" | while IFS= read -r file; do
        # Проверка существования файла
        if [ -f "$file" ]; then
            # Запуск сканирования каждого файла в отдельном процессе
            echo $file
            clamscan "$file" --log="$VIRUS_SCAN_LOG" --move="$BACKUP_DIR/infected_files"  --no-summary --cachedir="$BACKUP_DIR/clamav_cache"
        else
            log "Файл $file не существует, пропускаем сканирование."
        fi
    done

    # Ожидание завершения всех процессов
    wait

    # Проверка статуса сканирования
    if [ $? -eq 0 ]; then
        log_success "Проверка завершена: вирусы не обнаружены."
    else
        log_error "Внимание: обнаружены вирусы. Подробности в $VIRUS_SCAN_LOG."
    fi
}

# Функция для сканирования директории BACKUP_DIR на вирусы
function scan_dir() {
    log "Начинается проверка файлов в $BACKUP_DIR на вирусы..."

    # Путь к файлу лога для результатов сканирования
    VIRUS_SCAN_LOG="$BACKUP_DIR/$NAME_LOGS_DIR/virus_scan_$DATE.log"

    # Создаём директорию для бэкапов, если её нет
    mkdir -p "$BACKUP_DIR/infected_files"

    # Запуск сканирования с использованием ClamAV
    clamscan -r "$1" --log="$VIRUS_SCAN_LOG" --move="$BACKUP_DIR/infected_files"

    # Проверка статуса сканирования
    if [ $? -eq 0 ]; then
        log_success "Проверка завершена: вирусы не обнаружены."
    else
        log_error "Внимание: обнаружены вирусы. Подробности в $VIRUS_SCAN_LOG."
    fi
}

function run_antivirus() {
    if [[ "$IS_FIRST" -eq 1 ]]; then
        # Если бекап первый, то вызываем функцию scan_dir
        scan_dir
    else
        # Иначе бекап инкрементальный, вызываем функцию scan_file_list
        scan_file_list
fi     
}