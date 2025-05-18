FROM php:8.1-apache

# Install PHP extensions
RUN apt-get update && apt-get install -y \
    libpng-dev libjpeg-dev libonig-dev libxml2-dev zip unzip git \
    && docker-php-ext-install pdo pdo_mysql mysqli gd

# Enable Apache mod_rewrite
RUN a2enmod rewrite

RUN mkdir -p /setup

# Set working directory
WORKDIR /setup

# Add entrypoint
COPY docker-entrypoint.sh /setup
RUN chmod +x /setup/docker-entrypoint.sh

# Create working directory
WORKDIR /var/www/html

ENTRYPOINT ["/bin/bash", "/setup/docker-entrypoint.sh"]

# Apache listens on port 80 by default
EXPOSE 80