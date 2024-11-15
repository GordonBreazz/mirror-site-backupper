#!/bin/bash

### Блок настроек скрипта

## Параметры скрипта на локальтной машине

LOCAL_DIR="/home/site-backup/timeweb-newvsgaki"               # Локальная папка для бекапа

NAME_BACKUP_DIR="site-mirror"                                 # Название папки зеркала 
NAME_DB_DIR=".db_dumps"                                       # Название папки для дампов БД (часть зеркала)

NAME_LOGS_DIR="logs"                                          # Название папки для логов
NAME_DELTA_DIR="backup_delta"                                 # Название папки с симлинками на обновлённые файлы

NAME_MAIN_LOG_FILE="backup.log"                               # Название лог-файла
NAME_ERROR_LOG_FILE="backup_error.log"                        # Название лог-файла с ошибками
NAME_RSYNC_LOG_FILE="rsync.log"                               # Название лог-файла с результатами работы RSYNC

DB_CREDENTIALS_FILE="./db_credentials.conf"                   # Путь к файлу конфигурации c массивом с данными для подключения к базам данных
UPDATED_FILES_LIST="$LOGS_DIR/update_files.txt"               # Путь для файла со списком обновлённых файлов

## Параметры скрипта закрытых для изменения 

BACKUP_DIR="$LOCAL_DIR/$NAME_BACKUP_DIR"                      # Папка для бекапа файлов
LOGS_DIR="$LOCAL_DIR/$NAME_LOGS_DIR"                          # Папка для логов
DELTA_DIR="$LOCAL_DIR/$NAME_DELTA_DIR"                        # Папка для симлинков на обновлённые файлы

MAIN_LOG_FILE="$LOGS_DIR/$NAME_MAIN_LOG_FILE"                 # Путь к файлу с логами
ERROR_LOG_FILE="$LOGS_DIR/$NAME_ERROR_LOG_FILE"               # Путь к файлу с логами ошибок
RSYNC_LOG_FILE="$LOGS_DIR/$NAME_RSYNC_LOG_FILE"               # Путь к файлу с логами работы RSYNC

DATE=$(date +"%Y%m%d_%H%M%S")                                 # Дата и время для метки
IS_FIRST=1                                                     # Переменная для определения первого запуска

## Подключение функций

source ./credentials.conf                                     # Массив с данными для подключения к базам данных
source ./functions/log.sh                                     # Функции логирования
source ./functions/connection.sh                              # Функции проверки доступности удалённого сервера
source ./functions/databases_dump_create.sh                   # Функции создания дампов баз данных
source ./functions/rsync_files_copy.sh                        # Функции копирования файлов сайта
source ./functions/backup_delta_symlinks.sh                   # Функции создания папки симлинков
source ./functions/antivirus_check.sh                          # Функции проверки файлов антивирусом

### Определение функций

# Функция инициализации
function init() {
    check_connection                                          # Проверка доступности удалённого сервера
    #> "$RSYNC_LOG_FILE"                                      # Очищаем RSYNC log перед началом работы
    > "$MAIN_LOG_FILE"                                        # Очищаем log перед началом работы
    mkdir -p "$BACKUP_DIR"                                    # Создаём директорию для бэкапов, если её нет    
    mkdir -p "$LOGS_DIR"                                      # Создаём директорию для логов, если её нет
}

# Запуск функций
init                                                          # Инициализация
create_db_dumps                                               # Создание дампов баз данных
run_files_download                                            # Скачивание файлов сайта и дампов
create_delta_symlinks                                         # Создание папки симлинков на обновлённые файлы
run_antivirus                                                 # Проверка файлов антивирусом

exit 0