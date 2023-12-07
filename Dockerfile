FROM composer:2.3 as composer

FROM php:8.1.23-apache

ARG GLPI_VERSION=10.0.3
ARG PHPCAS_VERSION=1.6.1

# Prepare SSL
RUN set -ex; \
 a2enmod ssl && a2enmod rewrite; \
 mkdir -p /etc/apache2/ssl; \
 sed -ir 's/<VirtualHost.*443>/<VirtualHost _default_:443>/g' /etc/apache2/sites-available/default-ssl.conf; \
 sed -ir 's/SSLCertificateFile.*/SSLCertificateFile \/etc\/apache2\/ssl\/ssl-cert.pem/g' /etc/apache2/sites-available/default-ssl.conf; \
 sed -ir 's/SSLCertificateKeyFile.*/SSLCertificateKeyFile \/etc\/apache2\/ssl\/ssl-cert.key/g' /etc/apache2/sites-available/default-ssl.conf; \
 sed -ir 's/#SSLCertificateChainFile.*/#SSLCertificateChainFile \/etc\/apache2\/ssl\/server-ca.crt/g' /etc/apache2/sites-available/default-ssl.conf;

# Install packages
RUN set -ex; \
 apt update; \
 apt-get install -y --no-install-recommends \
    cron \
    zlib1g-dev \
    libpng-dev \
    libicu-dev \
    libldap2-dev \
    libsasl2-dev \
    libxml2-dev \
    libzip-dev \
    libbz2-dev \
    libgd3 \
    libzip4; 
# Configure php extensions
RUN set -ex; \
  docker-php-ext-configure gd; \
  docker-php-ext-configure intl; \
  docker-php-ext-configure ldap --with-ldap-sasl --with-libdir="lib/$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"; \
  docker-php-ext-configure bz2;
# Install php extensions
RUN set -ex; \
  docker-php-ext-install -j "$(nproc)" \
    mysqli \
    gd \
    intl \
    ldap \
    opcache \
    exif \
    zip \
    bz2; \
  pecl install apcu; \
  docker-php-ext-enable apcu;
# Get glpi, extract and set ownership
WORKDIR /var/tmp
RUN set -ex; \
curl -fsSL -o ./glpi.tgz https://github.com/glpi-project/glpi/releases/download/${GLPI_VERSION}/glpi-${GLPI_VERSION}.tgz; \
tar --transform='flags=r;s/^glpi//' -xzf ./glpi.tgz -C /var/www/html; \
rm ./glpi.tgz; \
chown www-data:www-data -R /var/www/html; \
rm -rf /var/lib/apt/lists/*;
COPY local_define.php /var/www/html/config/
# Add scheduled task by cron
RUN set -ex; \
echo "*/2 * * * * www-data /usr/local/bin/php /var/www/html/front/cron.php &>/dev/null" > /etc/cron.d/glpi; \
crontab /etc/cron.d/glpi;
# Install phpCAS
COPY --from=composer /usr/bin/composer /usr/bin/composer
WORKDIR /var/tmp
# This is a bit tricky but that's the best solution I found to add phpCAS through composer while keeping the already installed dependancies
RUN set -ex; \ 
composer require apereo/phpcas:${PHPCAS_VERSION}; \
mv /var/tmp/vendor /var/www/html/phpCAS; \
rm -r /var/tmp/*; \
sed -ir '/require_once $autoload;/a require_once '\'/var/www/html/phpCAS/autoload.php\'';' /var/www/html/inc/autoload.function.php;

COPY php.ini "$PHP_INI_DIR/php.ini"

WORKDIR /usr/local/bin/
COPY docker-glpi-entrypoint ./
RUN chmod 755 ./docker-glpi-entrypoint
ENTRYPOINT ["./docker-glpi-entrypoint"]

CMD ["apache2-foreground"]

EXPOSE 80
EXPOSE 443