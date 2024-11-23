# Функция для проверки целостности дампа
function check_dump_integrity {
    local dump_file="$1"
    local integrity_result

    # Выполняем проверку целостности на удалённом сервере и сохраняем результат
    integrity_result=$(ssh "$REMOTE_USER@$REMOTE_HOST" bash <<EOF
        # Проверяем первую и последнюю строки дампа на корректность
        if head -n 1 "$dump_file" | grep -q "^-- MySQL dump" && tail -n 1 "$dump_file" | grep -q "^-- Dump completed"; then
            echo "valid"
        else
            # Если дамп повреждён, переименуем файл, добавив суффикс '_broken'
            mv "$dump_file" "${dump_file%.*}_broken.sql"
            echo "invalid"
        fi
EOF
    )

    # Обработка результата на локальной стороне
    if [ "$integrity_result" == "valid" ]; then
        log_success "Дамп $dump_file успешно прошёл проверку."
    elif [ "$integrity_result" == "invalid" ]; then
        log_error "Ошибка: дамп $dump_file повреждён и был переименован на удалённом сервере в ${dump_file%.*}_broken.sql."
    else
        log_error "Ошибка: не удалось проверить целостность дампа $dump_file. Проверьте соединение и доступность файла."
    fi
}

# Функция для очистки старых дампов баз данных на удалённом сервере
function cleanup_db_dumps {
    log "Начинается очистка временых файлоы дампов баз данных на удалённом сервере..." "START"

    ssh "$REMOTE_USER@$REMOTE_HOST" bash <<EOF
        # Проверяем, существует ли папка с дампами
        if [ -d "$REMOTE_DIR/$NAME_DB_DIR" ]; then
            # Удаляем файлы, соответствующие маскам
            find "$REMOTE_DIR/$NAME_DB_DIR" -type f \( -name "dump_*.sql" -o -name "dump_*.zip" \) -delete
            if [ \$? -eq 0 ]; then
                echo "Очистка завершена: файлы с префиксом 'dump_' и расширениями '.sql' или '.zip' удалены из $REMOTE_DIR/$NAME_DB_DIR."
            else
                echo "Ошибка: не удалось удалить файлы с префиксом 'dump_' в $REMOTE_DIR/$NAME_DB_DIR."
            fi
        else
            echo "Папка $REMOTE_DIR/$NAME_DB_DIR не найдена."
        fi
EOF
    log "Очистка временых файлоы дампов дампов баз данных завершена." "END"
}

# Функция записи результатов очистки в локальный лог-файл
function cleanup_and_log {
    cleanup_result=$(cleanup_db_dumps)

    # Логируем результат очистки
    if [[ $cleanup_result == *"завершена"* ]]; then
        log_success "Очистка папки $REMOTE_DIR/$NAME_DB_DIR завершена успешно."
    elif [[ $cleanup_result == *"Ошибка"* ]]; then
        log_error "Ошибка: Очистка папки $REMOTE_DIR/$NAME_DB_DIR завершена с ошибкой."
    else
        log_error "Папка $REMOTE_DIR/$NAME_DB_DIR не найдена на удалённом сервере."
    fi
}

# Функция для создания дампов баз данных
function create_db_dumps_row {
    log "Начинается создание дампов баз данных на удалённом сервере $REMOTE_HOST" "START"

    # Проверка, что массив DATABASES существует и содержит данные
    echo $DATABASES
    if [ -z "${DATABASES[*]}" ]; then
        log_error "Ошибка: Массив DATABASES не определён или пуст. Проверьте файл $CREDENTIALS_FILE." "ERROR"
        exit 1
    fi

    # Обработка массива с данными для подключения к базам данных
    for DB_NAME in "${!DATABASES[@]}"; do
        DB_CREDENTIALS="${DATABASES[$DB_NAME]}"
        DB_USER="${DB_CREDENTIALS%%:*}"         # Извлекаем пользователя
        DB_PASSWORD="${DB_CREDENTIALS#*:}"      # Извлекаем пароль

        log "Создание дампа базы данных $DB_NAME..."
        
        DUMP_FILE="$REMOTE_DIR/$NAME_DB_DIR/dump_${DB_NAME}.sql"

        # Запуск дампа базы данных на удалённом сервере
        ssh "$REMOTE_USER@$REMOTE_HOST" << EOF
            mkdir -p "$REMOTE_DIR/$NAME_DB_DIR"                 # Создаём папку для дампов, если её нет
            export MYSQL_PWD="$DB_PASSWORD"                 # Устанавливаем пароль через переменную среды
            mysqldump --no-tablespaces -u "$DB_USER" "$DB_NAME" > "$DUMP_FILE" # Дамп базы
EOF
       # Проверка успешности дампа
        if [ $? -eq 0 ]; then
            log_success "Дамп базы данных $DB_NAME завершён успешно в файл $DUMP_FILE."
            # Проверка целостности дампа
            check_dump_integrity "$DUMP_FILE"
        else
            log_error "Ошибка: дамп базы данных $DB_NAME не выполнен."
            exit 1
        fi
    done
    log "Завершение создания дампов БД" "END"
}

function create_db_dumps {
    # Проверка, что массив DATABASES существует и содержит данные
    if [ -z "${DATABASES[*]}" ]; then
        log_error "Ошибка: Массив DATABASES не определён или пуст. Проверьте файл $CREDENTIALS_FILE." "ERROR"
        exit 1
    fi

    # Обработка массива с данными для подключения к базам данных
    for DB_NAME in "${!DATABASES[@]}"; do
        DB_CREDENTIALS="${DATABASES[$DB_NAME]}"
        DB_USER="${DB_CREDENTIALS%%:*}"         # Извлекаем пользователя
        DB_PASSWORD="${DB_CREDENTIALS#*:}"      # Извлекаем пароль

        log "Создание дампа базы данных $DB_NAME..."
        
        DUMP_FILE="dump_${DB_NAME}.sql"
        ARCHIVE_FILE="$REMOTE_DIR/$NAME_DB_DIR/dump_${DB_NAME}.zip"

        # Запуск дампа базы данных на удалённом сервере
        ssh "$REMOTE_USER@$REMOTE_HOST" << EOF
            mkdir -p "$REMOTE_DIR/$NAME_DB_DIR"                                  # Создаём папку для дампов, если её нет
            export MYSQL_PWD="$DB_PASSWORD"                                     # Устанавливаем пароль через переменную среды
            mysqldump --no-tablespaces -u "$DB_USER" "$DB_NAME" > "$DUMP_FILE"  # Дамп базы

            # Проверка корректности дампа
            if head -n 1 "$DUMP_FILE" | grep -q "^-- MySQL dump" && tail -n 1 "$DUMP_FILE" | grep -q "^-- Dump completed"; then
                echo "Дамп базы данных $DB_NAME корректен."
                zip -e -P "$DB_PASSWORD" "$ARCHIVE_FILE" "$DUMP_FILE"            # Создаём зашифрованный ZIP-архив с паролем
            else
                echo "Дамп базы данных $DB_NAME повреждён. Переименовываю файл."
                mv "$DUMP_FILE" "${DUMP_FILE%.*}_broken.sql"                     # Переименование повреждённого дампа
            fi
            
            rm -f "$DUMP_FILE"                                                  # Удаляем временные файлы (исключая повреждённые)
EOF
    
        log "Дамп базы данных $DB_NAME сохранён как зашифрованный архив $ARCHIVE_FILE"
    done
}

function run_db_backup {
    log "Начинается создание дампов баз данных на удалённом сервере $REMOTE_HOST" "START"
    create_db_dumps
    log "Завершение создания дампов БД" "END"
}