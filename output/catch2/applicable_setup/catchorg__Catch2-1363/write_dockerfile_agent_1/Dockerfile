# Base image specification. Defines the foundation OS and architecture for the container
FROM --platform=linux/x86_64 ubuntu:22.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# System dependencies installation. Installs essential tools and libraries required for development and runtime
RUN apt update && apt install -y \
    git \
    build-essential \
    cmake \
    && rm -rf /var/lib/apt/lists/*

# Set default workdir to /testbed/ for cloning the repository
WORKDIR /testbed/

# Target Project setup. Clones source code, checkouts to the target version
RUN git clone https://github.com/catchorg/Catch2.git . \
    && git reset --hard c9de7dd12d2971c63f9d32ce5459eb98f2fec13d \
    && git remote remove origin

# Create a build directory and perform the out-of-source build
RUN mkdir build
WORKDIR /testbed/build

# Configure Catch2 with CMake (enabling testing) and compile
RUN cmake -DCMAKE_BUILD_TYPE=Release -DCATCH_BUILD_TESTING=ON .. \
    && make -j $(nproc)