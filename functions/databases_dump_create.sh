function dump_database() {
    local DB_NAME=$1
    local DB_USER=$2
    local DB_PASSWORD=$3
    local DB_DUMP=$4   
    ssh "$REMOTE_USER@$REMOTE_HOST" << EOF
        mkdir -p "$REMOTE_DIR/$NAME_DB_DIR"                                 # Создаём папку для дампов, если её нет        
        export MYSQL_PWD="$DB_PASSWORD"                                     # Устанавливаем пароль через переменную среды
        mysqldump --no-tablespaces -u "$DB_USER" "$DB_NAME" > "$DB_DUMP"    # Дамп базы
EOF
}

function validate_and_rename_dump() {
    local DUMP_FILE=$1
    local DB_NAME=$2
    local DB_DUMP=$3
    log "Начинается проверка корректности дампа $DUMP_FILE на удалённом сервере $REMOTE_HOST" "START"

    ssh "$REMOTE_USER@$REMOTE_HOST" <<EOF
        if [ ! -f "$DB_DUMP" ]; then
            echo "Файл $DB_DUMP не существует. Операция отменена."
        elif head -n 1 "$DB_DUMP" | grep -q "^--" && grep -q "dump" "$DB_DUMP" && tail -n 1 "$DB_DUMP" | grep -q "^-- Dump completed"; then
            echo "Дамп базы данных $DB_NAME корректен."
        else
            echo "Дамп базы данных $DB_NAME повреждён. Переименовываю файл."
            mv "$DB_DUMP" "${DB_DUMP%.*}_broken.sql"  # Переименование повреждённого дампа
        fi
EOF
    log "Завершена проверка корректности дампа дампов БД" "END"
}

function archive_dump() {    
    local DUMP_FILE_NAME=$1
    local DB_NAME=$2
    local DB_PASSWORD=$3
    local DUMP_FILE=$4
    local ARCHIVE_FILE="$DUMP_FILE.zip"
    log "Начинается архивация дампа $DUMP_FILE_NAME на удалённом сервере $REMOTE_HOST" "START"
    ssh "$REMOTE_USER@$REMOTE_HOST" <<EOF
        if [ ! -f "$DUMP_FILE" ]; then
            echo "Файл $DB_DUMP не существует. Операция отменена."
        else        
            if [ -f "$ARCHIVE_FILE" ]; then
                rm -f "$ARCHIVE_FILE"
            fi    
            zip -e -P "$DB_PASSWORD" -j "$ARCHIVE_FILE" "$DUMP_FILE" || echo "Ошибка архивирования файла $DUMP_FILE"
            rm -f "$DUMP_FILE"                                      # Удаляем временные файлы (исключая повреждённые)
        fi    
EOF
    log "Завершена архивация. Дамп базы данных $DB_NAME сохранён как зашифрованный архив" "END"
}

function create_db_dumps() {
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
        local DUMP_FILE="dump_${DB_NAME}.sql" 
        local SQL_DUMP_FILE="$REMOTE_DIR/$NAME_DB_DIR/$DUMP_FILE"

        log "Создание дампа базы данных $DB_NAME..."

        # 1. Создание дампа
        dump_database "$DB_NAME" "$DB_USER" "$DB_PASSWORD" "$SQL_DUMP_FILE"

        #2. Проверка корректности дампа
        validate_and_rename_dump "$DUMP_FILE" "$DB_NAME" "$SQL_DUMP_FILE"

        # 3. Архивация файла
        archive_dump "$DUMP_FILE" "$DB_NAME" "$DB_PASSWORD" "$SQL_DUMP_FILE"
    done
}

function run_db_backup {
    log "Начинается создание дампов баз данных на удалённом сервере $REMOTE_HOST" "START"
    create_db_dumps
    log "Завершение создания дампов БД" "END"
}