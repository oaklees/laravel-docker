ARG ALPINE_VERSION=3.11

FROM alpine:${ALPINE_VERSION} as base

LABEL maintainer="Andrew Lees"
ENV COMPOSER_ALLOW_SUPERUSER=1 PHP_OPCACHE_VALIDATE_TIMESTAMPS=0
ARG GITHUB_TOKEN

# Add wait-for-it. Allows us to wait for MySQL.
ADD https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh /bin/wait-for-it.sh
RUN chmod +x /bin/wait-for-it.sh

# Add necessary packages, namely PHP and Nginx.
RUN apk --no-cache add \
    php7-bcmath \
    php7-calendar \
    php7-curl \
    php7-cli \
    php7-dom \
    php7-fpm \
    php7-gmp \
    php7-opcache \
    php7-intl \
    php7-imap \
    php7-imagick \
    php7-mbstring \
    php7-pdo_mysql \
    php7-json \
    php7-phar \
    php7-xmlwriter \
    php7-xml \
    php7-tokenizer \
    php7-fileinfo \
    php7-iconv \
    php7-simplexml \
    php7-redis \
    php7-soap \
    php7-zip \
    curl \
    nginx \
    supervisor

# PHP-FPM configuration
RUN sed -i 's|.*error_log =.*|error_log=/proc/self/fd/2|g' 			/etc/php7/php-fpm.conf && \
    # PHP-FPM pool configuration
    sed -i 's|.*listen =.*|listen = 9000|g' 						/etc/php7/php-fpm.d/www.conf && \
    sed -i 's|.*user =.*|user = nginx|g' 							/etc/php7/php-fpm.d/www.conf && \
    sed -i 's|.*group =.*|group = nginx|g' 							/etc/php7/php-fpm.d/www.conf && \
    sed -i 's|.*max_children =.*|pm.max_children = 50|g' 			/etc/php7/php-fpm.d/www.conf && \
    sed -i 's|.*min_spare_servers =.*|pm.min_spare_servers = 5|g' 	/etc/php7/php-fpm.d/www.conf && \
    sed -i 's|.*max_spare_servers =.*|pm.max_spare_servers = 45|g' 	/etc/php7/php-fpm.d/www.conf && \
    sed -i 's|.*start_servers =.*|pm.start_servers = 10|g' 			/etc/php7/php-fpm.d/www.conf && \
    sed -i 's|.*max_requests =.*|pm.max_requests = 1000|g' 			/etc/php7/php-fpm.d/www.conf && \
    sed -i 's|.*date.timezone.*|date.timezone=UTC|g' 				/etc/php7/php-fpm.d/www.conf && \
    sed -i 's|.*clear_env.*|clear_env=no|g' 						/etc/php7/php-fpm.d/www.conf && \
    # PHP.ini configuration
    sed -i 's|.*memory_limit=.*|memory_limit=256M|g' 							/etc/php7/php.ini && \
    sed -i 's|.*opcache.enable=.*|opcache.enable=1|g' 							/etc/php7/php.ini && \
    sed -i 's|.*opcache.save_comments=*|opcache.save_comments=0|g'			 	/etc/php7/php.ini && \
    sed -i 's|.*memory_consumption.*|opcache.memory_consumption=256|g'			/etc/php7/php.ini && \
    sed -i 's|.*interned_strings_buffer.*|opcache.interned_strings_buffer=64|g' /etc/php7/php.ini && \
    sed -i 's|.*max_accelerated_files.*|opcache.max_accelerated_files=32531|g' 	/etc/php7/php.ini && \
    sed -i 's|.*validate_timestamps.*|opcache.validate_timestamps=0|g' /etc/php7/php.ini && \
    sed -i 's|.*revalidate_freq.*|opcache.revalidate_freq=0|g' 					/etc/php7/php.ini && \
    sed -i 's|.*upload_max_filesize.*|upload_max_filesize = 128M|g' 			/etc/php7/php.ini && \
    sed -i 's|.*post_max_size.*|post_max_size = 128M|g' 						/etc/php7/php.ini && \
    sed -i 's|.*variables_order.*|variables_order=EGPCS|g' 						/etc/php7/php.ini

# Supervisor and Nginx config
COPY supervisor /etc/supervisor
COPY nginx.conf /etc/nginx/nginx.conf
RUN mkdir /run/nginx && mkdir /var/log/supervisor

# Configure container healthcheck and start script
COPY health-check.conf /etc/nginx/sites-available/health-check
COPY health-check.php /usr/share/www/index.php
COPY start.sh health-check.sh /usr/local/bin/
RUN mkdir /etc/nginx/sites-enabled && ln -s /etc/nginx/sites-available/health-check /etc/nginx/sites-enabled/health-check && \
    chown -R nginx: /usr/share/www && chmod u+x /usr/local/bin/start.sh /usr/local/bin/health-check.sh

HEALTHCHECK --start-period=7s --interval=10s --timeout=3s CMD /usr/local/bin/health-check.sh

# Container port
EXPOSE 80

# Default command to kick off our container
CMD ["/usr/local/bin/start.sh"]
