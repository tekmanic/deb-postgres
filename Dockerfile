FROM debian:bullseye-slim
LABEL org.opencontainers.image.authors="tekmanic"

COPY ansible/ /tmp/ansible/

RUN apt update && \
    apt install -y ansible && \
    cd /tmp/ansible && \
    mkdir /etc/postgresql && \
    ansible-playbook playbook.yml && \
    apt -y update && \
    apt -y upgrade && \
    apt -y autoremove && \
    apt -y autoclean && \
    apt install -y default-jdk-headless && \
    rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

ENV LANGUAGE=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV PG_VERSION 14
ENV POSTGIS_VERSION 3

# Add scripts
ADD scripts /scripts
ADD scripts/sanity-test.sh /usr/bin/sanity-test
RUN chmod +x /scripts/*.sh /usr/bin/sanity-test
RUN touch /.firstrun

# Tweaks to the environment and locale for initdb
RUN touch /etc/environment && echo "PG_VERSION=${PG_VERSION}" >> /etc/environment && \
    touch /etc/locale.conf && echo "LANG=en_US.UTF-8" >> /etc/locale.conf && localedef -i en_US -f UTF-8 en_US.UTF-8

# Command to run
# ENTRYPOINT [ "tail", "-f", "/dev/null" ]
ENTRYPOINT ["/scripts/run.sh"]
CMD [""]

# Expose listen port
EXPOSE 5432

# VOLUME [ "/var/lib/postgresql/data" ]