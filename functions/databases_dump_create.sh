#!/bin/bash
# Раньше: отдельный `ssh ... mysqldump` на каждую базу данных —
# при 5-10 сайтах это 5-10 новых соединений на каждый запуск.
#
# Теперь: один ssh-вызов передаёт на сервер целый bash-скрипт
# (через stdin), который сам, уже НА сервере, в цикле дампит
# все базы. Соединение открывается один раз для всей операции.

function run_db_backup() {
    local remote_script remote_output rc
    remote_script=$(build_remote_dump_script)

    # Захватываем и stdout, и stderr удалённого скрипта, чтобы в случае
    # ошибки в лог попало реальное сообщение mysqldump/bash, а не только
    # "что-то пошло не так".
    remote_output=$(printf '%s' "$remote_script" | remote_ssh "bash -s" 2>&1)
    rc=$?

    printf '%s\n' "$remote_output" >> "$MAIN_LOG_FILE"

    if [ $rc -ne 0 ]; then
        log_error "Удалённый дамп баз данных завершился с ошибкой (код $rc). Подробности:"
        printf '%s\n' "$remote_output" | while IFS= read -r line; do
            log_error "  $line"
        done
        return 1
    fi

    printf '%s\n' "$remote_output"
}

# Формирует bash-скрипт, который будет целиком выполнен на
# удалённой стороне за один ssh-вызов.
function build_remote_dump_script() {
    local script
    # pipefail критично: без него `mysqldump | gzip > file` вернёт код
    # ВОЗВРАТА gzip (обычно 0), даже если mysqldump упал с ошибкой —
    # gzip просто сожмёт пустой ввод, а скрипт решит, что всё хорошо.
    script="set -eu -o pipefail; mkdir -p '${REMOTE_DUMP_DIR}';"

    local db_name db_user db_pass
    for db_name in "${!DATABASES[@]}"; do
        db_user="${DATABASES[$db_name]%%:*}"
        db_pass="${DATABASES[$db_name]#*:}"

        # Однократный экранированный блок на каждую БД —
        # но это ЧАСТЬ ОДНОГО скрипта, не отдельное ssh-подключение.
        # Проверка размера файла после дампа — доп. страховка от
        # тихого "успеха" с пустым дампом, если pipefail почему-то
        # не сработал (например, очень старый bash на сервере).
        script+=$(printf ' echo "[dump] %q"; mysqldump --single-transaction --quick --user=%q --password=%q %q | gzip > %q/%q.sql.gz; sz=$(stat -c%%s %q/%q.sql.gz); if [ "$sz" -lt 100 ]; then echo "ОШИБКА: дамп %q подозрительно маленький ($sz байт) — вероятно, mysqldump не смог подключиться" >&2; exit 1; fi;' \
            "$db_name" "$db_user" "$db_pass" "$db_name" \
            "$REMOTE_DUMP_DIR" "$db_name" \
            "$REMOTE_DUMP_DIR" "$db_name" \
            "$db_name")
    done

    printf '%s' "$script"
}
