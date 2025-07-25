#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original state of the target test file(s) before applying any patch
git checkout 22ae8473fb88d6e585b05c709e81e1a46398a649 "tests/test_funcs.py"

# Apply test patch (content will be programmatically inserted)
git apply -v - <<'EOF_114329324912'
[CONTENT OF TEST PATCH]
EOF_114329324912

# Run target tests using tox for Python 3.11 environment.
# '-r' argument rebuilds the tox environment, ensuring a clean state.
# '-f py311' specifies the Python 3.11 environment.
# '--' separates tox arguments from arguments passed to the underlying test runner (pytest).
# '-Wd' is added to tell pytest to show all deprecation warnings, as advised by the analysis agent.
python -Im tox run -r -f py311 -- -Wd tests/test_funcs.py
rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up modified test files by reverting to the original state
git checkout 22ae8473fb88d6e585b05c709e81e1a46398a649 "tests/test_funcs.py"