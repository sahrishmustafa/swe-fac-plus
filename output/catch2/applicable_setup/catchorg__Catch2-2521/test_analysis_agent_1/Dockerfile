FROM --platform=linux/x86_64 ubuntu:22.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Install essential system dependencies:
# git: For cloning the repository.
# build-essential: Provides GCC/G++ and other foundational build tools for C++.
# cmake: The primary build system generator for Catch2.
# python3: Required for test-related scripts, as indicated in the context.
RUN apt update && apt install -y \
    git \
    build-essential \
    cmake \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory to /testbed/
WORKDIR /testbed/

# Clone the Catch2 repository into the working directory
RUN git clone https://github.com/catchorg/Catch2 .

# Checkout the specific commit SHA for reproducibility
RUN git reset --hard 359542d53ec142514da8a606ada8d9efd13b9678

# Configure and build the project using CMake.
# This step compiles the Catch2 library and its self-test executables,
# which are necessary for the provided test files to be executed.
# CMake is used to generate the build system, and then the project is built.
RUN mkdir build \
    && cmake -S . -B build \
    && cmake --build build -j$(nproc)