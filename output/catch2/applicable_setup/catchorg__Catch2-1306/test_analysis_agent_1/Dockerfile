FROM ubuntu:20.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ="Etc/UTC"

# Install essential system dependencies: git for cloning, build-essential for C++ compilation,
# cmake for build system generation, and python3 for pre-build script.
RUN apt update && apt install -y \
    git \
    build-essential \
    cmake \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory inside the container to /testbed.
# All subsequent commands will be executed from this directory.
WORKDIR /testbed/

# Clone the target repository into the working directory.
RUN git clone https://github.com/catchorg/Catch2.git .

# Checkout the specific commit SHA for reproducibility.
RUN git reset --hard 021fcee63667e346c619e04bbae932bcea562334

# Execute the pre-build step: generate the single header file for Catch2.
RUN python3 scripts/generateSingleHeader.py

# Create a build directory and configure CMake.
# -H. specifies the source directory (current directory).
# -BBuild specifies the build directory inside the current working directory.
# -DCMAKE_BUILD_TYPE=Release sets the build type to Release for optimized compilation.
# -DUSE_CPP14=1 enables C++14 support, as specified in the context.
RUN mkdir Build
RUN cmake -H. -BBuild -DCMAKE_BUILD_TYPE=Release -DUSE_CPP14=1

# The project is now configured. The actual build and test execution will be performed
# by the evaluation script using cmake --build Build and ctest.