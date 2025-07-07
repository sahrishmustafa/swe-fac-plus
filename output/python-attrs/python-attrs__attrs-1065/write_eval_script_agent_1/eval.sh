#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout target test files to a clean state before applying patch
# This ensures that any previous runs or modifications are reset.
git checkout 67dc8cc261a5ef64f576ce73f2281cc9021d8fb4 "tests/dataclass_transform_example.py" "tests/test_functional.py" "tests/typing_example.py"

# Apply test patch if provided. The content of the patch will be inserted here.
git apply -v - <<'EOF_114329324912'
diff --git a/tests/dataclass_transform_example.py b/tests/dataclass_transform_example.py
--- a/tests/dataclass_transform_example.py
+++ b/tests/dataclass_transform_example.py
@@ -55,3 +55,9 @@ class AliasedField:
 af = AliasedField(42)
 
 reveal_type(af.__init__)  # noqa
+
+
+# unsafe_hash is accepted
+@attrs.define(unsafe_hash=True)
+class Hashable:
+    pass
diff --git a/tests/test_functional.py b/tests/test_functional.py
--- a/tests/test_functional.py
+++ b/tests/test_functional.py
@@ -739,3 +739,14 @@ class D(C):
         assert "_setattr('x', x)" in src
         assert "_setattr('y', y)" in src
         assert object.__setattr__ != D.__setattr__
+
+    def test_unsafe_hash(self, slots):
+        """
+        attr.s(unsafe_hash=True) makes a class hashable.
+        """
+
+        @attr.s(slots=slots, unsafe_hash=True)
+        class Hashable:
+            pass
+
+        assert hash(Hashable())
diff --git a/tests/typing_example.py b/tests/typing_example.py
--- a/tests/typing_example.py
+++ b/tests/typing_example.py
@@ -452,3 +452,8 @@ def accessing_from_attrs() -> None:
 foo = object
 if attrs.has(foo) or attr.has(foo):
     foo.__attrs_attrs__
+
+
+@attrs.define(unsafe_hash=True)
+class Hashable:
+    pass
EOF_114329324912

# Initialize overall exit code to 0 (success)
overall_rc=0

# Run functional and example tests using pytest
# Based on collected information, these are run with coverage and pytest.
coverage run -m pytest tests/dataclass_transform_example.py tests/test_functional.py -n auto
pytest_rc=$?
overall_rc=$((overall_rc || pytest_rc)) # Update overall_rc if pytest failed

# Run type checking tests using mypy
# Based on collected information, tests/typing_example.py is checked with mypy.
mypy tests/typing_example.py
mypy_rc=$?
overall_rc=$((overall_rc || mypy_rc)) # Update overall_rc if mypy failed

# Capture the final combined exit code
rc=$overall_rc

# Echo the exit code for the test log analysis agent
echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up modified test files by checking them out again to the commit SHA
git checkout 67dc8cc261a5ef64f576ce73f2281cc9021d8fb4 "tests/dataclass_transform_example.py" "tests/test_functional.py" "tests/typing_example.py"