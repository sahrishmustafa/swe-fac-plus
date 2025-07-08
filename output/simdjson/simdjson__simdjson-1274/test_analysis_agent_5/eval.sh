#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory where the repository is cloned
cd /testbed

# Checkout the specific test file to its original state before applying the patch.
# This ensures a clean slate for the patch application.
git checkout 265db2e533d4cdc8f7548717b911a92b6a7c9ec9 "tests/ondemand/ondemand_basictests.cpp"

# Apply the test patch. The content of the patch will be injected here.
git apply -v - <<'EOF_114329324912'
diff --git a/tests/ondemand/ondemand_basictests.cpp b/tests/ondemand/ondemand_basictests.cpp
--- a/tests/ondemand/ondemand_basictests.cpp
+++ b/tests/ondemand/ondemand_basictests.cpp
@@ -326,10 +326,25 @@ namespace number_tests {
     printf("Powers of 10 can be parsed.\n");
     return true;
   }
+
+  void github_issue_1273() {
+    padded_string bad(std::string_view("0.0300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000024000000000000000000000000000000000000000000000000000000000000122978293824"));
+    simdjson::builtin::ondemand::parser parser;
+    simdjson_unused auto blah=parser.iterate(bad);
+    double x;
+    simdjson_unused auto blah2=blah.get(x);
+  }
+
+  bool old_crashes() {
+    github_issue_1273();
+    return true;
+  }
+
   bool run() {
     return small_integers() &&
            powers_of_two() &&
-           powers_of_ten();
+           powers_of_ten() &&
+           old_crashes();
   }
 }
 
EOF_114329324912

# Crucial: After applying the patch, rebuild the project to ensure
# any changes or new tests are compiled into the test binaries.
# Change to the build directory as the project was built there.
cd build

# Rebuild the project. Use `make -j$(nproc)` to utilize all available cores,
# as per the Dockerfile compilation step.
echo "Rebuilding the project after patch application..."
make -j$(nproc)
build_rc=$?

# Check the exit code of the build command. If the build fails, exit immediately.
if [ $build_rc -ne 0 ]; then
    echo "Project rebuild failed with exit code $build_rc. Aborting test execution."
    OMNIGRIL_EXIT_CODE=1
    exit 1
fi

# Execute the specific tests related to 'ondemand_basictests.cpp' using CTest.
# The 'ctest -R' option is used to run tests matching the regex 'ondemand_basictests'.
# '--output-on-failure' displays test output only if a test fails.
echo "Running targeted tests: ctest -R ondemand_basictests"
ctest -R ondemand_basictests --output-on-failure
rc=$?

# Navigate back to the testbed root directory for cleanup.
cd /testbed

# Output the test execution exit code, as required by the evaluation system.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up: revert the test file to its original state using git checkout.
# This ensures that the testbed is reset for any subsequent operations.
git checkout 265db2e533d4cdc8f7548717b911a92b6a7c9ec9 "tests/ondemand/ondemand_basictests.cpp"