# Base image specification. Defines the foundation OS and architecture for the container
FROM ubuntu:22.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# System dependencies installation. Installs essential tools and libraries required for development and runtime
RUN apt update && apt install -y \
    build-essential \
    cmake \
    git \
    ninja-build \
    && rm -rf /var/lib/apt/lists/*

# set default workdir to testbed.
WORKDIR /testbed/

# Target Project setup. Clones source code, checkouts to the target version, configures it, and builds the project
RUN git clone https://github.com/fmtlib/fmt /testbed && \
    cd /testbed && \
    git reset --hard 1f918159edded99c9c0cf005c96ecc12e4cc92b1 && \
    git remote remove origin && \
    mkdir build && \
    cmake -S . -B build -D FMT_TEST=ON -D CMAKE_BUILD_TYPE=Release && \
    cmake --build build --target test