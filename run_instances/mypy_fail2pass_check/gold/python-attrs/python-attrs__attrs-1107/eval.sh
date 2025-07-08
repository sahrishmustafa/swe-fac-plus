#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original state of the target test file(s) before applying any patch
git checkout 359c2db460f4410e86782a99eef06dabbfd96d34 "tests/test_next_gen.py"

# Apply test patch (content will be programmatically inserted)
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_next_gen.py b/tests/test_next_gen.py
--- a/tests/test_next_gen.py
+++ b/tests/test_next_gen.py
@@ -28,6 +28,16 @@ def test_simple(self):
         """
         C("1", 2)
 
+    def test_field_type(self):
+        """
+        Make class with attrs.field and type parameter.
+        """
+        classFields = {"testint": attrs.field(type=int)}
+
+        A = attrs.make_class("A", classFields)
+
+        assert int == attrs.fields(A).testint.type
+
     def test_no_slots(self):
         """
         slots can be deactivated.
EOF_114329324912

# Run target tests using pytest
# The Dockerfile already set up the environment by installing attrs with its test dependencies.
# Everything is accessible through the global python 3.9 installation in the container.
python -m pytest tests/test_next_gen.py
rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up modified test files by reverting to the original state
git checkout 359c2db460f4410e86782a99eef06dabbfd96d34 "tests/test_next_gen.py"