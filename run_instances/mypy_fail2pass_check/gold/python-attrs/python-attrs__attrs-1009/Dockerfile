# Base image specification. Defines the foundation OS and architecture for the container.
# Using python:3.9-slim-buster provides Python 3.9 and a slim Debian environment.
FROM python:3.9-slim-buster

# System dependencies installation. Installs essential tools required for cloning the repository.
# apt update and apt install for git, followed by clearing apt lists to reduce image size.
RUN apt update && apt install -y git && rm -rf /var/lib/apt/lists/*

# Set the working directory inside the container to /testbed/. All subsequent commands will run from this directory.
WORKDIR /testbed/

# Target Project setup.
# 1. Clones the 'attrs' repository into the /testbed/ directory.
# 2. Changes the current directory to /testbed/.
# 3. Resets the repository to the specific commit SHA to ensure reproducibility.
# 4. Installs the core build dependencies (setuptools, wheel).
# 5. Installs the 'attrs' project in editable mode, including its 'tests' extra dependencies.
#    This ensures that the project's local code is used and all necessary test dependencies (like pytest) are installed.
RUN git clone https://github.com/python-attrs/attrs /testbed && \
    cd /testbed && \
    git reset --hard 5ecc39749a98c7ec3fc63b8cbaa82de5eb17c173 && \
    pip install setuptools wheel && \
    pip install -e ".[tests]"