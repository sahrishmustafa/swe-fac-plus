#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original state of the target test file(s) before applying any patch
git checkout 22ae8473fb88d6e585b05c709e81e1a46398a649 "tests/test_funcs.py"

# Apply test patch (content will be programmatically inserted)
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_funcs.py b/tests/test_funcs.py
--- a/tests/test_funcs.py
+++ b/tests/test_funcs.py
@@ -689,3 +689,47 @@ class Cls2:
         assert Cls1({"foo": 42, "param2": 42}) == attr.evolve(
             obj1a, param1=obj2b
         )
+
+    def test_inst_kw(self):
+        """
+        If `inst` is passed per kw argument, a warning is raised.
+        See #1109
+        """
+
+        @attr.s
+        class C:
+            pass
+
+        with pytest.warns(DeprecationWarning) as wi:
+            evolve(inst=C())
+
+        assert __file__ == wi.list[0].filename
+
+    def test_no_inst(self):
+        """
+        Missing inst argument raises a TypeError like Python would.
+        """
+        with pytest.raises(TypeError, match=r"evolve\(\) missing 1"):
+            evolve(x=1)
+
+    def test_too_many_pos_args(self):
+        """
+        More than one positional argument raises a TypeError like Python would.
+        """
+        with pytest.raises(
+            TypeError,
+            match=r"evolve\(\) takes 1 positional argument, but 2 were given",
+        ):
+            evolve(1, 2)
+
+    def test_can_change_inst(self):
+        """
+        If the instance is passed by positional argument, a field named `inst`
+        can be changed.
+        """
+
+        @attr.define
+        class C:
+            inst: int
+
+        assert C(42) == evolve(C(23), inst=42)
EOF_114329324912

# Run target tests using tox for Python 3.11 environment.
# '-r' argument rebuilds the tox environment, ensuring a clean state.
# '-f py311' specifies the Python 3.11 environment.
# '--' separates tox arguments from arguments passed to the underlying test runner (pytest).
python -Im tox run -r -f py311 -- tests/test_funcs.py
rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up modified test files by reverting to the original state
git checkout 22ae8473fb88d6e585b05c709e81e1a46398a649 "tests/test_funcs.py"