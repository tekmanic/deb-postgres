# ---------------------------------------------------------------------------
# Builder stage: compile the source-built extensions against PostgreSQL 18
# headers (from the PGDG apt repository). Nothing from this stage except the
# installed extension files makes it into the final image.
# ---------------------------------------------------------------------------
FROM debian:trixie-slim AS builder

ARG DEBIAN_FRONTEND=noninteractive

# Add the PGDG apt repository (provides postgresql-server-dev-18)
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends ca-certificates curl gnupg; \
	curl -sSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/pgdg.gpg; \
	echo "deb [signed-by=/etc/apt/trusted.gpg.d/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt trixie-pgdg main" > /etc/apt/sources.list.d/pgdg.list; \
	apt-get update; \
	# libicu-dev: PG18 server headers unconditionally include <unicode/ucol.h>
	# libcurl4-openssl-dev: required by pg_net (HTTP extension)
	apt-get install -y --no-install-recommends build-essential postgresql-server-dev-18 libicu-dev libcurl4-openssl-dev; \
	rm -rf /var/lib/apt/lists/*

WORKDIR /build

# --- pgjwt (michelp/pgjwt) -------------------------------------------------
# Pinned by commit: upstream has no git tags and no GitHub releases.
ARG PGJWT_COMMIT=f3d82fd30151e754e19ce5d6a06c71c20689ce3d
ARG PGJWT_SHA256=dae8ed99eebb7593b43013f6532d772b12dfecd55548d2673f2dfd0163f6d2b9
RUN set -eux; \
	curl -sSLf -o pgjwt.tar.gz "https://github.com/michelp/pgjwt/archive/${PGJWT_COMMIT}.tar.gz"; \
	echo "${PGJWT_SHA256}  pgjwt.tar.gz" | sha256sum -c -; \
	tar -xzf pgjwt.tar.gz; \
	cd "pgjwt-${PGJWT_COMMIT}"; \
	make; \
	make install

# --- pg_net (supabase/pg_net) ----------------------------------------------
ARG PG_NET_VERSION=0.20.5
ARG PG_NET_SHA256=a0a2611ea6fbbc93ef553ff057d97d3a857136742cb50605058744bf57fe6c27
RUN set -eux; \
	curl -sSLf -o pg_net.tar.gz "https://github.com/supabase/pg_net/archive/refs/tags/v${PG_NET_VERSION}.tar.gz"; \
	echo "${PG_NET_SHA256}  pg_net.tar.gz" | sha256sum -c -; \
	tar -xzf pg_net.tar.gz; \
	cd "pg_net-${PG_NET_VERSION}"; \
	make; \
	make install

# --- pgmq (pgmq/pgmq) -------------------------------------------------------
# Extension sources live in the pgmq-extension/ subdirectory.
ARG PGMQ_VERSION=1.13.0
ARG PGMQ_SHA256=c980705ffa2a731b69f3d26be5650d6fbcc76b2b9add67b138da4ee74a4579a5
RUN set -eux; \
	curl -sSLf -o pgmq.tar.gz "https://github.com/pgmq/pgmq/archive/refs/tags/v${PGMQ_VERSION}.tar.gz"; \
	echo "${PGMQ_SHA256}  pgmq.tar.gz" | sha256sum -c -; \
	tar -xzf pgmq.tar.gz; \
	cd "pgmq-${PGMQ_VERSION}/pgmq-extension"; \
	make; \
	make install

# ---------------------------------------------------------------------------
# Final stage
# ---------------------------------------------------------------------------
FROM debian:trixie-slim
LABEL org.opencontainers.image.authors="tekmanic"

ARG DEBIAN_FRONTEND=noninteractive

# Add the PGDG apt repository and install PostgreSQL 18 + the apt extensions
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends ca-certificates curl gnupg locales openssl; \
	curl -sSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/pgdg.gpg; \
	echo "deb [signed-by=/etc/apt/trusted.gpg.d/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt trixie-pgdg main" > /etc/apt/sources.list.d/pgdg.list; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		postgresql-18 \
		postgresql-client-18 \
		libcurl4t64 \
		postgresql-18-postgis-3 \
		postgresql-18-postgis-3-scripts \
		postgresql-18-pgrouting \
		postgresql-18-pgrouting-scripts \
		postgresql-18-pgtap \
		postgresql-18-cron \
		postgresql-18-pgvector; \
	# the package postinst creates a default cluster at /var/lib/postgresql/18/main;
	# this image uses PGDATA=/var/lib/postgresql/data instead
	pg_dropcluster 18 main; \
	apt-get autoremove -y; \
	apt-get autoclean; \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Source-built extensions (compiled in the builder stage).
# pg_net is the only C extension (pgjwt and pgmq are pure-SQL); its .so is
# installed into the PG18 pkglibdir by PGXS.
COPY --from=builder /usr/lib/postgresql/18/lib/pg_net.so /usr/lib/postgresql/18/lib/
COPY --from=builder /usr/share/postgresql/18/extension/pgjwt* /usr/share/postgresql/18/extension/
COPY --from=builder /usr/share/postgresql/18/extension/pg_net* /usr/share/postgresql/18/extension/
COPY --from=builder /usr/share/postgresql/18/extension/pgmq* /usr/share/postgresql/18/extension/

# Locale setup for initdb
RUN localedef -i en_US -f UTF-8 en_US.UTF-8

ENV PG_VERSION=18
ENV LANGUAGE=en_US.UTF-8
ENV LANG=en_US.UTF-8

# Configuration + scripts
COPY etc/postgresql/ /etc/postgresql/
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh && touch /.firstrun

# Remove setuid/setgid bits to prevent privilege escalation
RUN find / -xdev -perm /6000 -type f -exec chmod a-s {} +

# Expose listen port
EXPOSE 5432

# Command to run
ENTRYPOINT ["/scripts/run.sh"]
