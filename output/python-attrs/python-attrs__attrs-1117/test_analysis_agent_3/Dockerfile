# Base image specification. Defines the foundation OS and architecture for the container.
# Using python:3.11-slim-buster as it's Debian-based and provides Python 3.11.
FROM python:3.11-slim-buster

# ARG DEBIAN_FRONTEND=noninteractive is not strictly necessary for slim images but doesn't hurt.
# ENV TZ=Etc/UTC is also not explicitly needed unless timezones cause issues for tests.
# Keeping it minimal as per context.

# System dependencies installation. Installs essential tools required for cloning the repository
# and building potential C extensions (build-essential).
RUN apt update && apt install -y \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory inside the container to /testbed/. All subsequent commands will run from this directory.
WORKDIR /testbed/

# Set crucial environment variables as specified by the context retrieval agent.
ENV SETUPTOOLS_SCM_PRETEND_VERSION="99.9.9" \
    FORCE_COLOR="1" \
    PIP_DISABLE_PIP_VERSION_CHECK="1" \
    PIP_NO_PYTHON_VERSION_WARNING="1" \
    HATCH_BUILD_HOOK_ENABLE_AUTORUN=1

# Install global Python dependencies required for test setup/execution.
# 'wheel' for building packages, 'tox' for running tests in isolated environments,
# and 'coverage[toml]' for test coverage reporting.
RUN pip install --no-cache-dir wheel tox 'coverage[toml]'

# Target Project setup.
# 1. Clones the 'attrs' repository into the /testbed/ directory.
# 2. Changes the current directory to /testbed/. (Implicitly done by WORKDIR, but good to clarify if changing sub-dir)
# 3. Resets the repository to the specific commit SHA to ensure reproducibility.
# Note: tox will handle installing the project with its test dependencies within its own virtual environments.
RUN git clone https://github.com/python-attrs/attrs /testbed && \
    cd /testbed && \
    git reset --hard 22ae8473fb88d6e585b05c709e81e1a46398a649

# No ENTRYPOINT is specified as per requirements.
# The evaluation script will execute the test command.