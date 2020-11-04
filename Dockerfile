FROM ubuntu:18.04

LABEL maintainer="Andrew Lees"

ARG GITHUB_TOKEN
ARG PHP_VERSION

ENV DEBIAN_FRONTEND=noninteractive COMPOSER_ALLOW_SUPERUSER=1 PHP_OPCACHE_VALIDATE_TIMESTAMPS=0

# Add wait-for-it. Allows us to wait for MySQL.
ADD https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh /bin/wait-for-it.sh
RUN chmod +x /bin/wait-for-it.sh

# Add necessary packages, namely PHP and Nginx.
RUN apt-get update && apt-get install -y software-properties-common curl && \
    LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php && add-apt-repository ppa:nginx/stable &&  \
    apt-get update && apt-get install -y --no-install-recommends \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-ldap \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-dom \
    php${PHP_VERSION}-redis \
    php${PHP_VERSION}-imap \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-sqlite \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-bcmath \
    php${PHP_VERSION}-intl \
    php${PHP_VERSION}-readline \
    php${PHP_VERSION}-igbinary \
    nginx \
    zip \
    git \
    unzip \
    supervisor \
    ca-certificates && \
    apt-get -y autoremove && apt-get clean && apt-get autoclean && rm -rf /var/lib/apt/lists/* && \
    # PHP-FPM configuration
	sed -i 's|.*error_log =.*|error_log=/proc/self/fd/2|g' 			/etc/php/${PHP_VERSION}/fpm/php-fpm.conf && \
	# PHP-FPM pool configuration
	sed -i 's|.*listen =.*|listen=9000|g' 							/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf && \
    sed -i 's|.*max_children =.*|pm.max_children = 50|g' 			/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf && \
    sed -i 's|.*min_spare_servers =.*|pm.min_spare_servers = 5|g' 	/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf && \
    sed -i 's|.*max_spare_servers =.*|pm.max_spare_servers = 45|g' 	/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf && \
    sed -i 's|.*start_servers =.*|pm.start_servers = 10|g' 			/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf && \
    sed -i 's|.*max_requests =.*|pm.max_requests = 1000|g' 			/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf && \
	sed -i 's|.*date.timezone.*|date.timezone=UTC|g' 				/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf && \
	sed -i 's|.*clear_env.*|clear_env=no|g' 						/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf && \
	# PHP.ini configuration
	sed -i 's|.*memory_limit=.*|memory_limit=256M|g' 							/etc/php/${PHP_VERSION}/fpm/php.ini && \
	sed -i 's|.*opcache.enable=.*|opcache.enable=1|g' 							/etc/php/${PHP_VERSION}/fpm/php.ini && \
	sed -i 's|.*opcache.save_comments=*|opcache.save_comments=0|g'			 	/etc/php/${PHP_VERSION}/fpm/php.ini && \
	sed -i 's|.*memory_consumption.*|opcache.memory_consumption=256|g'			/etc/php/${PHP_VERSION}/fpm/php.ini && \
	sed -i 's|.*interned_strings_buffer.*|opcache.interned_strings_buffer=64|g' /etc/php/${PHP_VERSION}/fpm/php.ini && \
	sed -i 's|.*max_accelerated_files.*|opcache.max_accelerated_files=32531|g' 	/etc/php/${PHP_VERSION}/fpm/php.ini && \
	sed -i 's|.*validate_timestamps.*|opcache.validate_timestamps=\${PHP_OPCACHE_VALIDATE_TIMESTAMPS}|g' /etc/php/${PHP_VERSION}/fpm/php.ini && \
	sed -i 's|.*revalidate_freq.*|opcache.revalidate_freq=0|g' 					/etc/php/${PHP_VERSION}/fpm/php.ini && \
	sed -i 's|.*upload_max_filesize.*|upload_max_filesize = 128M|g' 			/etc/php/${PHP_VERSION}/fpm/php.ini && \
	sed -i 's|.*post_max_size.*|post_max_size = 128M|g' 						/etc/php/${PHP_VERSION}/fpm/php.ini && \
	sed -i 's|.*variables_order.*|variables_order=EGPCS|g' 						/etc/php/${PHP_VERSION}/fpm/php.ini && \
	rm /etc/nginx/sites-available/default && rm /etc/nginx/sites-enabled/default && \
	# Composer install and configuration
	php -r "readfile('http://getcomposer.org/installer');" | php -- --install-dir=/usr/bin/ --version=1.10.16 --filename=composer
#    composer config ithub-oauth.github.com ${GITHUB_TOKEN}

# SSH Config
COPY config /root/.ssh/config
RUN chmod 400 /root/.ssh/config

# Supervisor and Nginx config
COPY supervisor /etc/supervisor
COPY nginx.conf /etc/nginx/nginx.conf

# Customise the php-fpm launcher
RUN sed -i "s|:PHP_VERSION|${PHP_VERSION}|g" /etc/supervisor/conf.d/php-fpm.conf

# Configure container healthcheck and start script
COPY health-check.conf /etc/nginx/sites-available/health-check
COPY health-check.php /usr/share/www/index.php
COPY start.sh health-check.sh /usr/local/bin/
RUN ln -s /etc/nginx/sites-available/health-check /etc/nginx/sites-enabled/health-check && \
	chown -R www-data: /usr/share/www && chmod u+x /usr/local/bin/start.sh /usr/local/bin/health-check.sh

HEALTHCHECK --start-period=7s --interval=10s --timeout=3s CMD /usr/local/bin/health-check.sh

# Container port
EXPOSE 80

# Default command to kick off our container
CMD ["/usr/local/bin/start.sh"]
