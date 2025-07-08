FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

RUN apt update && apt install -y \
    git \
    build-essential \
    cmake \
    libssl-dev \
    zlib1g-dev \
    libbrotli-dev \
    libgtest-dev \
    python3 \
    openssl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /testbed/

RUN git clone https://github.com/yhirose/cpp-httplib.git /testbed
RUN cd /testbed && git reset --hard 3c522386e961d61768ea527d04713b5402356dd4

RUN cd /testbed/test && \
    openssl genrsa 2048 > key.pem && \
    python3 ../split.py -o . && \
    openssl req -new -batch -config test.conf -key key.pem | openssl x509 -days 3650 -req -signkey key.pem > cert.pem && \
    openssl req -x509 -config test.conf -key key.pem -sha256 -days 3650 -nodes -out cert2.pem -extensions SAN && \
    openssl genrsa 2048 > rootCA.key.pem && \
    openssl req -x509 -new -batch -config test.rootCA.conf -key rootCA.key.pem -days 1024 > rootCA.cert.pem && \
    openssl genrsa 2048 > client.key.pem && \
    openssl req -new -batch -config test.conf -key client.key.pem | openssl x509 -days 370 -req -CA rootCA.cert.pem -CAkey rootCA.key.pem -CAcreateserial > client.cert.pem && \
    g++ -o test -I.. -g -std=c++11 -I. -Wall -Wextra -Wtype-limits -Wconversion test.cc include_httplib.cc gtest/gtest-all.cc gtest/gtest_main.cc -DCPPHTTPLIB_OPENSSL_SUPPORT -lssl -lcrypto -DCPPHTTPLIB_ZLIB_SUPPORT -lz -DCPPHTTPLIB_BROTLI_SUPPORT -lbrotlicommon -lbrotlienc -lbrotlidec -pthread