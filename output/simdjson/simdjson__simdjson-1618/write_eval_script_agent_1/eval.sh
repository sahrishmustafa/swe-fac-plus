#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory where the repository is cloned
cd /testbed

# Checkout the specific target test file to its original state before applying any patch.
# This ensures a clean base for the patch application.
# The commit SHA and file path are directly from the provided info and skeleton.
git checkout 1c01fc35ebce2d50ea6c279002ca949784d71ad4 "tests/ondemand/ondemand_readme_examples.cpp"

# Apply the test patch to modify/add tests.
# The content of the patch will be programmatically inserted here.
git apply -v - <<'EOF_114329324912'
diff --git a/tests/ondemand/ondemand_readme_examples.cpp b/tests/ondemand/ondemand_readme_examples.cpp
--- a/tests/ondemand/ondemand_readme_examples.cpp
+++ b/tests/ondemand/ondemand_readme_examples.cpp
@@ -292,6 +292,63 @@ bool using_the_parsed_json_6() {
   TEST_SUCCEED();
 }
 
+const padded_string cars_json = R"( [
+  { "make": "Toyota", "model": "Camry",  "year": 2018, "tire_pressure": [ 40.1, 39.9, 37.7, 40.4 ] },
+  { "make": "Kia",    "model": "Soul",   "year": 2012, "tire_pressure": [ 30.1, 31.0, 28.6, 28.7 ] },
+  { "make": "Toyota", "model": "Tercel", "year": 1999, "tire_pressure": [ 29.8, 30.0, 30.2, 30.5 ] }
+] )"_padded;
+
+bool json_pointer_simple() {
+    TEST_START();
+    ondemand::parser parser;
+    ondemand::document cars;
+    double x;
+    ASSERT_SUCCESS(parser.iterate(cars_json).get(cars));
+    ASSERT_SUCCESS(cars.at_pointer("/0/tire_pressure/1").get(x));
+    ASSERT_EQUAL(x,39.9);
+    TEST_SUCCEED();
+}
+
+bool json_pointer_multiple() {
+	TEST_START();
+	ondemand::parser parser;
+	ondemand::document cars;
+	size_t size;
+	ASSERT_SUCCESS(parser.iterate(cars_json).get(cars));
+	ASSERT_SUCCESS(cars.count_elements().get(size));
+	double expected[] = {39.9, 31, 30};
+	for (size_t i = 0; i < size; i++) {
+		std::string json_pointer = "/" + std::to_string(i) + "/tire_pressure/1";
+		double x;
+		ASSERT_SUCCESS(cars.at_pointer(json_pointer).get(x));
+		ASSERT_EQUAL(x,expected[i]);
+	}
+	TEST_SUCCEED();
+}
+
+bool json_pointer_rewind() {
+  TEST_START();
+  auto json = R"( {
+  "k0": 27,
+  "k1": [13,26],
+  "k2": true
+  } )"_padded;
+
+  ondemand::parser parser;
+  ondemand::document doc;
+  uint64_t i;
+  bool b;
+  ASSERT_SUCCESS(parser.iterate(json).get(doc));
+  ASSERT_SUCCESS(doc.at_pointer("/k1/1").get(i));
+  ASSERT_EQUAL(i,26);
+  ASSERT_SUCCESS(doc.at_pointer("/k2").get(b));
+  ASSERT_EQUAL(b,true);
+  doc.rewind();	// Need to manually rewind to be able to use find_field properly from start of document
+  ASSERT_SUCCESS(doc.find_field("k0").get(i));
+  ASSERT_EQUAL(i,27);
+  TEST_SUCCEED();
+}
+
 int main() {
   if (
     true
@@ -312,6 +369,9 @@ int main() {
     && using_the_parsed_json_5()
 #endif
     && using_the_parsed_json_6()
+    && json_pointer_simple()
+    && json_pointer_multiple()
+    && json_pointer_rewind()
   ) {
     return 0;
   } else {
EOF_114329324912

# Navigate to the build directory.
# The Dockerfile has already run `cmake ..` and `cmake --build .` from /testbed,
# so the `build` directory should already exist and contain the compiled project.
cd build

# Set the SIMDJSON_DEVELOPER_MODE environment variable.
# While CMake might have already configured with this, ensuring it's set before
# a rebuild is a good practice, especially if the patch modified CMake files.
export SIMDJSON_DEVELOPER_MODE=ON

# Rebuild the project after applying the patch.
# This step is critical to ensure that any new or modified tests from the patch
# are compiled and included in the test executable.
# Changed from -j$(nproc) to -j4 to prevent potential Out-Of-Memory errors during compilation,
# matching the Dockerfile's build command.
cmake --build . -j4

# Check the exit code of the build command. If the build fails, exit early.
if [ $? -ne 0 ]; then
    echo "Build failed after patch application. Exiting."
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Execute only the specified target tests.
# The target file is tests/ondemand/ondemand_readme_examples.cpp.
# CTest runs tests discovered by CMake within the build directory.
# We use -R "ondemand_readme_examples" to specifically target tests generated from this file,
# as per the collected context information.
ctest --output-on-failure -R "ondemand_readme_examples"
rc=$?

# Capture the exit code immediately after running the tests.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Navigate back to the testbed root directory for cleanup.
cd /testbed

# Clean up: Undo any changes made to the target test file.
# This ensures that the repository remains in its original state after the test run.
git checkout 1c01fc35ebce2d50ea6c279002ca949784d71ad4 "tests/ondemand/ondemand_readme_examples.cpp"