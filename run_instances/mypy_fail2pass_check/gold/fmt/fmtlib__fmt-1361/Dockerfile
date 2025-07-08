# Base image specification. Defines the foundation OS and architecture for the container
FROM ubuntu:22.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# System dependencies installation. Installs essential tools and libraries required for development and runtime
# build-essential provides g++ and make. cmake is for the build system.
# git is for cloning the repository. curl for general purpose.
# python3 is listed as a required tool for build scripts.
# ninja-build is included for faster build times, as seen in project configurations.
RUN apt update && apt install -y \
    build-essential \
    cmake \
    git \
    curl \
    python3 \
    ninja-build \
    && rm -rf /var/lib/apt/lists/*

# Set default workdir to /testbed.
WORKDIR /testbed/

# Target Project setup. Clones source code and checkouts to the target version.
# Note: Project build and test execution are handled by the evaluation script, not in the Dockerfile.
RUN git clone https://github.com/fmtlib/fmt /testbed && \
    cd /testbed && \
    git reset --hard a5abe5d95cb8a8015913be9748a9661f3e1fbda8 && \
    git remote remove origin