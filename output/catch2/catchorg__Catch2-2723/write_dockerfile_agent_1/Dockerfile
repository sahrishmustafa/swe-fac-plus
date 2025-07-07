FROM --platform=linux/x86_64 ubuntu:20.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Install essential tools and system dependencies
# build-essential for g++ and other build tools
# cmake minimum version 3.10 required
# ninja-build as the specified CMake generator
# python3 required by the root CMakeLists.txt
# git for cloning the repository
RUN apt update && \
    apt install -y \
    git \
    build-essential \
    cmake \
    ninja-build \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Set working directory to /testbed/
WORKDIR /testbed/

# Clone the repository and checkout the specific commit SHA
# Note: The provided commit SHA (4acc51828f7f93f3b2058a63f54d112af403450) is used as provided.
RUN git clone https://github.com/catchorg/Catch2.git /testbed/ && \
    cd /testbed/ && \
    git reset --hard 4acc51828f7f93f3b2058a63f54d112af403450 && \
    git remote remove origin

# Create a build directory and configure the project with CMake
# CMAKE_BUILD_TYPE=Release for an optimized build
# CMAKE_CXX_STANDARD=17 specifies the C++ standard
# CATCH_DEVELOPMENT_BUILD=ON is crucial for building and enabling tests
# -G Ninja specifies Ninja as the build system generator
RUN cmake -Bbuild -H. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
    -DCMAKE_CXX_EXTENSIONS=OFF \
    -DCATCH_DEVELOPMENT_BUILD=ON \
    -G Ninja

# Build the project using Ninja from within the build directory
# This command compiles the source code and creates executables, including tests.
RUN cmake --build build

# Set environment variable for CTest output, helpful for debugging test failures.
ENV CTEST_OUTPUT_ON_FAILURE=1