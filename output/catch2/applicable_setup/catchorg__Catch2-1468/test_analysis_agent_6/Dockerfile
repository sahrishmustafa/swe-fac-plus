# Base image specification. Defines the foundation OS and architecture for the container
FROM --platform=linux/x86_64 ubuntu:18.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# System dependencies installation. Installs essential tools and libraries required for development and runtime
RUN apt update && apt install -y \
    git \
    build-essential \
    cmake \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages required for the build system (e.g., Conan)
RUN pip3 install \
    conan \
    conan-package-tools

# Set default workdir to /testbed/ for cloning the repository
WORKDIR /testbed/

# Target Project setup. Clones source code and checkouts to the target version
RUN git clone https://github.com/catchorg/Catch2.git . \
    && git reset --hard 4902cd721586822ded795afe0c418c553137306a \
    && git remote remove origin

# Set environment variable for the C++ compiler to use g++-7.
# On Ubuntu 18.04, build-essential provides g++-7 by default.
ENV CXX=g++-7