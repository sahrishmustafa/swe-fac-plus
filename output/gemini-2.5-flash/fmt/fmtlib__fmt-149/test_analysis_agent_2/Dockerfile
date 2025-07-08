FROM --platform=linux/x86_64 ubuntu:22.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Install essential system dependencies: build-essential for C++ compiler and make, cmake for build system, and git for cloning.
RUN apt update && apt install -y \
    build-essential \
    cmake \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory inside the container.
WORKDIR /testbed/

# Clone the target repository and checkout the specific commit SHA.
RUN git clone https://github.com/fmtlib/fmt . \
    && git reset --hard 88f4be3d19364a484431309f750535386c7d0d5c

# Initialize and update Git submodules, which are required for dependencies like gmock.
RUN git submodule update --init

# Create a build directory, configure the project with CMake, and compile it.
# FMT_EXTRA_TESTS=ON ensures test executables are built.
# make -j "$(nproc)" compiles using all available processor cores.
RUN mkdir build \
    && cd build \
    && cmake -DCMAKE_BUILD_TYPE=Release -DFMT_EXTRA_TESTS=ON .. \
    && make -j "$(nproc)"