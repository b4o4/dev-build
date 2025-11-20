###############################################################################
# Базовые шаги сборки, которые необходимы и локально, и на серверах.
###############################################################################
FROM php:8.3-cli-bookworm AS base

# Установка расширений и программ
RUN --mount=type=bind,from=mlocati/php-extension-installer:2,source=/usr/bin/install-php-extensions,target=/usr/local/bin/install-php-extensions \
    install-php-extensions bcmath gd intl pcntl pdo_pgsql redis sockets protobuf zip opcache

COPY --from=ghcr.io/roadrunner-server/roadrunner:2025.1.2 /usr/bin/rr /usr/local/bin/rr

# Настройка
COPY docker/php/php.ini /usr/local/etc/php/php.ini
COPY docker/php/php.ini-base /usr/local/etc/php/conf.d/01-php.ini

COPY docker/php/rr.yaml /usr/local/etc/rr.yaml

ENV RR_DEBUG=false
ENV RR_MAX_REQUEST_SIZE=128
ENV RR_MAX_QUEUE_SIZE=1000

ENV OCTANE_HOST=0.0.0.0
ENV OCTANE_PORT=8000
ENV OCTANE_RPC_HOST=127.0.0.1
ENV OCTANE_RPC_PORT=6001
ENV OCTANE_WORKERS=auto
ENV OCTANE_MAX_REQUESTS=0

# Некоторые настройки Octane можно указать только через cli флаги. Чтобы
# добавить возможность указывать их через переменные среды, команда запускается
# с shell синтаксисом. При запуске контейнера Docker выполнит `sh -c '<CMD>'`,
# поэтому тут будут работать переменные среды. `exec` используется чтобы
# процесс sh не оставался висеть в контейнере после запуска.
CMD exec php artisan octane:roadrunner \
    --rr-config=/usr/local/etc/rr.yaml \
    --host=${OCTANE_HOST} --port=${OCTANE_PORT} \
    --rpc-host=${OCTANE_RPC_HOST} --rpc-port=${OCTANE_RPC_PORT} \
    --workers=${OCTANE_WORKERS} --max-requests=${OCTANE_MAX_REQUESTS}

EXPOSE 8000
EXPOSE 2112
EXPOSE 2114


###############################################################################
# Сборка локального образа. Многие шаги взяты из Dockerfile laravel/sail.
###############################################################################
FROM base AS development

ARG WWWGROUP

ENV DEBIAN_FRONTEND=noninteractive
ENV RR_PHP_USER="sail"

# Установка расширений и программ
RUN --mount=type=bind,from=mlocati/php-extension-installer:2,source=/usr/bin/install-php-extensions,target=/usr/local/bin/install-php-extensions \
    install-php-extensions xdebug

RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y gosu \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && curl -fsSL https://getcomposer.org/installer | php -- --version=2.8.10 --install-dir=/usr/bin/ --filename=composer \
    && curl -fsSL https://quobix.com/scripts/install_vacuum.sh | VERSION='0.17.6' INSTALL_DIR='/usr/bin' sh

# Настройка
COPY docker/php/php.ini-development /usr/local/etc/php/conf.d/02-php.ini

COPY --chmod=755 docker/php/entrypoint-development /usr/local/bin/docker-php-entrypoint

RUN groupadd --force -g $WWWGROUP sail
RUN useradd -ms /bin/bash --no-user-group -g $WWWGROUP -u 1337 sail


###############################################################################
# Сборка образа для деплоя на сервера.
###############################################################################
FROM base AS production

# Установка расширений и программ
RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y cron \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Копирование приложения
COPY composer.json composer.lock /app/
COPY vendor /app/vendor

COPY artisan /app/
COPY --chown=www-data:www-data --chmod=755 bootstrap/cache /app/bootstrap/cache
COPY --chown=www-data:www-data --chmod=755 storage /app/storage
COPY public /app/public

COPY bootstrap/app.php /app/bootstrap/

COPY app /app/app
COPY config /app/config
COPY database /app/database
COPY routes /app/routes

# Настройка
COPY docker/php/php.ini-production /usr/local/etc/php/conf.d/02-php.ini
COPY --chown=root:root --chmod=644 docker/php/crontab /etc/crontab

COPY --chmod=755 docker/php/entrypoint-production /usr/local/bin/docker-php-entrypoint

# Tinker сохраняет историю команд в `$HOME/.config`.
# /var/www - это домашняя директория пользователя www-data, но владеет ею root,
# поэтому tinker не может создать нужные папки, не может сохранить историю и
# выдаёт ошибку. Поэтому создаём папку, которая необходима tinker заранее, и
# меняем её владельца.
RUN mkdir -p /var/www/.config && chown www-data:www-data /var/www/.config

HEALTHCHECK --interval=30s --timeout=5s --start-period=2s \
    CMD \
        curl -f http://127.0.0.1:2114/health || exit 1 && \
        curl -f http://127.0.0.1:8000/up || exit 1

WORKDIR /app
USER www-data:www-data
