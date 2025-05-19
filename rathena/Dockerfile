FROM debian:11

# Install required packages
RUN apt-get update
RUN apt-get install -y git make gcc g++ zlib1g-dev \
  libpcre3-dev nano apt-utils dos2unix libmariadb* \
  default-mysql-client default-libmysqlclient-dev\
  procps

# Clean instalation
RUN apt-get clean

# Create volume mount point
VOLUME ["/rAthena"]

RUN mkdir -p /setup

# Set working directory
WORKDIR /setup

COPY accountsandchars.sql /setup
COPY firstaccount.sql /setup
COPY gab_npc.txt /setup
COPY docker-entrypoint.sh /setup
COPY start-server.sh /setup

RUN chmod +x /setup/docker-entrypoint.sh
RUN chmod +x /setup/start-server.sh

EXPOSE 6900/tcp 6121/tcp 5121/tcp

# We pending the server make when container run later

ENTRYPOINT ["/bin/bash", "/setup/docker-entrypoint.sh"]

# Allow container command override
CMD ["/bin/bash", "/setup/start-server.sh"]