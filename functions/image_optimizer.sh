function list_image_files {
    # Проверка, что путь и имя списка переданы как параметры
    if [ -z "$1" ] || [ -z "$2" ]; then
        log_error "Ошибка: Не переданы параметры в list_image_files(). Необходимо указать путь к каталогу и имя списка."
        exit 1  # Завершаем выполнение скрипта с ошибкой
    fi

    # Устанавливаем переменные
    IMAGE_DIR="$1"
    LIST_NAME="$2"

    # Проверка существования каталога
    if [ ! -d "$IMAGE_DIR" ]; then
        log_error "Ошибка: каталог $IMAGE_DIR не существует."
        exit 1  # Завершаем выполнение скрипта с ошибкой
    fi

    # Создание текстового файла со списком растровых изображений
    find "$IMAGE_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.webp" -o -iname "*.heic" \) > "$LOGS_DIR/$LIST_NAME.txt"
    
    # Проверка на успешность выполнения
    if [ $? -eq 0 ]; then
        echo "Список изображений создан и сохранен в $LOGS_DIR/$LIST_NAME.txt"
    else
        echo "Ошибка при создании списка изображений."
        exit 1  # Завершаем выполнение скрипта с ошибкой
    fi
}

function analyze_files {
    log "Начинается создание файла списка файлов изображений для оптимизации" "START"
    # Проверка наличия файлов
    if [ ! -f "$1" ] || [ ! -f "$2" ]; then
        log_error "Ошибка: один или оба файла не существуют."
        exit 1
    fi

    # Устанавливаем имена файлов
    original_file="$1"
    optimal_file="$2"
    output_file="$LOGS_DIR/difference.txt"

    # Чтение файлов и создание массивов путей
    mapfile -t original_files < "$original_file"
    mapfile -t optimal_files < "$optimal_file"

    # Создаем пустой файл для записи путей
    > "$output_file"

    # Сравниваем файлы
    for original in "${original_files[@]}"; do
        # Проверка, если файл из original.txt не присутствует в optimal.txt
        if ! grep -q "$original" "$optimal_file"; then
            # Получаем размер файла из original.txt
            original_size=$(stat --format="%s" "$original")
            
            # Проверяем, если файл существует и его размер
            if [ -f "$original" ]; then
                # Добавляем путь к файлу в output_file
                log "$original" >> "$output_file"
            fi
        fi
    done

    # Сортируем файлы по размеру (больший размер будет первым) и сохраняем в новый файл
    sort -n -r -k1,1 "$output_file" -o "$output_file"

    log "Задача завершена. Результаты сохранены в $output_file." "END"
}


function run_image_optimazer {
    OPTIMAGES="$LOCAL_DIR/optimized_images"

    log "Начинается создание оптимизированных изображений сайта" "START"

    # Создаём директорию для оптимизированных файлов изображений, если её нет
    
    #mkdir -p "$OPTIMAGES"
    log "Создание списка файлов изображений сайта"
    list_image_files "$BACKUP_DIR" "original"

    log "Создание списка файлов оптимизированных изображений сайта"
    list_image_files "$OPTIMAGES" "optimal"   

    analyze_files "$LOGS_DIR/original.txt" "$LOGS_DIR/optimal"

    
    log "Завершена задача создания оптимизированных изображений сайта" "END"
}
