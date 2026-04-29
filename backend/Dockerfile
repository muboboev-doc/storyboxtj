# ============================================================================
# Backend Dockerfile — PHP 8.2-fpm + ffmpeg + extensions для Laravel 11.
# Multi-stage: dev (с Xdebug-подобными инструментами) и prod (минимальный).
# ============================================================================

# ─── Базовый слой с PHP-расширениями ────────────────────────────────────────
FROM php:8.2-fpm-alpine AS base

# Системные зависимости (libs для PHP extensions + ffmpeg + сетевые утилиты)
RUN apk add --no-cache \
        autoconf \
        bash \
        build-base \
        curl \
        ffmpeg \
        freetype-dev \
        git \
        gmp-dev \
        icu-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libwebp-dev \
        libxml2-dev \
        libzip-dev \
        linux-headers \
        mysql-client \
        oniguruma-dev \
        postgresql-dev \
        unzip \
        zip

# PHP-расширения, нужные Laravel + Filament + IAP/банк-интеграции + Sanctum
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
 && docker-php-ext-install -j"$(nproc)" \
        bcmath \
        exif \
        gd \
        gmp \
        intl \
        mbstring \
        pcntl \
        pdo \
        pdo_mysql \
        sockets \
        xml \
        zip

# Redis + opcache через PECL
RUN apk add --no-cache --virtual .build-deps autoconf gcc g++ make \
 && pecl install redis-6.0.2 \
 && docker-php-ext-enable redis opcache \
 && apk del .build-deps

# Composer
COPY --from=composer:2.7 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# php.ini — базовые настройки для dev
RUN { \
        echo "memory_limit=512M"; \
        echo "upload_max_filesize=200M"; \
        echo "post_max_size=200M"; \
        echo "max_execution_time=300"; \
        echo "date.timezone=UTC"; \
    } > /usr/local/etc/php/conf.d/zz-app.ini

# opcache.ini для dev (revalidate каждый запрос)
RUN { \
        echo "opcache.enable=1"; \
        echo "opcache.enable_cli=0"; \
        echo "opcache.validate_timestamps=1"; \
        echo "opcache.revalidate_freq=0"; \
        echo "opcache.memory_consumption=128"; \
        echo "opcache.max_accelerated_files=10000"; \
    } > /usr/local/etc/php/conf.d/zz-opcache.ini

# ─── DEV-стадия ─────────────────────────────────────────────────────────────
FROM base AS dev

# В dev — запускаем под root для удобства (mounted volumes на Windows).
# В prod создадим непривилегированного юзера.
USER root

EXPOSE 9000
CMD ["php-fpm", "-F"]

# ─── PROD-стадия (для будущих деплоев) ──────────────────────────────────────
FROM base AS prod

# Создаём непривилегированного юзера
RUN addgroup -g 1000 app && adduser -u 1000 -G app -s /bin/sh -D app

# Копируем код проекта (build-context = ./backend)
COPY --chown=app:app . /var/www/html

# Composer install (без dev-зависимостей)
RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader

USER app

EXPOSE 9000
CMD ["php-fpm", "-F"]
