# Base image specification. Defines the foundation OS and architecture for the container (Required)
FROM ubuntu:20.04

# Set environment variables for non-interactive apt operations and timezone
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# System dependencies installation. Installs essential tools and libraries required for development and runtime (Required)
# Update package lists, upgrade existing packages, and install necessary packages:
# - build-essential: Provides essential tools like make, gcc, and g++ for compiling C++ projects.
# - git: Required for cloning the target repository.
# - wget: Common utility for downloading files.
# - cmake: The build system used by simdjson. Ubuntu 20.04 provides CMake 3.16.3, which satisfies simdjson's minimum requirement of 3.14.
# - g++-8: The specific C++ compiler version, satisfies the requirement of g++ version 7 or better.
RUN apt update && apt upgrade -y && \
    apt install -y \
    build-essential \
    git \
    wget \
    cmake \
    g++-8 && \
    rm -rf /var/lib/apt/lists/*

# Configure g++-8 as the default G++ and GCC compiler using update-alternatives.
# This step ensures that CMake and other build tools automatically pick version 8 of
# the compiler, matching the project's dependency requirements.
# A priority of 800 is used to make it the preferred default choice.
RUN update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-8 800 --slave /usr/bin/gcov gcov /usr/bin/gcov-8 && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 800 --slave /usr/bin/gcov-tool gcov-tool /usr/bin/gcov-tool-8

# Set the working directory inside the container
WORKDIR /testbed/

# Target Project setup. Clones the source code, checks out the specified commit SHA.
# The repository is cloned into /testbed/.
RUN git clone https://github.com/simdjson/simdjson.git /testbed/ && \
    cd /testbed/ && \
    git checkout 6cd04aa858f2d92105c0fbd65cdafb96428db002 && \
    git remote remove origin

# Configure and build the project.
# Create a build directory, navigate into it, and perform CMake configuration
# with SIMDJSON_DEVELOPER_MODE=ON to ensure tests and examples are included.
# Then, build the entire project. This prepares the environment for running tests.
# The '-j4' flag is used to limit parallel compilation jobs to 4, preventing
# potential out-of-memory errors, as observed in similar setups.
RUN cd /testbed/ && \
    mkdir build && \
    cd build && \
    cmake .. -DSIMDJSON_DEVELOPER_MODE=ON && \
    cmake --build . -j4

# Apply global read/write permissions for the testbed directory (including build artifacts)
# This ensures that any subsequent operations by the eval script have full access.
RUN chmod -R 777 /testbed