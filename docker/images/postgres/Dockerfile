FROM postgres:17.5

# Устанавливаем зависимости для сборки расширения
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        postgresql-server-dev-${PG_MAJOR} \
        build-essential \
        ca-certificates \
        && \
    rm -rf /var/lib/apt/lists/*

# Клонируем и устанавливаем pg_uuidv7
RUN git clone https://github.com/fboulnois/pg_uuidv7.git /tmp/pg_uuidv7 && \
    cd /tmp/pg_uuidv7 && \
    make && \
    make install && \
    rm -rf /tmp/pg_uuidv7