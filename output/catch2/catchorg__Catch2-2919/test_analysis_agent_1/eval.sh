#!/bin/bash
set -uxo pipefail

# Navigate to the repository root as defined in the Dockerfile
cd /testbed

# Reset target test file to ensure a clean state before applying patch
# This ensures that git apply operates on the original file content for the specified file.
git checkout fa43b77429ba76c462b1898d6cd2f2d7a9416b14 "tests/SelfTest/UsageTests/MatchersRanges.tests.cpp"

# Apply the test patch to the specified files
# The actual content of the patch will be programmatically inserted at the placeholder.
git apply -v - <<'EOF_114329324912'
diff --git a/tests/SelfTest/UsageTests/MatchersRanges.tests.cpp b/tests/SelfTest/UsageTests/MatchersRanges.tests.cpp
--- a/tests/SelfTest/UsageTests/MatchersRanges.tests.cpp
+++ b/tests/SelfTest/UsageTests/MatchersRanges.tests.cpp
@@ -727,6 +727,15 @@ TEST_CASE( "Usage of RangeEquals range matcher", "[matchers][templated][quantifi
                       } ) );
     }
 
+    SECTION( "Compare against std::initializer_list" ) {
+        const std::array<int, 3> array_a{ { 1, 2, 3 } };
+
+        REQUIRE_THAT( array_a, RangeEquals( { 1, 2, 3 } ) );
+        REQUIRE_THAT( array_a, RangeEquals( { 2, 4, 6 }, []( int l, int r ) {
+                          return l * 2 == r;
+                      } ) );
+    }
+
     SECTION("Check short-circuiting behaviour") {
         with_mocked_iterator_access<int> const mocked1{ 1, 2, 3, 4 };
 
@@ -820,6 +829,16 @@ TEST_CASE( "Usage of UnorderedRangeEquals range matcher",
 
         REQUIRE_THAT( needs_adl1, UnorderedRangeEquals( needs_adl2 ) );
     }
+
+    SECTION( "Compare against std::initializer_list" ) {
+        const std::array<int, 3> array_a{ { 1, 10, 20 } };
+
+        REQUIRE_THAT( array_a, UnorderedRangeEquals( { 10, 20, 1 } ) );
+        REQUIRE_THAT( array_a,
+                      UnorderedRangeEquals( { 11, 21, 2 }, []( int l, int r ) {
+                          return std::abs( l - r ) <= 1;
+                      } ) );
+    }
 }
 
 /**
EOF_114329324912

# Configure CMake project with the specified flags in a 'build' directory
# -Bbuild: Specifies 'build' as the binary directory
# -H.: Specifies the current directory as the source directory
# -DCATCH_DEVELOPMENT_BUILD=ON: Enables building tests and development features (as per skeleton)
# -DCATCH_BUILD_EXTRA_TESTS=ON: Crucial for including tests (as per skeleton)
# -G Ninja: Specifies Ninja as the build system generator
cmake -Bbuild -H. \
      -DCATCH_DEVELOPMENT_BUILD=ON \
      -DCATCH_BUILD_EXTRA_TESTS=ON \
      -G Ninja

# Build the project using Ninja, specifying the 'build' directory
# This command is run from the /testbed (repository root) directory.
ninja -C build

# Navigate into the build directory to run ctest
cd build

# Execute the specific target test using CTest with a regular expression filter.
# The collected information indicates 'ctest -R "MatchersRanges"' can run this test.
ctest -R "MatchersRanges"
rc=$?

# Navigate back to the repository root for cleanup
cd /testbed

# Echo the final exit code for the judge to process
echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up: Reset the target test file to its original state
# This command is run from the /testbed (repository root) directory.
git checkout fa43b77429ba76c462b1898d6cd2f2d7a9416b14 "tests/SelfTest/UsageTests/MatchersRanges.tests.cpp"