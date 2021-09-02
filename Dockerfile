# base image
FROM postgres:13.4-buster
LABEL org.opencontainers.image.authors="tekmanic"

# run create.sql on init
ADD create.sql /docker-entrypoint-initdb.d
