FROM --platform=linux/x86_64 ubuntu:22.04
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
    git reset --hard fa43b77429ba76c462b1898d6cd2f2d7a9416b14