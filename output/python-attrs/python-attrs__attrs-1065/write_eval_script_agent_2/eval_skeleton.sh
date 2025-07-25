#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout target test files to a clean state before applying patch
# This ensures that any previous runs or modifications are reset.
git checkout 67dc8cc261a5ef64f576ce73f2281cc9021d8fb4 "tests/dataclass_transform_example.py" "tests/test_functional.py" "tests/typing_example.py"

# Apply test patch if provided. The content of the patch will be inserted here.
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# Initialize overall exit code to 0 (success)
overall_rc=0

# Run functional tests using pytest
# tests/dataclass_transform_example.py was moved to mypy based on feedback.
coverage run -m pytest tests/test_functional.py -n auto
pytest_rc=$?
overall_rc=$((overall_rc || pytest_rc)) # Update overall_rc if pytest failed

# Run type checking tests using mypy
# Both tests/typing_example.py and tests/dataclass_transform_example.py are checked with mypy.
mypy tests/typing_example.py tests/dataclass_transform_example.py
mypy_rc=$?
overall_rc=$((overall_rc || mypy_rc)) # Update overall_rc if mypy failed

# Capture the final combined exit code
rc=$overall_rc

# Echo the exit code for the test log analysis agent
echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up modified test files by checking them out again to the commit SHA
git checkout 67dc8cc261a5ef64f576ce73f2281cc9021d8fb4 "tests/dataclass_transform_example.py" "tests/test_functional.py" "tests/typing_example.py"