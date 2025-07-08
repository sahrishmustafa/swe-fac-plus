#!/bin/bash
set -uxo pipefail
cd /testbed

# Ensure the target test file is in its original state before applying any patch
git checkout 87fbc6f7566e4d3266bd3a2cd69f6c90e1aefa5d "test/prepare-test.cc"

# Required: apply test patch to update target tests
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

# Build system setup
# 1. Create the build directory
mkdir build

# 2. Configure CMake with tests enabled
cmake -S . -B build -DFMT_TEST=ON

# 3. Build the project
cmake --build build

# Test execution
# Navigate into the build directory
cd build

# Run tests: ctest will execute all tests compiled as part of the FMT_TEST target,
# which includes tests derived from test/prepare-test.cc.
ctest --output-on-failure
rc=$? # Capture exit code immediately after running tests

echo "OMNIGRIL_EXIT_CODE=$rc" # Required, echo test status

# Cleanup: Revert changes made by the patch to the target test file
cd /testbed # Ensure we are in the repository root for git checkout
git checkout 87fbc6f7566e4d3266bd3a2cd69f6c90e1aefa5d "test/prepare-test.cc"