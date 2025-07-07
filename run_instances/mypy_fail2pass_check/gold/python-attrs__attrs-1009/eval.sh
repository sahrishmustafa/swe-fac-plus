#!/bin/bash
set -uxo pipefail
cd /testbed
git checkout 5ecc39749a98c7ec3fc63b8cbaa82de5eb17c173 "tests/test_slots.py"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_slots.py b/tests/test_slots.py
--- a/tests/test_slots.py
+++ b/tests/test_slots.py
@@ -9,6 +9,8 @@
 import types
 import weakref
 
+from unittest import mock
+
 import pytest
 
 import attr
@@ -743,3 +745,58 @@ def f(self):
 
     assert B(11).f == 121
     assert B(17).f == 289
+
+
+@attr.s(slots=True)
+class A:
+    x = attr.ib()
+    b = attr.ib()
+    c = attr.ib()
+
+
+@pytest.mark.parametrize("cls", [A])
+def test_slots_unpickle_after_attr_removed(cls):
+    """
+    We don't assign attributes we don't have anymore if the class has
+    removed it.
+    """
+    a = cls(1, 2, 3)
+    a_pickled = pickle.dumps(a)
+    a_unpickled = pickle.loads(a_pickled)
+    assert a_unpickled == a
+
+    @attr.s(slots=True)
+    class NEW_A:
+        x = attr.ib()
+        c = attr.ib()
+
+    with mock.patch(f"{__name__}.A", NEW_A):
+        new_a = pickle.loads(a_pickled)
+        assert new_a.x == 1
+        assert new_a.c == 3
+        assert not hasattr(new_a, "b")
+
+
+@pytest.mark.parametrize("cls", [A])
+def test_slots_unpickle_after_attr_added(cls):
+    """
+    We don't assign attribute we haven't had before if the class has one added.
+    """
+    a = cls(1, 2, 3)
+    a_pickled = pickle.dumps(a)
+    a_unpickled = pickle.loads(a_pickled)
+    assert a_unpickled == a
+
+    @attr.s(slots=True)
+    class NEW_A:
+        x = attr.ib()
+        b = attr.ib()
+        d = attr.ib()
+        c = attr.ib()
+
+    with mock.patch(f"{__name__}.A", NEW_A):
+        new_a = pickle.loads(a_pickled)
+        assert new_a.x == 1
+        assert new_a.b == 2
+        assert new_a.c == 3
+        assert not hasattr(new_a, "d")
EOF_114329324912

# Run target tests
python -m pytest tests/test_slots.py
rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up modified test files
git checkout 5ecc39749a98c7ec3fc63b8cbaa82de5eb17c173 "tests/test_slots.py"