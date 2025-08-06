# Используем Debian Bookworm вместо Alpine
FROM golang:1.24-bookworm AS builder

# Установка зависимостей (в Bookworm многие уже есть)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Рабочая директория
WORKDIR /app

# Копирование всех исходных файлов
COPY . .

# Явно чиним окончания строк и пересоздаем скрипт на случай проблем
RUN if [ -f "build.sh" ]; then \
        tr -d '\r' < build.sh > build.sh.fixed && \
        mv build.sh.fixed build.sh && \
        chmod +x build.sh && \
        echo "build.sh почищен и готов к запуску"; \
    else \
        echo '#!/bin/bash' > build.sh && \
        echo 'set -e' >> build.sh && \
        echo 'echo "Generate static"' >> build.sh && \
        echo 'go run ./cmd/genpages/gen_pages.go' >> build.sh && \
        echo 'echo "Build..."' >> build.sh && \
        echo 'GOOS=linux GOARCH=amd64 go build -v -ldflags="-s -w" -o ./dist/torrs ./cmd/main' >> build.sh && \
        chmod +x build.sh && \
        echo "Новый build.sh создан"; \
    fi

# Отладка: выводим содержимое скрипта
RUN cat build.sh

# Сборка через скрипт
RUN ./build.sh

# Финальный минимальный образ (тоже на Bookworm)
FROM debian:bookworm-slim

# Установка необходимых пакетов
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Создание пользователя
RUN useradd -m -s /bin/bash torrs

# Копирование собранного бинарника В КОРНЕВУЮ ДИРЕКТОРИЮ ПОЛЬЗОВАТЕЛЯ или в /app
# ВАЖНО: Это место будет использоваться как global.PWD для torrs
WORKDIR /home/torrs
# Копируем бинарник сюда
COPY --from=builder --chown=torrs:torrs /app/dist/torrs ./torrs
# Копируем views тоже сюда или в корень, как в исходном build.sh
COPY --from=builder --chown=torrs:torrs /app/views ./views

# Создание директории для данных (тома) и установка прав
# Эта директория будет монтироваться извне через volume
RUN mkdir -p /data && chown torrs:torrs /data

# Устанавливаем рабочую директорию ТАМ, ГДЕ НАХОДИТСЯ БИНАРНИК
# Это критично, потому что torrs ищет/создает torrents.db и index.db здесь.
WORKDIR /home/torrs

# Переключение на непривилегированного пользователя
USER torrs

# Порты
EXPOSE 8094

# Тома - указываем, что /data может быть примонтирован
VOLUME ["/data"] 

# Команда запуска - НЕТ --data
# Если нужен другой порт, измените 8094 на нужный, например 8080
ENTRYPOINT ["./torrs"]
# CMD ["--port", "8080"] # Раскомментируйте, если хотите порт 8080 вместо 8094
CMD ["--port", "8094"] 

