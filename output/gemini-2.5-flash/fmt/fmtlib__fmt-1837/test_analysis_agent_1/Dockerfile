# Base image specification. Defines the foundation OS and architecture for the container (Required)
FROM ubuntu:22.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# System dependencies installation. Installs essential tools and libraries required for development and runtime (Required)
RUN apt update && apt install -y \
    build-essential \
    cmake \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set default workdir to testbed. (Required)
WORKDIR /testbed/

# Target Project setup. Clones source code, checkouts to the target version, configures it, and installs project-specific dependencies
RUN git clone https://github.com/fmtlib/fmt /testbed && \
    cd /testbed && \
    git reset --hard c7e6d8afb06cec7b8244f963dc081daf7e70f7f6 && \
    git remote remove origin

# Build the project and its tests.
# This step compiles the fmt library and its test executables (including chrono-test),
# making them ready for execution by the evaluation script.
RUN mkdir build && \
    cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DFMT_TEST=ON -DCMAKE_CXX_STANDARD=17 && \
    make -j$(nproc)