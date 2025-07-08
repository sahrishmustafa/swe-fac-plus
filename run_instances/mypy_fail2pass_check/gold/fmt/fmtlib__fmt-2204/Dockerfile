# Base image specification. Defines the foundation OS and architecture for the container
FROM ubuntu:22.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# System dependencies installation. Installs essential tools and libraries required for development and runtime
# build-essential provides gcc, g++, and make, which are necessary for compiling C++ projects.
# cmake is the required build system.
# git is for cloning the repository.
# ca-certificates is added to fix SSL certificate verification issues during git clone.
# python3 and curl are included as per the reference Dockerfile, suggesting their use in supporting scripts.
RUN apt update && apt install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
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
    git reset --hard 308510eb4fad9b112ebdd2867b0b96338b0a9a36 && \
    git remote remove origin