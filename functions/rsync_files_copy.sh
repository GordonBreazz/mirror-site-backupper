#!/bin/bash
# REMOTE_DUMP_DIR лежит ВНУТРИ REMOTE_ROOT_DIR (например,
# REMOTE_ROOT_DIR/.db_dumps_tmp) — поэтому одного rsync-вызова
# на весь корень достаточно: дампы БД заберутся вместе с сайтами,
# отдельный rsync под них не нужен.
#
# Идёт через -e "ssh ... ControlPath=..." — то есть поверх уже
# открытого мастер-соединения, без нового подключения.
#
# --delete НЕ используется намеренно: это бэкап-архив, а не зеркало.
# Если файл удалили на сервере, он должен остаться в локальном
# бэкапе, а не исчезнуть из него следом.
#
# -i/--itemize-changes заставляет rsync построчно печатать, что именно
# он сделал с каждым файлом (новый / изменён / атрибуты и т.д.).
# Из этого вывода мы отдельно сохраняем "список изменённых файлов"
# за этот конкретный прогон — без дополнительной логики сравнения,
# rsync и так знает, что изменилось.

function run_files_download() {
    local ssh_cmd changed_log rsync_tmp_output rc
    ssh_cmd=$(rsync_ssh_command)
    changed_log="$LOGS_DIR/changed_files_${DATE}.log"

    # Временный файл — в /dev/shm (tmpfs, т.е. в оперативной памяти),
    # а не в /tmp на диске: так данные физически лежат в RAM, как и
    # при варианте с bash-переменной, но без дублирования строки внутри
    # интерпретатора и без реальной записи на NVMe. Если /dev/shm вдруг
    # недоступен (редкость, но бывает в урезанных контейнерах) —
    # откатываемся на обычный mktemp (уже на диске, как временная мера).
    if [ -d /dev/shm ] && [ -w /dev/shm ]; then
        rsync_tmp_output=$(mktemp --tmpdir=/dev/shm rsync_output.XXXXXX)
    else
        rsync_tmp_output=$(mktemp)
        log "Внимание: /dev/shm недоступен, временный файл rsync попадёт на диск: $rsync_tmp_output"
    fi

    log "rsync: корень сайтов (файлы + дампы БД) из ${REMOTE_ROOT_DIR} -> ${BACKUP_DIR}"

    # Вывод rsync идёт в обычный stdout скрипта (виден в терминале при
    # ручном запуске, попадает в лог cron при автозапуске) через tee,
    # и параллельно построчно пишется во временный файл в tmpfs —
    # НЕ в bash-переменную (при тысячах файлов итемайз-вывод может
    # разрастись до десятков МБ, а дублирование строки внутри bash —
    # лишняя нагрузка) и НЕ на NVMe (tmpfs не касается диска вообще).
    rsync -az -i \
        -e "$ssh_cmd" \
        --log-file="$RSYNC_LOG_FILE" \
        "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_ROOT_DIR}/" \
        "$BACKUP_DIR/" | tee "$rsync_tmp_output"
    rc=${PIPESTATUS[0]}

    if [ $rc -ne 0 ]; then
        log_error "rsync завершился с ошибкой (код $rc). Подробности в $RSYNC_LOG_FILE"
        rm -f "$rsync_tmp_output"
        return 1
    fi

    # Строки итемайза начинаются с одного из кодов <>ch* и буквы типа файла
    # (f/d/L/D/S), например ">f.st...... path/to/file.php". Остальное
    # (пустая строка + сводная статистика rsync в конце) отсекаем.
    # grep читает и пишет потоково, файл целиком в память не грузится.
    grep -E '^[<>ch*][fdLDS]' "$rsync_tmp_output" > "$changed_log" || true
    rm -f "$rsync_tmp_output"

    local changed_count
    changed_count=$(wc -l < "$changed_log" | tr -d ' ')
    log "Изменённых файлов в этом прогоне: $changed_count (список: $changed_log)"
}
