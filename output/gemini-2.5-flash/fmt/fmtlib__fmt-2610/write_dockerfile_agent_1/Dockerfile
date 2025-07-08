# Base image specification. Defines the foundation OS and architecture for the container
FROM ubuntu:22.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Set locale environment variables for consistent behavior
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

# System dependencies installation. Installs essential tools and libraries required for development and runtime
# `build-essential` provides g++ (GCC compiler) and make, which are necessary for C++ projects.
# `cmake` is required for building the fmtlib project.
# `git` is needed for cloning the repository.
# `python3` and `ninja-build` are included as common development tools, aligning with the reference Dockerfile.
RUN apt update && apt install -y \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    python3 \
    ninja-build \
    && rm -rf /var/lib/apt/lists/*

# Set default workdir to /testbed. All subsequent commands will be run from this directory.
WORKDIR /testbed/

# Target Project setup. Clones the source code, checks out the specific commit,
# and builds the project. For C++ projects, the build process (`cmake` and `make`)
# is equivalent to "installing in development mode", ensuring the local source
# code is compiled and ready for testing.
# The 'test/compile-error-test' from the collected information is implicitly handled
# during the `cmake ..` configuration step.
RUN git clone https://github.com/fmtlib/fmt /testbed && \
    cd /testbed && \
    git reset --hard 19cac63fe4b4d8fe6a4ced28de16a68659cf9035 && \
    git remote remove origin && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make -j$(nproc)