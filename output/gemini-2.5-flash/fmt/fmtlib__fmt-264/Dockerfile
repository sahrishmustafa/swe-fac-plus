FROM --platform=linux/x86_64 ubuntu:18.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Install essential system dependencies: build-essential (which includes gcc/g++ version 7 by default on Ubuntu 18.04),
# cmake for build system, git for cloning, and gdb for debugging.
RUN apt update && apt install -y \
    build-essential \
    cmake \
    git \
    gdb \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory inside the container.
WORKDIR /testbed/

# Clone the target repository into the working directory.
RUN git clone https://github.com/fmtlib/fmt .

# Checkout the specific commit SHA to ensure reproducibility.
RUN git reset --hard 97e9ed11bce828235a25e2cb72910fa6928ffdf5

# Initialize and update Git submodules, which are required for dependencies like GoogleTest/GoogleMock.
RUN git submodule update --init

# Create a build directory, navigate into it, and configure the project with CMake.
# -DFMT_CHAR_WIDTH_MACRO=0 is added to resolve the compilation error related to CHAR_WIDTH macro conflict.
# CMake will automatically detect and use the default GCC/g++ (version 7) installed by build-essential.
# -DCMAKE_BUILD_TYPE=Release: Specifies a release build configuration.
# -DFMT_PEDANTIC=ON: Enables additional pedantic checks during compilation as suggested by the context.
# -DFMT_TEST=ON: Ensures the test target is enabled for building.
# Finally, compile the project using all available processor cores.
RUN mkdir build \
    && cd build \
    && cmake -DCMAKE_BUILD_TYPE=Release -DFMT_PEDANTIC=ON -DFMT_TEST=ON -DFMT_CHAR_WIDTH_MACRO=0 .. \
    && make -j "$(nproc)"