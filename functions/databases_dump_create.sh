function dump_database() {
    local DB_NAME=$1
    local DB_USER=$2
    local DB_PASSWORD=$3
    local DUMP_FILE="dump_${DB_NAME}.sql"

    ssh "$REMOTE_USER@$REMOTE_HOST" << EOF
        mkdir -p "$REMOTE_DIR/$NAME_DB_DIR"                                  # Создаём папку для дампов, если её нет
        export MYSQL_PWD="$DB_PASSWORD"                                     # Устанавливаем пароль через переменную среды
        mysqldump --no-tablespaces -u "$DB_USER" "$DB_NAME" > "$DUMP_FILE"  # Дамп базы
EOF
    echo "$DUMP_FILE"
}

function validate_and_rename_dump() {
    local DUMP_FILE=$1
    local DB_NAME=$2

    ssh "$REMOTE_USER@$REMOTE_HOST" << EOF
        if head -n 1 "$DUMP_FILE" | grep -q "^-- MySQL dump" && tail -n 1 "$DUMP_FILE" | grep -q "^-- Dump completed"; then
            echo "Дамп базы данных $DB_NAME корректен."
        else
            echo "Дамп базы данных $DB_NAME повреждён. Переименовываю файл."
            mv "$DUMP_FILE" "${DUMP_FILE%.*}_broken.sql"                     # Переименование повреждённого дампа
        fi
EOF
}

function archive_dump() {
    local DUMP_FILE=$1
    local DB_NAME=$2
    local DB_PASSWORD=$3
    local ARCHIVE_FILE="$REMOTE_DIR/$NAME_DB_DIR/dump_${DB_NAME}.zip"

    ssh "$REMOTE_USER@$REMOTE_HOST" << EOF
        zip -e -P "$DB_PASSWORD" "$ARCHIVE_FILE" "$DUMP_FILE" || echo "Ошибка архивирования файла $DUMP_FILE"
        rm -f "$DUMP_FILE"                                                  # Удаляем временные файлы (исключая повреждённые)
EOF
    echo "$ARCHIVE_FILE"
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

        log "Создание дампа базы данных $DB_NAME..."

        # 1. Создание дампа
        DUMP_FILE=$(dump_database "$DB_NAME" "$DB_USER" "$DB_PASSWORD")

        # 2. Проверка корректности дампа
        #validate_and_rename_dump "$DUMP_FILE" "$DB_NAME"

        # 3. Архивация файла
        #ARCHIVE_FILE=$(archive_dump "$DUMP_FILE" "$DB_NAME" "$DB_PASSWORD")

        log "Дамп базы данных $DB_NAME сохранён как зашифрованный архив $ARCHIVE_FILE"
    done
}

function run_db_backup {
    log "Начинается создание дампов баз данных на удалённом сервере $REMOTE_HOST" "START"
    create_db_dumps
    log "Завершение создания дампов БД" "END"
}