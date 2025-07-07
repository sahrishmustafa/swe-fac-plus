FROM --platform=linux/x86_64 ubuntu:20.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Install essential tools and system dependencies
RUN apt update && \
    apt install -y \
    git \
    build-essential \
    cmake \
    ninja-build \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /testbed/

# Clone the repository and checkout the specific commit
RUN git clone https://github.com/catchorg/Catch2.git /testbed/ && \
    cd /testbed/ && \
    git reset --hard 8ce92d2c7288b6b3261caf1c016f8a779b6a8efc