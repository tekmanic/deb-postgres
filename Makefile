all: build run 

run: build
	docker run -d \
	--name deb-postgres \
	-p 5433:5432 \
	-e POSTGRES_USER=myuser \
    -e POSTGRES_PASSWORD=mypassword \
    -e POSTGRES_DB=mydb \
    -e POSTGRES_EXTENSIONS='pg_stat_statements postgis' \
	deb-postgres:latest

build:
	docker build -t deb-postgres:latest .

clean:
	docker kill deb-postgres || true
	docker rm -f deb-postgres