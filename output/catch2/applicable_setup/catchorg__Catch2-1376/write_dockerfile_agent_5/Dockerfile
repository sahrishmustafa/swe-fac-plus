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
    && rm -rf /var/lib/apt/lists/*

# Set default workdir to /testbed/
WORKDIR /testbed/

# Target Project setup. Clones source code, checkouts to the target version
RUN git clone https://github.com/catchorg/Catch2.git . \
    && git reset --hard 1eb42eed974f944401091325bbe8e61b38fd0678 \
    && git remote remove origin

# Prepare and build the project as per Catch2's requirements
# This includes generating the single header and compiling the project, including test executables.
# Add -DBUILD_TESTING=ON to explicitly enable test target generation for CMake.
# Adjust CMAKE_CXX_FLAGS to include -DCATCH_CONFIG_NO_POSIX_SIGNALS and -Wno-error=redundant-move
RUN python3 scripts/generateSingleHeader.py \
    && mkdir Build \
    && cmake -H. -BBuild -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTING=ON -DCMAKE_CXX_FLAGS="-DCATCH_CONFIG_NO_POSIX_SIGNALS -Wno-error=redundant-move" \
    && cmake --build Build -j $(nproc)