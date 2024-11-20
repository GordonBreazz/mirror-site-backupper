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
    log "Начинается очистка старых дампов баз данных на удалённом сервере..."

    ssh "$REMOTE_USER@$REMOTE_HOST" bash <<EOF
        # Проверяем, существует ли папка с дампами
        if [ -d "$REMOTE_DIR/$NAME_DB_DIR" ]; then
            # Удаляем только файлы, начинающиеся с 'dump_' и заканчивающиеся на '.sql'
            find "$REMOTE_DIR/$NAME_DB_DIR" -type f -name "dump_*.sql" -exec rm -f {} \;
            if [ \$? -eq 0 ]; then
                echo "Очистка завершена: все файлы с префиксом 'dump_' удалены из $REMOTE_DIR/$NAME_DB_DIR."
            else
                echo "Ошибка: не удалось удалить файлы с префиксом 'dump_' в $REMOTE_DIR/$NAME_DB_DIR."
            fi
        else
            echo "Папка $REMOTE_DIR/$NAME_DB_DIR не найдена."
        fi
EOF
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
function create_db_dumps {
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

function run_db_backup {
    log "Начинается задача создания бекапов баз данных" "START"
    create_db_dumps
    log "Завершена задача создания бекапов баз данных" "END"
}