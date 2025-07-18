# Base image specification. Defines the foundation OS and architecture for the container.
# Using python:3.11-slim-bookworm provides Python 3.11 and a slim Debian environment (Bookworm).
FROM python:3.11-slim-bookworm

# System dependencies installation. Installs essential tools required for cloning the repository
# and building Python packages that might have C extensions (like psutil).
# apt update and apt install for git and build-essential, followed by clearing apt lists to reduce image size.
RUN apt update && apt install -y git build-essential && rm -rf /var/lib/apt/lists/*

# Set the working directory inside the container to /testbed/. All subsequent commands will run from this directory.
WORKDIR /testbed/

# Target Project setup.
# 1. Clones the 'attrs' repository into the /testbed/ directory.
# 2. Changes the current directory to /testbed/.
# 3. Resets the repository to the specific commit SHA to ensure reproducibility.
# 4. Installs the core build dependencies (setuptools, wheel) explicitly.
# 5. Installs the 'attrs' project in editable mode, including its 'tests' and 'cov' extra dependencies.
#    This ensures that the project's local code is used and all necessary test dependencies
#    (like pytest, coverage, mypy, hypothesis, etc.) are installed.
RUN git clone https://github.com/python-attrs/attrs /testbed && \
    cd /testbed && \
    git reset --hard 67dc8cc261a5ef64f576ce73f2281cc9021d8fb4 && \
    pip install setuptools wheel && \
    pip install -e ".[tests,cov]"