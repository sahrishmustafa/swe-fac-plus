# Base image specification. Defines the foundation OS and architecture for the container (Required)
FROM ubuntu:22.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# System dependencies installation. Installs essential tools and libraries required for development and runtime (Required)
RUN apt update && apt install -y \
    build-essential \
    clang \
    cmake \
    git \
    ninja-build \
    && rm -rf /var/lib/apt/lists/*

# set default workdir to testbed. (Required)
WORKDIR /testbed/

# Target Project setup. Clones source code, checkouts to the target version, configures it, and installs project-specific dependencies
RUN git clone https://github.com/fmtlib/fmt /testbed && \
    cd /testbed && \
    git reset --hard 87fbc6f7566e4d3266bd3a2cd69f6c90e1aefa5d && \
    git remote remove origin

# Configure and build the project, including tests.
# A separate build directory is created for out-of-source builds.
# Reduced parallel jobs for make to avoid OOM issues during compilation.
RUN mkdir /testbed/build && \
    cd /testbed/build && \
    cmake -DFMT_TEST=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=14 .. && \
    make -j1