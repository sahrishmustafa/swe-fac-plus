#!/bin/bash
set -uxo pipefail

# Navigate to the repository root directory, as Git operations are relative to it.
cd /testbed

# Checkout the specific test file to its original state at the commit SHA.
# This ensures a clean state before applying any potential patches, especially crucial
# if the file was modified by a previous test run or context.
git checkout 62460fafe6b54c3173bc5cbc46d05a5f071017ff "projects/SelfTest/UsageTests/Message.tests.cpp"

# Apply the test patch (if required) to modify the target test file(s).
# The content of the patch will be programmatically inserted here.
# This step is critical if the test requires specific modifications to pass or fail.
git apply -v - <<'EOF_114329324912'
diff --git a/projects/SelfTest/UsageTests/Message.tests.cpp b/projects/SelfTest/UsageTests/Message.tests.cpp
--- a/projects/SelfTest/UsageTests/Message.tests.cpp
+++ b/projects/SelfTest/UsageTests/Message.tests.cpp
@@ -9,10 +9,6 @@
 #include "catch.hpp"
 #include <iostream>
 
-#ifdef __clang__
-#pragma clang diagnostic ignored "-Wc++98-compat-pedantic"
-#endif
-
 TEST_CASE( "INFO and WARN do not abort tests", "[messages][.]" ) {
     INFO( "this is a " << "message" );    // This should output the message if a failure occurs
     WARN( "this is a " << "warning" );    // This should always output the message but then continue
@@ -135,3 +131,60 @@ TEST_CASE( "Pointers can be converted to strings", "[messages][.][approvals]" )
     WARN( "actual address of p: " << &p );
     WARN( "toString(p): " << ::Catch::Detail::stringify( &p ) );
 }
+
+TEST_CASE( "CAPTURE can deal with complex expressions", "[messages][capture]" ) {
+    int a = 1;
+    int b = 2;
+    int c = 3;
+    CAPTURE( a, b, c, a + b, a+b, c > b, a == 1 );
+    SUCCEED();
+}
+
+#ifdef __clang__
+#pragma clang diagnostic push
+#pragma clang diagnostic ignored "-Wunused-value" // In (1, 2), the "1" is unused ...
+#endif
+#ifdef __GNUC__
+#pragma GCC diagnostic push
+#pragma GCC diagnostic ignored "-Wunused-value" // All the comma operators are side-effect free
+#endif
+#ifdef _MSC_VER
+#pragma warning(push)
+#pragma warning(disable:4709) // comma in indexing operator
+#endif
+
+template <typename T1, typename T2>
+struct helper_1436 {
+    helper_1436(T1 t1, T2 t2):
+        t1{ t1 },
+        t2{ t2 }
+    {}
+    T1 t1;
+    T2 t2;
+};
+
+template <typename T1, typename T2>
+std::ostream& operator<<(std::ostream& out, helper_1436<T1, T2> const& helper) {
+    out << "{ " << helper.t1 << ", " << helper.t2 << " }";
+    return out;
+}
+
+TEST_CASE("CAPTURE can deal with complex expressions involving commas", "[messages][capture]") {
+    CAPTURE(std::vector<int>{1, 2, 3}[0, 1, 2],
+            std::vector<int>{1, 2, 3}[(0, 1)],
+            std::vector<int>{1, 2, 3}[0]);
+    CAPTURE((helper_1436<int, int>{12, -12}),
+            (helper_1436<int, int>(-12, 12)));
+    CAPTURE( (1, 2), (2, 3) );
+    SUCCEED();
+}
+
+#ifdef __clang__
+#pragma clang diagnostic pop
+#endif
+#ifdef __GNUC__
+#pragma GCC diagnostic pop
+#endif
+#ifdef _MSC_VER
+#pragma warning(pop)
+#endif
EOF_114329324912

# Navigate to the build directory where the Catch2 project was configured and built.
# All build artifacts and the CTest setup are located here.
cd build

# Execute the specific test cases from Message.tests.cpp
# Using [messages] tag to match the test cases
./projects/SelfTest "[messages]" --success
rc=$? # Capture the exit code of the test command immediately after execution.

# Echo the exit code in the required format for the test judge.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Navigate back to the repository root for cleanup.
cd /testbed

# Checkout the specific test file again to revert any changes made by the patch.
# This ensures that the file system is clean and restored to its original state
# after the test run, which is vital for subsequent operations or tests.
git checkout 62460fafe6b54c3173bc5cbc46d05a5f071017ff "projects/SelfTest/UsageTests/Message.tests.cpp"