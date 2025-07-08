# Base image specification. Defines the foundation OS and architecture for the container
FROM ubuntu:22.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# System dependencies installation. Installs essential tools and libraries required for development and runtime
# build-essential provides gcc, g++, and make, which are necessary for compiling C++ projects.
# cmake is the required build system.
# git is for cloning the repository.
# libc++-dev is included for C++ standard library development files, as suggested.
# ca-certificates, python3, and curl are included as per the reference Dockerfile for general utility.
RUN apt update && apt install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    libc++-dev \
    ca-certificates \
    python3 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set default workdir to /testbed.
WORKDIR /testbed/

# Target Project setup. Clones source code and checkouts to the target version.
# The repository is cloned into /testbed.
# The specified commit SHA for version 7.1 is checked out to ensure reproducibility.
# 'git remote remove origin' is good practice for isolated environments.
RUN git clone https://github.com/fmtlib/fmt /testbed && \
    cd /testbed && \
    git reset --hard 7612f18dc8e0112e64e0845a1ebe9da6cfb8a123 && \
    git remote remove origin