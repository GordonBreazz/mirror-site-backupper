#!/bin/bash
# install.sh — интерактивная настройка credentials.conf для mirror-site-backupper.
# Запускать из корня репозитория:
#   ./install.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CREDENTIALS_FILE="$SCRIPT_DIR/credentials.conf"

echo "═══ Настройка mirror-site-backupper ═══"
echo

# --- 1. Проверка, что credentials.conf ещё не существует ---
if [ -f "$CREDENTIALS_FILE" ]; then
    read -rp "credentials.conf уже существует. Перезаписать? [y/N]: " overwrite
    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
        echo "Отменено. Существующий credentials.conf не тронут."
        exit 0
    fi
    echo
fi

# --- 2. Параметры подключения к серверу ---
read -rp "Пользователь на удалённом сервере (REMOTE_USER): " REMOTE_USER
read -rp "Хост/IP удалённого сервера (REMOTE_HOST): " REMOTE_HOST
read -rp "SSH-порт [22]: " REMOTE_PORT
REMOTE_PORT="${REMOTE_PORT:-22}"
read -rp "Корневая папка со всеми сайтами на сервере (REMOTE_ROOT_DIR), например /var/www: " REMOTE_ROOT_DIR

if [ -z "$REMOTE_USER" ] || [ -z "$REMOTE_HOST" ] || [ -z "$REMOTE_ROOT_DIR" ]; then
    echo "REMOTE_USER, REMOTE_HOST и REMOTE_ROOT_DIR обязательны. Прервано."
    exit 1
fi
echo

# --- 3. SSH-ключ ---
existing_keys=()
for name in id_ed25519 id_rsa id_ecdsa id_ed25519_sk; do
    [ -f "$HOME/.ssh/$name" ] && existing_keys+=("$HOME/.ssh/$name")
done

SSH_KEY_LINE=""
if [ "${#existing_keys[@]}" -eq 1 ]; then
    echo "Найден SSH-ключ: ${existing_keys[0]} — будет использован автоматически."
    echo "(SSH_KEY_PATH в credentials.conf оставляем пустым — автоопределение сработает само.)"
elif [ "${#existing_keys[@]}" -gt 1 ]; then
    echo "Найдено несколько SSH-ключей: ${existing_keys[*]}"
    read -rp "Укажите, какой использовать (полный путь): " chosen_key
    SSH_KEY_LINE="SSH_KEY_PATH=\"$chosen_key\""
else
    echo "SSH-ключ в $HOME/.ssh не найден."
    read -rp "Сгенерировать новый ed25519-ключ сейчас? [Y/n]: " gen_key
    if [[ ! "$gen_key" =~ ^[Nn]$ ]]; then
        ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)" -f "$HOME/.ssh/id_ed25519"
        echo "Ключ создан: $HOME/.ssh/id_ed25519"
    else
        echo "Без ключа скрипт бэкапа работать не сможет — не забудьте создать его позже."
    fi
fi
echo

# --- 4. Копирование ключа на сервер ---
read -rp "Скопировать публичный ключ на удалённый сервер сейчас (ssh-copy-id)? [Y/n]: " do_copy
if [[ ! "$do_copy" =~ ^[Nn]$ ]]; then
    if command -v ssh-copy-id >/dev/null 2>&1; then
        ssh-copy-id -p "$REMOTE_PORT" "${REMOTE_USER}@${REMOTE_HOST}"
    else
        echo "ssh-copy-id не найден. Скопируйте ключ вручную (см. README раздел 'Настройка SSH-ключей')."
    fi
fi
echo

# --- 5. Базы данных ---
declare -A DATABASES_MAP=()
echo "Теперь добавим базы данных для дампа."
while true; do
    read -rp "Имя базы данных (Enter — закончить ввод баз): " db_name
    [ -z "$db_name" ] && break
    read -rp "  Пользователь БД для '$db_name': " db_user
    read -rsp "  Пароль БД для '$db_name': " db_pass
    echo
    DATABASES_MAP["$db_name"]="${db_user}:${db_pass}"
done

if [ "${#DATABASES_MAP[@]}" -eq 0 ]; then
    echo "Ни одной базы не добавлено — credentials.conf будет содержать пустой DATABASES[]."
    echo "Добавьте базы вручную перед запуском backup_script.sh."
fi
echo

# --- 6. Запись credentials.conf ---
{
    echo "# Сгенерировано install.sh $(date '+%Y-%m-%d %H:%M:%S')"
    echo "# НЕ коммитьте этот файл в git — он уже в .gitignore."
    echo
    if [ -n "$SSH_KEY_LINE" ]; then
        echo "$SSH_KEY_LINE"
        echo
    fi
    echo "REMOTE_USER=\"$REMOTE_USER\""
    echo "REMOTE_HOST=\"$REMOTE_HOST\""
    echo "REMOTE_PORT=\"$REMOTE_PORT\""
    echo "REMOTE_ROOT_DIR=\"$REMOTE_ROOT_DIR\""
    echo
    echo "declare -A DATABASES=("
    for db_name in "${!DATABASES_MAP[@]}"; do
        echo "    [\"$db_name\"]=\"${DATABASES_MAP[$db_name]}\""
    done
    echo ")"
} > "$CREDENTIALS_FILE"

chmod 600 "$CREDENTIALS_FILE"

echo "═══ Готово ═══"
echo "credentials.conf создан: $CREDENTIALS_FILE (права 600)"
echo "Проверьте его содержимое, затем запускайте: ./backup_script.sh"
