#!/bin/bash
# Вся суть переделки — здесь.
#
# Вместо того, чтобы каждый ssh/rsync-вызов поднимал новое TCP/SSH
# соединение (за что банит хостинг), мы один раз открываем
# "мастер"-соединение в фоне (ssh -M), а все последующие команды
# идут через unix-сокет ControlPath и физически используют
# то же самое TCP-соединение — сервер видит ОДНО подключение
# за весь прогон скрипта, сколько бы команд мы ни выполнили.

# Ключ и SSH-опции строятся ЛЕНИВО (не в момент source этого файла),
# потому что финальный SSH_KEY_PATH (в т.ч. автоопределённый)
# известен только после init() в главном скрипте.
SSH_BASE_OPTS=()
SSH_MUX_OPTS=()

function _init_ssh_opts() {
    SSH_BASE_OPTS=(
        -i "$SSH_KEY_PATH"
        -p "${REMOTE_PORT:-22}"
        -o "ConnectTimeout=$SSH_CONNECT_TIMEOUT"
        -o "StrictHostKeyChecking=accept-new"
        -o "BatchMode=yes"
    )
    SSH_MUX_OPTS=(
        -o "ControlMaster=auto"
        -o "ControlPath=$SSH_CONTROL_PATH"
        -o "ControlPersist=10m"
    )
}

# Пытается найти единственный приватный ключ в ~/.ssh среди
# стандартных имён. Если найден ровно один — возвращает путь.
# Если ноль или больше одного — ошибка с понятным сообщением,
# т.к. угадывать "чей это ключ" в общем скрипте небезопасно.
function detect_ssh_key() {
    local candidates=()
    local name
    for name in id_ed25519 id_rsa id_ecdsa id_ed25519_sk; do
        [ -f "$HOME/.ssh/$name" ] && candidates+=("$HOME/.ssh/$name")
    done

    case "${#candidates[@]}" in
        1)
            echo "${candidates[0]}"
            ;;
        0)
            log_error "Не найден приватный SSH-ключ в $HOME/.ssh (искал: id_ed25519, id_rsa, id_ecdsa, id_ed25519_sk). Укажите SSH_KEY_PATH явно в credentials.conf."
            return 1
            ;;
        *)
            log_error "В $HOME/.ssh найдено несколько ключей (${candidates[*]}) — непонятно, какой использовать. Укажите SSH_KEY_PATH явно в credentials.conf."
            return 1
            ;;
    esac
}

# Открыть мастер-соединение в фоне (один раз за весь запуск скрипта).
function open_ssh_master() {
    _init_ssh_opts
    mkdir -p "$SSH_CONTROL_DIR"
    ssh "${SSH_BASE_OPTS[@]}" "${SSH_MUX_OPTS[@]}" -fN \
        "${REMOTE_USER}@${REMOTE_HOST}"
    local rc=$?
    if [ $rc -ne 0 ]; then
        log_error "Не удалось открыть управляющее SSH-соединение (код $rc)."
        exit 1
    fi
}

# Явно закрыть мастер-соединение (освобождает сокет сразу,
# не дожидаясь ControlPersist=10m).
function close_ssh_master() {
    ssh "${SSH_BASE_OPTS[@]}" "${SSH_MUX_OPTS[@]}" -O exit \
        "${REMOTE_USER}@${REMOTE_HOST}" 2>/dev/null || true
}

# Выполнить произвольную команду на удалённом сервере
# через уже открытое мастер-соединение (новое TCP не создаётся).
function remote_ssh() {
    ssh "${SSH_BASE_OPTS[@]}" "${SSH_MUX_OPTS[@]}" \
        "${REMOTE_USER}@${REMOTE_HOST}" "$@"
}

# Проверка доступности сервера — использует то же соединение.
function check_connection() {
    remote_ssh "echo ok" >/dev/null 2>&1
}

# Готовая строка для передачи в `rsync -e "..."`, чтобы rsync
# тоже пошёл через мастер-соединение, а не открывал своё.
function rsync_ssh_command() {
    echo "ssh ${SSH_BASE_OPTS[*]} ${SSH_MUX_OPTS[*]}"
}
