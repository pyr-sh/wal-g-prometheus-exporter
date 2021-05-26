# Build exporter
FROM python:3.9.5 AS exporter-builder

WORKDIR /usr/src/

COPY requirements.txt /usr/src/
RUN pip3 install -r requirements.txt
ADD exporter.py /usr/src/
RUN pyinstaller --onefile exporter.py && \
    mv dist/exporter wal-g-prometheus-exporter

FROM golang:1.16 AS wal-g-builder

RUN apt-get update && \
    apt-get install -y \
        liblzo2-dev=2.10-0.1 \
        build-essential=12.6 \
        cmake=3.13.4-1 && \
    rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/wal-g/wal-g.git /build && \
    cd /build && \
    git checkout 01c227fae07fee8e91a2392b3a5b42ddf7900e66 && \
    make install && \
    make deps && \
    make pg_build

# Build final image
FROM debian:10
COPY --from=exporter-builder /usr/src/wal-g-prometheus-exporter /usr/local/bin/
COPY --from=wal-g-builder /build/main/pg/wal-g /usr/bin/

RUN apt-get update && \
    apt-get install -y \
    ca-certificates=20200601~deb10u2 && \
    rm -rf /var/lib/apt/lists

ENTRYPOINT ["/usr/local/bin/wal-g-prometheus-exporter"]
