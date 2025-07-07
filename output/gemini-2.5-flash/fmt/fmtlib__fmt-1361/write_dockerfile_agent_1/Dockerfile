# Base image specification. Defines the foundation OS and architecture for the container
FROM ubuntu:22.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# System dependencies installation. Installs essential tools and libraries required for development and runtime
RUN apt update && apt install -y \
    git \
    cmake \
    build-essential \
    g++-8 \
    g++-6 \
    clang-6.0 \
    clang-4.0 \
    curl \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# set default workdir to testbed.
WORKDIR /testbed/

# Target Project setup. Clones source code, checkouts to the target version, configures it, and builds the project
RUN git clone https://github.com/fmtlib/fmt /testbed && \
    cd /testbed && \
    git reset --hard a5abe5d95cb8a8015913be9748a9661f3e1fbda8 && \
    git remote remove origin && \
    mkdir build && \
    cd build && \
    # Configure CMake with specified options and C++17 standard using g++-8
    CXX=g++-8 cmake \
        -DFMT_TEST=ON \
        -DFMT_PEDANTIC=ON \
        -DFMT_WERROR=ON \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_STANDARD=17 \
        .. && \
    # Build the project, including tests
    cmake --build .