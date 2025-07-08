#!/bin/bash
set -uxo pipefail
# Navigate to the testbed directory, which is the root of the cloned repository.
cd /testbed

# Ensure the target test file is in its original state before applying any patch.
# This prevents issues if a previous run's patch was not fully reverted.
git checkout 87fbc6f7566e4d3266bd3a2cd69f6c90e1aefa5d "test/prepare-test.cc"

# Required: apply the test patch to update the target tests.
# The actual patch content will be injected here programmatically.
git apply -v - <<'EOF_114329324912'
diff --git a/test/prepare-test.cc b/test/prepare-test.cc
--- a/test/prepare-test.cc
+++ b/test/prepare-test.cc
@@ -475,7 +475,7 @@ TEST(PrepareTest, CopyPreparedFormat_InternalStringViewsAreNotInvalidated) {
   }
 }
 
-TEST(PepareTest, ReusedPreparedFormatType) {
+TEST(PrepareTest, ReusedPreparedFormatType) {
   typedef fmt::prepared_format<std::string, int>::type prepared_format;
 
   prepared_format prepared = fmt::prepare<prepared_format>("The {} is {}.");
@@ -637,3 +637,58 @@ TEST(PrepareTest, PassUserTypeFormat) {
   const auto prepared = fmt::prepare<int>(user_format("test {}"));
   EXPECT_EQ("test 42", prepared.format(42));
 }
+
+TEST(PrepareTest, FormatToArrayOfChars) {
+  char buffer[32] = {0};
+  const auto prepared = fmt::prepare<int>("4{}");
+  prepared.format_to(buffer, 2);
+  EXPECT_EQ(std::string("42"), buffer);
+  wchar_t wbuffer[32] = {0};
+  const auto wprepared = fmt::prepare<int>(L"4{}");
+  wprepared.format_to(wbuffer, 2);
+  EXPECT_EQ(std::wstring(L"42"), wbuffer);
+}
+
+TEST(PrepareTest, FormatToIterator) {
+  std::string s(2, ' ');
+  const auto prepared = fmt::prepare<int>("4{}");
+  prepared.format_to(s.begin(), 2);
+  EXPECT_EQ("42", s);
+  std::wstring ws(2, L' ');
+  const auto wprepared = fmt::prepare<int>(L"4{}");
+  wprepared.format_to(ws.begin(), 2);
+  EXPECT_EQ(L"42", ws);
+}
+
+TEST(PrepareTest, FormatToBackInserter) {
+  std::string s;
+  const auto prepared = fmt::prepare<int>("4{}");
+  prepared.format_to(std::back_inserter(s), 2);
+  EXPECT_EQ("42", s);
+  std::wstring ws;
+  const auto wprepared = fmt::prepare<int>(L"4{}");
+  wprepared.format_to(std::back_inserter(ws), 2);
+  EXPECT_EQ(L"42", ws);
+}
+
+TEST(PrepareTest, FormatToBasicMemoryBuffer) {
+  fmt::basic_memory_buffer<char, 100> buffer;
+  const auto prepared = fmt::prepare<int>("4{}");
+  prepared.format_to(buffer, 2);
+  EXPECT_EQ("42", to_string(buffer));
+  fmt::basic_memory_buffer<wchar_t, 100> wbuffer;
+  const auto wprepared = fmt::prepare<int>(L"4{}");
+  wprepared.format_to(wbuffer, 2);
+  EXPECT_EQ(L"42", to_string(wbuffer));
+}
+
+TEST(PrepareTest, FormatToMemoryBuffer) {
+  fmt::memory_buffer buffer;
+  const auto prepared = fmt::prepare<int>("4{}");
+  prepared.format_to(buffer, 2);
+  EXPECT_EQ("42", to_string(buffer));
+  fmt::wmemory_buffer wbuffer;
+  const auto wprepared = fmt::prepare<int>(L"4{}");
+  wprepared.format_to(wbuffer, 2);
+  EXPECT_EQ(L"42", to_string(wbuffer));
+}
EOF_114329324912

# Required: After applying the test patch, rebuild the test binary or recompile the project
# This ensures that any new or modified tests from the patch are included in the executable.
# Navigate to the build directory where the project was initially configured.
cd /testbed/build

# Rebuild the project. This will recompile `test/prepare-test.cc` if it was modified by the patch,
# and link it into the `prepare-test` executable.
echo "Attempting to rebuild the project after applying the patch..."
make -j$(nproc)
build_rc=$? # Capture the exit code of the build command

# Critical: If the build fails, set the OMNIGRIL_EXIT_CODE to 1 and exit immediately.
if [ $build_rc -ne 0 ]; then
  echo "Project rebuild failed with exit code $build_rc. Test execution aborted."
  echo "OMNIGRIL_EXIT_CODE=1" # Indicate failure due to build error
  exit 0 # Exit the script successfully from a shell perspective, but report failure via OMNIGRIL_EXIT_CODE
fi

echo "Project rebuilt successfully. Proceeding with test execution."

# Test execution: Run only the specified target test using CTest.
# The collected information indicates that `prepare-test.cc` compiles to a CTest target named `prepare-test`.
ctest -R prepare-test --output-on-failure
rc=$? # Capture the exit code immediately after running the tests

echo "OMNIGRIL_EXIT_CODE=$rc" # Required: Echo the test status for the test log analysis agent

# Cleanup: Revert changes made by the patch to the target test file.
# Navigate back to the repository root directory before performing git checkout.
cd /testbed
git checkout 87fbc6f7566e4d3266bd3a2cd69f6c90e1aefa5d "test/prepare-test.cc"