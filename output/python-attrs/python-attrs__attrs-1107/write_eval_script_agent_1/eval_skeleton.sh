#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original state of the target test file(s) before applying any patch
git checkout 359c2db460f4410e86782a99eef06dabbfd96d34 "tests/test_next_gen.py"

# Apply test patch (content will be programmatically inserted)
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# Run target tests using pytest
# The Dockerfile already set up the environment by installing attrs with its test dependencies.
# Everything is accessible through the global python 3.9 installation in the container.
python -m pytest tests/test_next_gen.py
rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up modified test files by reverting to the original state
git checkout 359c2db460f4410e86782a99eef06dabbfd96d34 "tests/test_next_gen.py"