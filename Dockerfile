# base image
FROM debian:bullseye-slim
LABEL org.opencontainers.image.authors="tekmanic"

# Install PostgreSQL 13
ENV PG_VERSION 13
RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update && \
    apt-get install -y gnupg2 wget lsb-release && \
    cd /tmp && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    postgresql-${PG_VERSION} postgresql-client-${PG_VERSION} postgresql-contrib-${PG_VERSION} \
    jq && \
    service postgresql stop && \
    apt-get remove -y --purge wget gnupg2 lsb-release && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    touch /etc/environment && echo "PG_VERSION=${PG_VERSION}" >> /etc/environment && \
    touch /etc/locale.conf && echo "LANG=en_US.UTF-8" >> /etc/locale.conf && localedef -i en_US -f UTF-8 en_US.UTF-8

# Add scripts
ADD scripts /scripts
ADD scripts/sanity-test.sh /usr/bin/sanity-test
RUN chmod +x /scripts/*.sh /usr/bin/sanity-test
RUN touch /.firstrun

# Command to run
ENTRYPOINT ["/scripts/run.sh"]
CMD [""]

# Expose listen port
EXPOSE 5432

# Expose our data directory
VOLUME ["/data"]