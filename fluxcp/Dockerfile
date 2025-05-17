FROM php:8.1-apache

# Install PHP extensions
RUN apt-get update && apt-get install -y \
    libpng-dev libjpeg-dev libonig-dev libxml2-dev zip unzip git \
    && docker-php-ext-install pdo pdo_mysql mysqli gd

# Enable Apache mod_rewrite
RUN a2enmod rewrite

# Copy FluxCP source
WORKDIR /var/www/html
RUN git clone https://github.com/rathena/FluxCP.git .

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html && chmod -R 755 /var/www/html

# Apache listens on port 80 by default
EXPOSE 80