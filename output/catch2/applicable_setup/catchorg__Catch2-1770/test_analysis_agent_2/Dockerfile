# Base image specification. Defines the foundation OS and architecture for the container (Required)
FROM ubuntu:20.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# System dependencies installation. Installs essential tools and libraries required for development and runtime (Required)
RUN apt update && apt install -y \
    build-essential \
    g++-8 \
    libstdc++-8-dev \
    python3 \
    python3-pip \
    python3-dev \
    valgrind \
    lcov \
    git \
    curl \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install specific CMake version 3.8.2 as required by the context.
# Ubuntu 20.04's default apt repository provides a newer CMake, so manual installation is necessary.
RUN mkdir -p /usr/local/cmake \
    && curl -sSL https://cmake.org/files/v3.8/cmake-3.8.2-Linux-x86_64.tar.gz -o /tmp/cmake.tar.gz \
    && tar --strip-components=1 -zxf /tmp/cmake.tar.gz -C /usr/local/cmake \
    && rm /tmp/cmake.tar.gz

# Set up environment variables as specified in the collected information.
ENV CXX=g++-8
ENV PATH="/usr/local/cmake/bin:${PATH}"

# Set default working directory for the repository. (Required)
WORKDIR /testbed/

# Target Project setup. Clones source code, checks out to the target version.
RUN git clone https://github.com/catchorg/Catch2 /testbed \
    && cd /testbed \
    && git reset --hard 01ef7076f50f5f2b481ddf082e1afca3c926983f \
    && git remote remove origin \
    && chmod -R 777 /testbed