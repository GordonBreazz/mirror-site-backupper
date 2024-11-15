# Функция для создания файла update_files.txt с абсолютными путями к скопированным файлам
function extract_copied_files {
    # Убедимся, что файл rsync.log существует
    if [ ! -f "$RSYNC_LOG_FILE" ]; then
        log "Ошибка: Файл $RSYNC_LOG_FILE не найден. Невозможно создать список обновлённых файлов." "ERROR"
        return 1
    fi

    if [ ! -s "$RSYNC_LOG_FILE" ]; then
        log_error "Ошибка: Файл $RSYNC_LOG_FILE пуст."
        return 1
    fi

    # Очищаем файл update_files.txt перед записью
    > "$UPDATED_FILES_LIST"

    # Извлекаем пути к файлам из rsync.log, создаём абсолютные пути и записываем их в update_files.txt
    grep -E '^.*?>f.*?\s(.*?$)' "$RSYNC_LOG_FILE" | while read -r line; do
        # Извлекаем путь к файлу из строки
        file_path=$(echo "$line" | sed -E 's/^.*?>f.*?\s(.*?$)/\1/') 

        # Преобразуем в абсолютный путь и записываем в update_files.txt
        echo "$BACKUP_DIR/$file_path" >> "$UPDATED_FILES_LIST"
    done

    log "Файл со списком обновлённых файлов создан: $UPDATED_FILES_LIST" "SUCCESS"
}

# Функция для создания символических ссылок
function create_simlinks() {
    # Проверяем, что файл со списком существует
    if [[ ! -f "$UPDATED_FILES_LIST" ]]; then
        log_error "Ошибка: файл $UPDATED_FILES_LIST не существует!"
        return 1
    fi

    log "Начинается создание папки с симлинками на удалённые файлы..." "START" 

    # Проверяем, что каталог для символических ссылок существует и доступен для записи
    if [[ ! -d "$DELTA_DIR" ]]; then
        mkdir -p "$DELTA_DIR" || { log_error "Ошибка: не удалось создать папку $DELTA_DIR"; return 1; }
    fi

    if [[ ! -w "$DELTA_DIR" ]]; then
        log_error "Ошибка: папка $DELTA_DIR недоступна для записи!"
        return 1
    fi

    # Очищаем папку с символическими ссылками перед началом работы
    find "$DELTA_DIR" -type l -delete || { log_error "Ошибка при очистке папки $DELTA_DIR"; return 1; }

    local success_count=0
    local fail_count=0

    # Чтение строк из файла и создание символических ссылок
    while IFS= read -r file; do
        # Проверяем, существует ли файл
        if [[ -e "$file" ]]; then
            # Получаем имя файла из пути
            local filename=$(basename "$file")
            
            # Создаем символическую ссылку в каталоге simlinks
            ln -s "$file" "$DELTA_DIR/$filename"
            if [[ $? -eq 0 ]]; then
                log_success "Создана ссылка: $DELTA_DIR/$filename -> $file"
                ((success_count++))
            else
                log_error "Ошибка: не удалось создать ссылку для $file"
                ((fail_count++))
            fi
        else
            log_error "Файл не найден: $file"
            ((fail_count++))
        fi
    done < "$UPDATED_FILES_LIST"

    # Вывод итогового сообщения
    log "Создание символических ссылок завершено: успешно создано $success_count ссылок, не удалось создать $fail_count ссылок." "END"
}

function create_delta_symlinks() {
    extract_copied_files 
    create_simlinks
}