FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Install essential tools and system libraries required for building and running tests.
# git: for cloning the repository.
# build-essential: provides core build utilities like g++ and make.
# cmake: Project's CMake build system, referred to in the README, though 'make' is used directly for tests.
# libssl-dev: For OpenSSL/HTTPS support as mentioned in README.md. (Ubuntu 20.04 uses OpenSSL 1.1.1)
# zlib1g-dev: For Zlib compression support.
# libbrotli-dev: For Brotli compression support.
# libgtest-dev: For the Google Test framework used by test/test.cc.
# python3: Required by the 'split.py' script during the build process.
# openssl: Command-line tool required for certificate generation.
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

# Set the working directory inside the container.
WORKDIR /testbed/

# Clone the target repository into the working directory.
RUN git clone https://github.com/yhirose/cpp-httplib.git /testbed

# Checkout the specific commit SHA to ensure reproducibility.
RUN git reset --hard e3e28c623165f9965efd2abbb7a31891c0fad684

# Build the test executable (test/test.cc).
# Replaced 'make' command with explicit build steps to prevent tests from running during Dockerfile build.
# This sequence performs certificate generation, runs split.py, and then compiles the test executable.
# The G++ command uses standard library paths for OpenSSL and Brotli, which are correctly handled by apt-installed packages.
RUN cd test && \
    openssl genrsa 2048 > key.pem && \
    python3 ../split.py -o . && \
    openssl req -new -batch -config test.conf -key key.pem | openssl x509 -days 3650 -req -signkey key.pem > cert.pem && \
    openssl req -x509 -config test.conf -key key.pem -sha256 -days 3650 -nodes -out cert2.pem -extensions SAN && \
    openssl genrsa 2048 > rootCA.key.pem && \
    openssl req -x509 -new -batch -config test.rootCA.conf -key rootCA.key.pem -days 1024 > rootCA.cert.pem && \
    openssl genrsa 2048 > client.key.pem && \
    openssl req -new -batch -config test.conf -key client.key.pem | openssl x509 -days 370 -req -CA rootCA.cert.pem -CAkey rootCA.key.pem -CAcreateserial > client.cert.pem && \
    g++ -o test -I.. -g -std=c++11 -I. -Wall -Wextra -Wtype-limits -Wconversion  test.cc include_httplib.cc gtest/gtest-all.cc gtest/gtest_main.cc -DCPPHTTPLIB_OPENSSL_SUPPORT -lssl -lcrypto -DCPPHTTPLIB_ZLIB_SUPPORT -lz -DCPPHTTPLIB_BROTLI_SUPPORT -lbrotlicommon -lbrotlienc -lbrotlidec -pthread