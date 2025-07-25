# Base image specification. Defines the foundation OS and architecture for the container
FROM --platform=linux/x86_64 ubuntu:22.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# System dependencies installation. Installs essential tools and libraries required for development and runtime
RUN apt update && apt install -y \
    git \
    build-essential \
    cmake \
    python3 \
    python3-pip \
    valgrind \
    lcov \
    && rm -rf /var/lib/apt/lists/*

# Set default workdir to /testbed/ for cloning the repository
WORKDIR /testbed/

# Target Project setup. Clones source code, checkouts to the target version
RUN git clone https://github.com/catchorg/Catch2.git . \
    && git reset --hard 1faccd601d904a951142d8fba82914a8325b764e \
    && git remote remove origin

# Pre-build step: Generate the single header file required by Catch2's build process
RUN python3 scripts/generateSingleHeader.py

# Create a build directory and set it as the working directory for the build process
WORKDIR /testbed/build

# Configure Catch2 with CMake (enabling testing and debug build type) and compile the project
# -DCATCH_BUILD_TESTING=ON is crucial to ensure test executables are built.
# -DCMAKE_BUILD_TYPE=Debug sets the build type for debugging.
RUN cmake -DCATCH_BUILD_TESTING=ON -DCMAKE_BUILD_TYPE=Debug .. \
    && cmake --build . -j $(nproc)