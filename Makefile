TOPDIR=$(PWD)

.PHONY: all build run scan clean

all: build run

scan:
	trivy image --severity HIGH,CRITICAL \
	deb-postgres:latest > scanresults

run: build
	docker run -d \
	--name deb-postgres \
	-p 5433:5432 \
	-e POSTGRES_USER=myuser \
	-e POSTGRES_PASSWORD=mypassword \
	-e POSTGRES_DB=mydb \
	-e POSTGRES_EXTENSIONS='postgis vector pg_cron pgjwt pg_net pgmq pgrouting pgtap' \
	deb-postgres:latest

build:
	docker build -t deb-postgres:latest .

clean:
	docker kill deb-postgres || true
	docker rm -f deb-postgres
