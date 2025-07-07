#!/bin/bash
set -uxo pipefail
cd /testbed
# Checkout the original state of the target test file(s) before applying any patch
git checkout 0de967d6ece1606234ac56d5fe58a800d1b0434f "tests/test_make.py"

# Apply test patch (content will be programmatically inserted)
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# Run target tests using pytest
# The Dockerfile already set up the environment, so no explicit activation (like conda/venv) is needed.
# Everything is accessible through the global python 3.9 installation in the container.
python -m pytest tests/test_make.py
rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up modified test files by reverting to the original state
git checkout 0de967d6ece1606234ac56d5fe58a800d1b0434f "tests/test_make.py"