#!/bin/bash
set -uxo pipefail
cd /testbed
git checkout 5ecc39749a98c7ec3fc63b8cbaa82de5eb17c173 "tests/test_slots.py"

# Apply test patch
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# Run target tests
python -m pytest tests/test_slots.py
rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up modified test files
git checkout 5ecc39749a98c7ec3fc63b8cbaa82de5eb17c173 "tests/test_slots.py"