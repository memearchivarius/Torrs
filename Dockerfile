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

# Явно чиним окончания строк и пересоздаем скрипт
RUN if [ -f "build.sh" ]; then \
        # Удаляем Windows окончания строк и создаем чистый скрипт \
        rm -f build.sh.fixed && \
        tr -d '\r' < build.sh > build.sh.fixed && \
        mv build.sh.fixed build.sh && \
        chmod +x build.sh && \
        echo "build.sh почищен и готов к запуску"; \
    else \
        echo "build.sh НЕ НАЙДЕН!" && exit 1; \
    fi

# Отладка: выводим содержимое скрипта
RUN cat build.sh

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
