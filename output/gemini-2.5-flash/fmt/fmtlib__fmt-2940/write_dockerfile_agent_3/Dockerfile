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
RUN apt update && apt install -y \
    build-essential \
    cmake \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set default workdir to /testbed. All subsequent commands will be run from this directory.
WORKDIR /testbed/

# Target Project setup. Clones the source code, checks out the specific commit,
# and builds the project. For C++ projects, the build process (`cmake` and `make`)
# ensures the local source code is compiled and ready for testing.
# -DFMT_TEST=OFF is added to prevent building tests in the Dockerfile, saving resources.
# -j1 is used to limit parallel compilation jobs to mitigate OOM issues.
RUN git clone https://github.com/fmtlib/fmt /testbed && \
    cd /testbed && \
    git reset --hard eaa8efb950be5d8f1803a99b06f76cf398c67cb8 && \
    git remote remove origin && \
    mkdir build && \
    cd build && \
    cmake .. -DFMT_TEST=OFF && \
    cmake --build . -j1