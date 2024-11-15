#!/bin/bash

### Блок настроек скрипта ###

## Параметры скрипта на локальтной машине

LOCAL_DIR_PATH="/home/site-backup"                            # Путь к локальной папки для бекапа
SSH_KEY_PATH="$HOME/.ssh/id_rsa"                              # Путь к вашему приватному ключу

NAME_LOCAL_DIR="timeweb-newvsgaki"                            # Название локальной папки для Бекапа
NAME_MIRROR_DIR="site-mirror"                                 # Название папки для зеркала удалённого сервера 
NAME_DB_DIR=".db_dumps"                                       # Название папки для дампов БД (часть зеркала)

NAME_LOGS_DIR="logs"                                          # Название папки для логов
NAME_DELTA_DIR="backup_delta"                                 # Название папки с симлинками на обновлённые файлы

NAME_MAIN_LOG_FILE="backup.log"                               # Название лог-файла
NAME_ERROR_LOG_FILE="backup_error.log"                        # Название лог-файла с ошибками
NAME_RSYNC_LOG_FILE="rsync.log"                               # Название лог-файла с результатами работы RSYNC
NAME_CREDENTIALS_FILE="credentials.conf"                      # Название файла конфигурации c подключением к удалённому серверу и массивом данных для подключения к базам данных 

## Параметры скрипта закрытых для изменения 

LOCAL_DIR="$LOCAL_DIR_PATH/$NAME_LOCAL_DIR"                   # Локальная папка для бекапа
BACKUP_DIR="$LOCAL_DIR/$NAME_MIRROR_DIR"                      # Папка для зеркала удалённого сервера
LOGS_DIR="$LOCAL_DIR/$NAME_LOGS_DIR"                          # Папка для логов
DELTA_DIR="$LOCAL_DIR/$NAME_DELTA_DIR"                        # Папка для симлинков на обновлённые файлы

UPDATED_FILES_LIST="$LOGS_DIR/update_files.txt"               # Путь для файла со списком обновлённых файлов
MAIN_LOG_FILE="$LOGS_DIR/$NAME_MAIN_LOG_FILE"                 # Путь к файлу с логами
ERROR_LOG_FILE="$LOGS_DIR/$NAME_ERROR_LOG_FILE"               # Путь к файлу с логами ошибок
RSYNC_LOG_FILE="$LOGS_DIR/$NAME_RSYNC_LOG_FILE"               # Путь к файлу с логами работы RSYNC
CREDENTIALS_FILE="./$NAME_CREDENTIALS_FILE"                   # Путь к файлу с конфадециальными данными 


DATE=$(date +"%Y%m%d_%H%M%S")                                 # Дата и время для метки
IS_FIRST=0                                                    # Переменная для определения первого запуска

## Подключение функций

source ./functions/loging.sh                                  # Функции логирования
source ./functions/connection.sh                              # Функции проверки доступности удалённого сервера
source ./functions/databases_dump_create.sh                   # Функции создания дампов баз данных
source ./functions/rsync_files_copy.sh                        # Функции копирования файлов сайта
source ./functions/backup_delta_symlinks.sh                   # Функции создания папки симлинков
source ./functions/antivirus_check.sh                         # Функции проверки файлов антивирусом

### Определение функций ###

## Функция инициализации
function init() {
    mkdir -p "$LOCAL_DIR"                                     # Создаём директорию для бэкапов, если её нет    
    > "$MAIN_LOG_FILE"                                        # Очищаем log перед началом работы

    # Проверка наличия файла credentials.conf и логирование ошибки, если его нет
    if [ ! -f "$CREDENTIALS_FILE" ]; then
        log_error "Ошибка: Не найден файл \"$CREDENTIALS_FILE\" с настройками подключения к удалённому серверу и базам данных. Убедитесь, что он существует и доступен."
        exit 1
    fi

    source "$CREDENTIALS_FILE"                                # Подключение файла с конфадециальными данными
    check_connection                                          # Проверка доступности удалённого сервера
    mkdir -p "$BACKUP_DIR"                                    # Создаём директорию для зеркала удалённого сервера, если её нет    
    mkdir -p "$LOGS_DIR"                                      # Создаём директорию для логов, если её нет
}

## Запуск функций
init                                                          # Инициализация
#create_db_dumps                                               # Создание дампов баз данных
#run_files_download                                            # Скачивание файлов сайта и дампов
#create_delta_symlinks                                         # Создание папки симлинков на обновлённые файлы
run_antivirus                                                 # Проверка файлов антивирусом

exit 0