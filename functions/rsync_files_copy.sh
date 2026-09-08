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
    local ssh_cmd changed_log rsync_output rc
    ssh_cmd=$(rsync_ssh_command)
    changed_log="$LOGS_DIR/changed_files_${DATE}.log"

    log "rsync: корень сайтов (файлы + дампы БД) из ${REMOTE_ROOT_DIR} -> ${BACKUP_DIR}"

    # Захватываем stdout (там при -i построчный список изменений),
    # и одновременно пишем полный технический лог в RSYNC_LOG_FILE как раньше.
    rsync_output=$(rsync -az -i \
        -e "$ssh_cmd" \
        --log-file="$RSYNC_LOG_FILE" \
        "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_ROOT_DIR}/" \
        "$BACKUP_DIR/")
    rc=$?

    if [ $rc -ne 0 ]; then
        log_error "rsync завершился с ошибкой (код $rc). Подробности в $RSYNC_LOG_FILE"
        return 1
    fi

    # Строки итемайза начинаются с одного из кодов <>ch* и буквы типа файла
    # (f/d/L/D/S), например ">f.st...... path/to/file.php". Остальное
    # (пустая строка + сводная статистика rsync в конце) отсекаем.
    printf '%s\n' "$rsync_output" | grep -E '^[<>ch*][fdLDS]' > "$changed_log" || true

    local changed_count
    changed_count=$(wc -l < "$changed_log" | tr -d ' ')
    log "Изменённых файлов в этом прогоне: $changed_count (список: $changed_log)"
}
