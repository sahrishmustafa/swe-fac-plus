# Base image specification based on the collected information.
# Changed to ubuntu:22.04 as ubuntu:20.10 is End of Life (EOL).
FROM ubuntu:22.04

# Set environment variables for non-interactive apt operations and timezone
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Install system dependencies required for building and testing the project
# This includes cmake for the build system, g++ for C++ compilation,
# git for cloning the repository, and tzdata for timezone configuration.
RUN apt update && \
    apt install -y \
    cmake \
    g++ \
    git \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory inside the container to /testbed
WORKDIR /testbed/

# Clone the target repository into the /testbed directory
RUN git clone https://github.com/simdjson/simdjson .

# Checkout the specific commit SHA for reproducibility
RUN git reset --hard c96ff018fedc7fe087b6f898442458a31a240a28 && \
    # Remove the remote origin to prevent accidental pushes or fetches to the original repo
    git remote remove origin

# Create a build directory and configure/build the project using CMake
# This prepares the environment for test execution by compiling the source code
# and linking necessary libraries.
RUN mkdir build && \
    cmake -S . -B build && \
    cmake --build build