# Base image specification. Defines the foundation OS and architecture for the container
FROM ubuntu:22.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# System dependencies installation. Installs essential tools and libraries required for development and runtime
# build-essential provides g++ and make. cmake is for the build system.
# git is for cloning the repository. curl for general purpose.
# python3 is listed as a required tool for build scripts.
# software-properties-common is needed to add PPAs.
RUN apt update && apt install -y \
    software-properties-common \
    build-essential \
    cmake \
    git \
    curl \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Add ubuntu-toolchain-r/test PPA and install g++-8 for C++17 support
RUN add-apt-repository ppa:ubuntu-toolchain-r/test -y && \
    apt update && \
    apt install -y g++-8 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-8 800 && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 800 && \
    rm -rf /var/lib/apt/lists/*

# Set default workdir to /testbed.
WORKDIR /testbed/

# Target Project setup. Clones source code, checkouts to the target version, and configures/builds the project.
# This section performs the "installation in development mode" for C++ projects by building them from source.
RUN git clone https://github.com/fmtlib/fmt /testbed && \
    cd /testbed && \
    git reset --hard 96f91428c6ad2d19f1ce87ae160b78f52ed989fb && \
    git remote remove origin && \
    mkdir _build && \
    cd _build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=17 -DFMT_TEST=ON -DFMT_PEDANTIC=ON -DFMT_WERROR=ON && \
    cmake --build .