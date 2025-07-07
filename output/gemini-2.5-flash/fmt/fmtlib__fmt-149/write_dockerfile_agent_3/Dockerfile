# Base image specification. Defines the foundation OS and architecture for the container
FROM --platform=linux/x86_64 ubuntu:22.04

# Set environment variables for non-interactive apt operations and timezone
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# System dependencies installation. Installs essential tools and libraries required for development and runtime
# build-essential: Provides GNU compiler collection (GCC/g++), make, and other development utilities.
# cmake: Build system generator.
# git: Version control system for cloning the repository and managing submodules.
# gdb: GNU Debugger, required for diagnosing runtime crashes like SegFaults.
RUN apt update && apt install -y \
    build-essential \
    cmake \
    git \
    gdb \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory inside the container
WORKDIR /testbed/

# Target Project setup. Clones source code, checkouts to the target version, and configures it.
# 1. Clone the fmtlib/fmt repository into the /testbed directory.
# 2. Checkout the specific commit SHA to ensure reproducibility.
# 3. Update Git submodules, which fetch necessary dependencies like Google Test/Mock.
# 4. Create a 'build' directory, navigate into it, configure the project with CMake,
#    and then build the project and its tests using 'make'.
#    -DCMAKE_BUILD_TYPE=Debug configures a debug build with symbols, essential for GDB.
#    -DFMT_EXTRA_TESTS=ON enables the building of tests.
#    make -j$(nproc) compiles the project using all available CPU cores.
RUN git clone https://github.com/fmtlib/fmt . && \
    git reset --hard 88f4be3d19364a484431309f750535386c7d0d5c && \
    git submodule update --init && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Debug -DFMT_EXTRA_TESTS=ON .. && \
    make -j$(nproc)