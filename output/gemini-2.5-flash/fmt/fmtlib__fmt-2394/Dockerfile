# Base image specification. Defines the foundation OS and architecture for the container
FROM ubuntu:20.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Set locale environment variables for consistent behavior, as locales-all is installed
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

# System dependencies installation. Installs essential tools and libraries required for development and runtime
# Include build-essential, cmake, git, curl, python3, ninja-build as often required.
# Specifically install g++-10, clang-11 and related libc++ libraries as per collected information.
RUN apt update && apt install -y software-properties-common wget gnupg apt-transport-https && \
    # Add LLVM apt repository for clang-11 and related libraries, corrected GPG key URL
    wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - && \
    echo "deb http://apt.llvm.org/focal/ llvm-toolchain-focal-11 main" | tee /etc/apt/sources.list.d/llvm-11.list && \
    apt update && apt install -y \
    build-essential \
    cmake \
    git \
    curl \
    python3 \
    ninja-build \
    g++-10 \
    clang-11 \
    libc++-11-dev \
    libc++abi-11-dev \
    locales-all \
    && rm -rf /var/lib/apt/lists/*

# Set default workdir to /testbed.
WORKDIR /testbed/

# Target Project setup. Clones source code and checkouts to the target version.
# Note: Project build and test execution are handled by the evaluation script, not in the Dockerfile.
RUN git clone https://github.com/fmtlib/fmt /testbed && \
    cd /testbed && \
    git reset --hard cfc05e05f08dc0b6fe619831c96f00ee27d99613 && \
    git remote remove origin