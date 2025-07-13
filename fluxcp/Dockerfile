# Imagem base com PHP 8.1 + Apache, compatível com ARM64 (ex: Oracle Ampere)
FROM php:8.1-apache

# Instala extensões e dependências necessárias
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    git \
    && docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
    && docker-php-ext-install \
        pdo \
        pdo_mysql \
        mysqli \
        gd \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Ativa o módulo de reescrita do Apache (necessário para URLs amigáveis no FluxCP)
RUN a2enmod rewrite

# Cria diretório para scripts de setup
RUN mkdir -p /setup

# Copia o script de entrada
COPY docker-entrypoint.sh /setup/
RUN chmod +x /setup/docker-entrypoint.sh

# Define diretório de trabalho final para o Apache/FluxCP
WORKDIR /var/www/html

# Define o ponto de entrada do container
ENTRYPOINT ["/bin/bash", "/setup/docker-entrypoint.sh"]

# Expõe a porta padrão do Apache
EXPOSE 80
