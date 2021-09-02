# base image
FROM postgres:13.4-buster
LABEL org.opencontainers.image.authors="tekmanic"

# run create.sql on init
ADD create.sql /docker-entrypoint-initdb.d

CMD [""]

# Expose listen port
EXPOSE 5432

# Expose our data directory
VOLUME ["/data"]
