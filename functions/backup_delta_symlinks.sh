# Функция для создания символических ссылок
function create_simlinks() {
  
  # Проверяем, что файл со списком существует
  if [[ ! -f "$UPDATED_FILES_LIST" ]]; then
    log "Ошибка: файл $UPDATED_FILES_LIST не существует!"
    return 1
  fi
  
  # Проверяем, что каталог для символических ссылок существует, если нет, создаём его
  mkdir -p "$DELTA_DIR"
  
  # Чтение строк из файла и создание символических ссылок
  while IFS= read -r file; do
    # Проверяем, существует ли файл
    if [[ -e "$file" ]]; then
      # Получаем имя файла из пути
      local filename=$(basename "$file")
      
      # Создаем символическую ссылку в каталоге simlinks
      ln -s "$file" "$DELTA_DIR/$filename"
      log_success "Создана ссылка: $DELTA_DIR/$filename -> $file"
    else
      log_error "Файл не найден: $file"
    fi
  done < "$UPDATED_FILES_LIST"
}

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

function delta_symlinks() {
    extract_copied_files 
    create_simlinks
}