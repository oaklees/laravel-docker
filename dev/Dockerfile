ARG BASE_VERSION=7.2

FROM 458118949611.dkr.ecr.eu-west-2.amazonaws.com/laravel-docker:${BASE_VERSION} as builder

# Compile pcov extension
RUN apk --no-cache add build-base php7-dev git && \
    git clone https://github.com/krakjoe/pcov.git && cd pcov && phpize && \
    ./configure --enable-pcov && \
    make && make test && make install

FROM 458118949611.dkr.ecr.eu-west-2.amazonaws.com/laravel-docker:${BASE_VERSION} as base

# Add dev packages.
RUN apk --no-cache add \
    php7-xdebug \
    php7-pdo_sqlite \
    php7-sqlite3 \
    git \
    openssh

# Copy over our compiled pcov extension
COPY --from=builder /usr/lib/php7/modules/pcov.so /usr/lib/php7/modules/pcov.so
COPY 00_pcov.ini ./00_xdebug.ini /etc/php7/conf.d/

# PHP-FPM configuration to validate timestamps for opcache
RUN sed -i 's|.*validate_timestamps.*|opcache.validate_timestamps=1|g' /etc/php7/php.ini && \
    # Composer install and configuration
    php -r "readfile('http://getcomposer.org/installer');" | php -- --install-dir=/usr/bin/ --version=1.10.16 --filename=composer

