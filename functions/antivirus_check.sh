function scan_file_list {
    log "Начинается проверка обновлённых файлов (дельты) в $BACKUP_DIR на вирусы..."

    # Путь к файлу лога для результатов сканирования
    VIRUS_SCAN_LOG="$LOGS_DIR/virus_scan_$DATE.log"
    local scanned_count=0
    local infected_count=0

    # Проверяем, существует ли файл UPDATED_FILES_LIST
    if [[ ! -f "$UPDATED_FILES_LIST" ]]; then
        log_error "Ошибка: файл $UPDATED_FILES_LIST не найден. Невозможно выполнить сканирование."
        return 1
    fi

    if [[ ! -s "$UPDATED_FILES_LIST" ]]; then
        log_error "Ошибка: файл $UPDATED_FILES_LIST пуст. Сканирование пропущено."
        return 1
    fi

    # Создаём каталог для заражённых файлов, если его нет
    mkdir -p "$LOCAL_DIR/infected_files"
    if [[ ! -w "$LOCAL_DIR/infected_files" ]]; then
        log_error "Ошибка: каталог для заражённых файлов $LOCAL_DIR/infected_files недоступен для записи."
        return 1
    fi

    # Сканирование файлов
     clamscan  --file-list="$LOGS_DIR/update_files.txt" --log="$VIRUS_SCAN_LOG" --move="$LOCAL_DIR/infected_files"


    # Итоговый результат
    if [[ $infected_count -eq 0 ]]; then
        log_success "Проверка завершена: все $scanned_count файлов чисты."
    else
        log_error "Проверка завершена: из $scanned_count файлов $infected_count заражены. Подробности в $VIRUS_SCAN_LOG."
    fi
}


# Функция для сканирования директории BACKUP_DIR на вирусы
function scan_dir() {
    # Убедитесь, что передана директория для сканирования
    if [ -z "$1" ]; then
        log_error "Ошибка: не указана директория для сканирования."
        return 1
    fi

    log "Начинается проверка директории $1 на вирусы..." "START"

    # Путь к файлу лога для результатов сканирования
    VIRUS_SCAN_LOG="$LOGS_DIR/virus_scan_$DATE.log"

    # Создаём директорию для бэкапов инфицированных файлов, если её нет
    mkdir -p "$BACKUP_DIR/infected_files"

    # Запуск сканирования с использованием ClamAV
    # Логируем результат работы clamscan
    clamscan -r "$1" --log="$VIRUS_SCAN_LOG" --move="$BACKUP_DIR/infected_files" --recursive

    log "Завершена проверка директории $1 на вирусы..." "END"

    # Проверка статуса сканирования
    if [ $? -eq 0 ]; then
        log_success "Проверка завершена: вирусы не обнаружены."
    else
        log_error "Внимание: обнаружены вирусы. Подробности в $VIRUS_SCAN_LOG."
    fi
}

## Запуск антивируса

function run_antivirus() {
    # Обновление баз данных ClamAV
    log "Обновление баз данных ClamAV..."
    freshclam --verbose > "$LOGS_DIR/freshclam_output.log" 2>&1

    if [[ "$IS_FIRST" -eq 1 ]]; then
        # Если бекап первый, то вызываем функцию scan_dir
        scan_dir $DELTA_DIR
    else
        # Иначе бекап инкрементальный, вызываем функцию scan_file_list
        scan_file_list        
fi     
}