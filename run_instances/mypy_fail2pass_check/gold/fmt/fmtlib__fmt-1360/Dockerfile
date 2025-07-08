# Base image specification. Defines the foundation OS and architecture for the container
FROM ubuntu:22.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# System dependencies installation. Installs essential tools and libraries required for development and runtime
# build-essential provides g++ and make. cmake is for the build system.
# git is for cloning the repository. curl for general purpose.
# python3 is listed as a required tool for build scripts (`support/travis-build.py`).
RUN apt update && apt install -y \
    build-essential \
    cmake \
    git \
    curl \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Set default workdir to /testbed.
WORKDIR /testbed/

# Target Project setup. Clones source code, checkouts to the target version, and configures/builds the project.
RUN git clone https://github.com/fmtlib/fmt /testbed && \
    cd /testbed && \
    git reset --hard 96f91428c6ad2d19f1ce87ae160b78f52ed989fb && \
    git remote remove origin && \
    mkdir _build && \
    cd _build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=17 -DFMT_TEST=ON -DFMT_PEDANTIC=ON -DFMT_WERROR=ON && \
    cmake --build .