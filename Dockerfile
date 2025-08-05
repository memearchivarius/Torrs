# Используем актуальную версию Go, как указано в go.mod
FROM golang:1.22-alpine AS builder

# Установка зависимостей
RUN apk add --no-cache git build-base

# Рабочая директория
WORKDIR /app

# Копирование всех исходных файлов
COPY . .

# Отладка: Проверяем содержимое рабочей директории
RUN ls -la

# Явно устанавливаем права на выполнение для build.sh
RUN if [ -f "build.sh" ]; then \
        chmod +x build.sh && \
        echo "Права на build.sh установлены"; \
    else \
        echo "build.sh НЕ НАЙДЕН!" && exit 1; \
    fi

# Сборка через скрипт
RUN ./build.sh

# Финальный минимальный образ
FROM alpine:latest

# Установка необходимых пакетов
RUN apk add --no-cache ca-certificates

# Создание пользователя
RUN adduser -D -s /bin/sh torrs

# Копирование собранного бинарника и веб-файлов
COPY --from=builder /app/dist/torrs /usr/local/bin/torrs
COPY --from=builder /app/views /views

# Создание рабочей директории для данных
WORKDIR /data
RUN mkdir -p /data && chown torrs:torrs /data

# Переключение на непривилегированного пользователя
USER torrs

# Порты
EXPOSE 8080

# Тома
VOLUME ["/data"]

# Команда запуска
ENTRYPOINT ["torrs"]
CMD ["--port", "8080", "--data", "/data"]