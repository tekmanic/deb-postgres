all: build run 

run: build
	docker run -d --name deb-postgres -p 5433:5432 deb-postgres:latest

build: 
	docker build -t deb-postgres:latest .

clean:
	docker kill deb-postgres
	docker rm -f deb-postgres