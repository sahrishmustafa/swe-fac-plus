# Base image specification. Defines the foundation OS and architecture for the container
FROM ubuntu:20.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# System dependencies installation. Installs essential tools and libraries required for development and runtime
# build-essential provides gcc, g++, and make. cmake is for the build system.
# ninja-build is for faster builds, specifically requested by the test setup.
# git is for cloning the repository.
# python3 is included based on the reference Dockerfile, suggesting its use in supporting scripts.
# g++-8 (and associated gcc-8) are installed from the Ubuntu Toolchain PPA, as required for C++14 support.
RUN apt update && apt install -y --no-install-recommends \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/* \
    && add-apt-repository -y ppa:ubuntu-toolchain-r/test \
    && apt update && apt install -y --no-install-recommends \
    build-essential \
    cmake \
    ninja-build \
    g++-8 \
    git \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Set g++-8 as the default g++ compiler using update-alternatives.
# This ensures that `g++` command points to version 8, which supports C++14 as required.
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 800 \
    --slave /usr/bin/g++ g++ /usr/bin/g++-8 \
    --slave /usr/bin/gcov gcov /usr/bin/gcov-8 \
    --slave /usr/bin/gfortran gfortran /usr/bin/gfortran-8

# Set default workdir to /testbed.
WORKDIR /testbed/

# Target Project setup. Clones source code and checkouts to the target version.
# The repository is cloned into /testbed, and the specific commit SHA for version 6.0 is checked out.
# 'git remote remove origin' is good practice for isolated environments.
RUN git clone https://github.com/fmtlib/fmt /testbed && \
    cd /testbed && \
    git reset --hard 1f918159edded99c9c0cf005c96ecc12e4cc92b1 && \
    git remote remove origin

# Build the project using CMake and Ninja.
# Create a build directory, configure CMake with specified options, and then build the project.
# The -G Ninja flag ensures that Ninja is used as the build system if available.
RUN mkdir build && \
    cd build && \
    cmake -G Ninja -DFMT_DOC=OFF -DFMT_PEDANTIC=ON -DFMT_WERROR=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=14 .. && \
    cmake --build .