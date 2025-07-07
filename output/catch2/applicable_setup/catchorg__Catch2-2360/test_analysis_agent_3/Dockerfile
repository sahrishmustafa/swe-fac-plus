# Base image specification. Defines the foundation OS and architecture for the container
FROM ubuntu:20.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# System dependencies installation. Installs essential tools and libraries required for development and runtime
RUN apt update && apt install -y \
    build-essential \
    cmake \
    ninja-build \
    python3 \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set default working directory for the repository.
WORKDIR /testbed/

# Target Project setup. Clones source code, checks out to the target version.
RUN git clone https://github.com/catchorg/Catch2 /testbed \
    && cd /testbed \
    && git reset --hard 52066dbc2a53f4c3ab2a418d03f93200a8245451 \
    && git remote remove origin

# Build steps: Generate amalgamated files, configure CMake, and build the project including tests.
# These steps are necessary to prepare the environment for test execution.
RUN /bin/bash -c " \
    cd /testbed && \
    python3 ./tools/scripts/generateAmalgamatedFiles.py && \
    mkdir build && \
    cd build && \
    cmake -B. -H.. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
    -DCMAKE_CXX_EXTENSIONS=OFF \
    -DCATCH_DEVELOPMENT_BUILD=ON \
    -DCATCH_BUILD_TESTING=ON \
    -G Ninja && \
    ninja"