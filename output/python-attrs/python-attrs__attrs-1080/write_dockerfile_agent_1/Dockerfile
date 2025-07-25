# Base image specification. Defines the foundation OS and architecture for the container.
# Using python:3.9-slim-buster provides Python 3.9 and a slim Debian environment.
FROM python:3.9-slim-buster

# System dependencies installation. Installs essential tools required for cloning the repository
# and building potential C extensions (build-essential).
RUN apt update && apt install -y git build-essential && rm -rf /var/lib/apt/lists/*

# Set the working directory inside the container to /testbed/. All subsequent commands will run from this directory.
WORKDIR /testbed/

# Target Project setup.
# 1. Clones the 'attrs' repository into the /testbed/ directory.
# 2. Changes the current directory to /testbed/.
# 3. Resets the repository to the specific commit SHA to ensure reproducibility.
# 4. Installs the core build dependencies (setuptools, wheel) that might be needed by pyproject.toml.
# 5. Installs the 'attrs' project in editable mode, including its 'tests' extra dependencies.
#    This ensures that the project's local code is used and all necessary test dependencies (like pytest) are installed.
RUN git clone https://github.com/python-attrs/attrs /testbed && \
    cd /testbed && \
    git reset --hard 0de967d6ece1606234ac56d5fe58a800d1b0434f && \
    pip install setuptools wheel && \
    pip install -e ".[tests]"