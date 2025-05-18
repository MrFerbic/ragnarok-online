FROM debian:11

# Install required packages
RUN apt-get update
RUN apt-get install -y git make gcc g++ zlib1g-dev \
  libpcre3-dev nano apt-utils dos2unix libmariadb* \
  default-mysql-client default-libmysqlclient-dev\
  procps

RUN apt-get clean

# Using git pull method
RUN git clone https://github.com/rathena/rathena.git /rAthena
WORKDIR /rAthena
RUN git checkout master

# Using copied local rAthena source from monorepo
# COPY rAthena /rAthena
# WORKDIR /rAthena

RUN mv conf/import-tmpl conf/import
COPY accountsandchars.sql /
COPY gab_npc.txt /rAthena/npc/custom/

EXPOSE 6900/tcp 6121/tcp 5121/tcp

# We pending the server make when container run later

COPY docker-entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/bin/bash", "/usr/local/bin/docker-entrypoint.sh"]

# Set working directory
WORKDIR /rAthena

# Allow container command override
CMD ["/bin/bash", "/rAthena/athena-start", "watch"]