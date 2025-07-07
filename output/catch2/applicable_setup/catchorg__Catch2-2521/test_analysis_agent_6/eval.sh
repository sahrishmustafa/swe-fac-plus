#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory where the repository is cloned
cd /testbed

# Checkout the specific target files to their original state before applying the patch.
# This ensures that only the intended files are affected by the patch.
git checkout 359542d53ec142514da8a606ada8d9efd13b9678 "src/catch2/internal/catch_test_macro_impl.hpp"

# Apply the test patch to the specified files.
# The content of the patch will be programmatically inserted at the placeholder.
git apply -v - <<'EOF_114329324912'
diff --git a/src/catch2/internal/catch_test_macro_impl.hpp b/src/catch2/internal/catch_test_macro_impl.hpp
--- a/src/catch2/internal/catch_test_macro_impl.hpp
+++ b/src/catch2/internal/catch_test_macro_impl.hpp
@@ -76,7 +76,10 @@
     do { \
         Catch::AssertionHandler catchAssertionHandler( macroName##_catch_sr, CATCH_INTERNAL_LINEINFO, CATCH_INTERNAL_STRINGIFY(__VA_ARGS__), resultDisposition ); \
         try { \
+            CATCH_INTERNAL_START_WARNINGS_SUPPRESSION \
+            CATCH_INTERNAL_SUPPRESS_USELESS_CAST_WARNINGS \
             static_cast<void>(__VA_ARGS__); \
+            CATCH_INTERNAL_STOP_WARNINGS_SUPPRESSION \
             catchAssertionHandler.handleExceptionNotThrownAsExpected(); \
         } \
         catch( ... ) { \
@@ -91,7 +94,10 @@
         Catch::AssertionHandler catchAssertionHandler( macroName##_catch_sr, CATCH_INTERNAL_LINEINFO, CATCH_INTERNAL_STRINGIFY(__VA_ARGS__), resultDisposition); \
         if( catchAssertionHandler.allowThrows() ) \
             try { \
+                CATCH_INTERNAL_START_WARNINGS_SUPPRESSION \
+                CATCH_INTERNAL_SUPPRESS_USELESS_CAST_WARNINGS \
                 static_cast<void>(__VA_ARGS__); \
+                CATCH_INTERNAL_STOP_WARNINGS_SUPPRESSION \
                 catchAssertionHandler.handleUnexpectedExceptionNotThrown(); \
             } \
             catch( ... ) { \
@@ -108,7 +114,10 @@
         Catch::AssertionHandler catchAssertionHandler( macroName##_catch_sr, CATCH_INTERNAL_LINEINFO, CATCH_INTERNAL_STRINGIFY(expr) ", " CATCH_INTERNAL_STRINGIFY(exceptionType), resultDisposition ); \
         if( catchAssertionHandler.allowThrows() ) \
             try { \
+                CATCH_INTERNAL_START_WARNINGS_SUPPRESSION \
+                CATCH_INTERNAL_SUPPRESS_USELESS_CAST_WARNINGS \
                 static_cast<void>(expr); \
+                CATCH_INTERNAL_STOP_WARNINGS_SUPPRESSION \
                 catchAssertionHandler.handleUnexpectedExceptionNotThrown(); \
             } \
             catch( exceptionType const& ) { \
@@ -131,7 +140,10 @@
         Catch::AssertionHandler catchAssertionHandler( macroName##_catch_sr, CATCH_INTERNAL_LINEINFO, CATCH_INTERNAL_STRINGIFY(__VA_ARGS__) ", " CATCH_INTERNAL_STRINGIFY(matcher), resultDisposition ); \
         if( catchAssertionHandler.allowThrows() ) \
             try { \
+                CATCH_INTERNAL_START_WARNINGS_SUPPRESSION \
+                CATCH_INTERNAL_SUPPRESS_USELESS_CAST_WARNINGS \
                 static_cast<void>(__VA_ARGS__); \
+                CATCH_INTERNAL_STOP_WARNINGS_SUPPRESSION \
                 catchAssertionHandler.handleUnexpectedExceptionNotThrown(); \
             } \
             catch( ... ) { \
EOF_114329324912

# Rebuild the project after applying the patch.
# This is crucial for C++ projects, especially when header files (`.hpp`) are modified,
# to ensure that compiled tests pick up the changes.
# The Dockerfile now explicitly passes -DCATCH_BUILD_TESTING=ON during initial configuration,
# so a simple rebuild from the build directory is sufficient.
cmake --build build -j$(nproc)

# Navigate to the build directory where the tests are located and executable.
cd build

# Execute the tests using ctest, which is the correct runner for Catch2's self-tests
# configured via CMake. -VV provides verbose output for detailed logs.
ctest -VV
rc=$? # Capture the exit code of the test command

# Return to the /testbed directory for proper cleanup operations.
cd ..

# Output the captured exit code for external systems to evaluate test success or failure.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up modified files by checking them out to their original state.
git checkout 359542d53ec142514da8a606ada8d9efd13b9678 "src/catch2/internal/catch_test_macro_impl.hpp"