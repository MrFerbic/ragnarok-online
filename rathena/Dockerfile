FROM debian:11

# Atualiza os pacotes e instala as dependências necessárias para compilar e rodar rAthena
RUN apt-get update && apt-get install -y \
    git make gcc g++ zlib1g-dev \
    libpcre3-dev nano apt-utils dos2unix libmariadb* \
    default-mysql-client default-libmysqlclient-dev \
    procps && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Cria um ponto para montagem de volume, onde os arquivos do servidor ficarão persistidos
VOLUME ["/rAthena"]

# Diretório de trabalho temporário para setup inicial
RUN mkdir -p /setup
WORKDIR /setup

# Copia scripts e arquivos necessários para dentro do container
COPY accountsandchars.sql firstaccount.sql gab_npc.txt docker-entrypoint.sh start-server.sh /setup/

# Dá permissão de execução para os scripts
RUN chmod +x docker-entrypoint.sh start-server.sh

# Expõe as portas padrão do servidor rAthena (login, char, map)
EXPOSE 6900/tcp 6121/tcp 5121/tcp

# EntryPoint padrão para inicializar a configuração ao iniciar o container
ENTRYPOINT ["/bin/bash", "/setup/docker-entrypoint.sh"]

# Comando padrão para rodar o servidor (pode ser sobrescrito)
CMD ["/bin/bash", "/setup/start-server.sh"]
