function init_or_update_web_git_repo {
    # Проверка, что путь передан как параметр
    if [ -z "$1" ]; then
        echo "Ошибка: Не передан путь к каталогу."
        return 1
    fi

    # Устанавливаем путь к каталогу
    REPO_DIR="$1"

    # Проверка существования каталога
    if [ ! -d "$REPO_DIR" ]; then
        echo "Ошибка: каталог $REPO_DIR не существует."
        return 1
    fi

    # Переходим в указанный каталог
    cd "$REPO_DIR" || return 1

    # Проверка, существует ли репозиторий git
    if [ -d ".git" ]; then
        # Репозиторий уже существует, просто добавляем изменения
        echo "Репозиторий уже существует. Добавляем изменения."

        # Массив с типичными типами файлов для веб-разработки
        FILE_TYPES=("*.php" "*.css" "*.html" "*.js" "*.json" "*.md")

        # Строим команду для поиска файлов, соответствующих типам из массива
        FIND_CMD="find . -type f"
        for EXT in "${FILE_TYPES[@]}"; do
            FIND_CMD="$FIND_CMD -o -iname \"$EXT\""
        done

        # Выполняем команду поиска файлов и добавляем их в репозиторий
        eval $FIND_CMD | git add -

        # Если есть изменения, делаем коммит
        if git diff-index --quiet HEAD; then
            echo "Нет изменений для коммита."
        else
            git commit -m "Update with typical web development files"
            echo "Изменения добавлены и коммит выполнен."
        fi
    else
        # Репозиторий не существует, создаём новый
        echo "Репозиторий не существует. Инициализация нового репозитория."
        git init

        # Создаём .gitignore с типичными исключениями для веб-разработки
        echo "node_modules/" > .gitignore
        echo "dist/" >> .gitignore
        echo "build/" >> .gitignore
        echo ".env" >> .gitignore
        echo "*.log" >> .gitignore
        echo "*.bak" >> .gitignore
        echo "*.swp" >> .gitignore

        # Массив с типичными типами файлов для веб-разработки
        FILE_TYPES=("*.php" "*.css" "*.html" "*.js" "*.json" "*.md")

        # Строим команду для поиска файлов, соответствующих типам из массива
        FIND_CMD="find . -type f"
        for EXT in "${FILE_TYPES[@]}"; do
            FIND_CMD="$FIND_CMD -o -iname \"$EXT\""
        done

        # Выполняем команду поиска файлов и добавляем их в репозиторий
        eval $FIND_CMD | git add -

        # Делаем первый коммит
        git commit -m "Initial commit with typical web development files"
        echo "Репозиторий создан и первый коммит выполнен."
    fi
}

function code_repository_update {
    
}