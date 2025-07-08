# Base image specification. Defines the foundation OS and architecture for the container
FROM --platform=linux/x86_64 ubuntu:20.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# System dependencies installation. Installs essential tools and libraries required for development and runtime
RUN apt update && apt install -y \
    git \
    build-essential \
    cmake \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Set default workdir to /testbed/ for cloning the repository
WORKDIR /testbed/

# Target Project setup. Clones source code, checkouts to the target version
RUN git clone https://github.com/catchorg/Catch2.git . \
    && git reset --hard 62460fafe6b54c3173bc5cbc46d05a5f071017ff \
    && git remote remove origin

# Pre-build step: Run the Python script to generate the single header file
RUN python3 scripts/generateSingleHeader.py

# Create a build directory and perform the out-of-source build
RUN mkdir build
WORKDIR /testbed/build

# New: Add CXXFLAGS environment variable to ensure -Wno-error and -Wno-redundant-move are propagated directly to g++.
ENV CXXFLAGS="-Wno-error -Wno-redundant-move"

# Configure Catch2 with CMake (enabling testing) and compile
# CATCH_BUILD_TESTING is ON by default, but explicitly set for clarity.
# CMAKE_BUILD_TYPE set to Release to avoid aggressive warning flags in Debug builds.
# Removed -DCATCH_BUILD_WARNINGS_AS_ERRORS=OFF as it's not recognized for this version.
# Removed -DCMAKE_CXX_FLAGS="-Wno-error" as CXXFLAGS environment variable is used instead.
RUN cmake .. -DCMAKE_BUILD_TYPE=Release -DCATCH_BUILD_TESTING=ON \
    && make -j $(nproc)