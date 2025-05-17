FROM debian:11

# Install required packages
RUN apt-get update
RUN apt-get install -y git make libmariadb-dev gcc g++ zlib1g-dev libpcre3-dev nano apt-utils dos2unix 

RUN apt-get clean

# Using git pull method
# RUN git clone https://github.com/rathena/rathena.git /rAthena &&
# RUN cd /rAthena 
# RUN git checkout master

# Copy local rAthena source from monorepo
COPY rAthena /rAthena

# Set working directory
WORKDIR /rAthena

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
COPY accountsandchars.sql /
COPY gab_npc.txt /rAthena/npc/custom/

EXPOSE 6900/tcp 6121/tcp 5121/tcp

# We pending the server make when container run later

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Set working directory
WORKDIR /rAthena

# Allow container command override
CMD ["/rAthena/athena-start", "watch"]