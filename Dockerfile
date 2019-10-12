FROM php:7.2-cli AS php-builder
LABEL maintainer="steffen@mllrsohn.com"

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y git wget zip \
    && wget https://getcomposer.org/composer.phar -O /usr/local/bin/composer \
    && chmod +x /usr/local/bin/composer

WORKDIR /app
RUN composer global require hirak/prestissimo \
    && php -dmemory_limit=-1 /usr/local/bin/composer create-project --no-interaction --ignore-platform-reqs --prefer-dist --no-dev --no-progress \
        akeneo/pim-community-standard . "v3.2.12" \
    #&& php -dmemory_limit=-1 /usr/local/bin/composer require flagbit/table-attribute-bundle --ignore-platform-reqs --prefer-dist --no-progress \
    #&& php -dmemory_limit=-1 /usr/local/bin/composer require "akeneo-labs/custom-entity-bundle":"3.0.*" --prefer-dist --no-progress \
    #&& php -dmemory_limit=-1 /usr/local/bin/composer require "clickandmortar/advanced-csv-connector-bundle":"1.6.*" --ignore-platform-reqs --prefer-dist --no-progress \
    #&& php -dmemory_limit=-1 /usr/local/bin/composer --env=prod pim:installer:assets --symlink --clean \
    && rm -rf /app/var/*

# Build the fontend
FROM node:12 AS js-builder

WORKDIR /app
COPY --from=php-builder /app /app
RUN yarn install && yarn run webpack && rm -rf node_modules

# PHP Apache server
FROM php:7.2-apache

WORKDIR /app

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        git wget zip libzip-dev zlib1g-dev libicu-dev libpng-dev libfreetype6-dev libjpeg62-turbo-dev libmagickwand-dev \
    && wget https://getcomposer.org/composer.phar -O /usr/local/bin/composer \
    && chmod +x /usr/local/bin/composer

RUN docker-php-ext-install pdo zip pdo_mysql opcache bcmath exif \
    && pecl install imagick \
    && docker-php-ext-enable imagick \
    && pecl install apcu \
    && docker-php-ext-enable apcu \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-configure intl \
    && docker-php-ext-install intl \
    && a2enmod rewrite

COPY --chown=www-data:www-data  --from=js-builder /app /app

RUN mkdir -p /app/var/cache/prod \
    && mkdir -p /app/var/logs/ \
    && chown -R www-data:www-data /app
