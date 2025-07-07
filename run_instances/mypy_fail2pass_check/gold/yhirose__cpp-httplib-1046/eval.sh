#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory where the repository is cloned.
cd /testbed

# Ensure the target test file is at the commit's state before applying the patch.
git checkout e3e28c623165f9965efd2abbb7a31891c0fad684 "test/test.cc"

# Apply the test patch to the specified file.
git apply -v - <<'EOF_114329324912'
diff --git a/test/test.cc b/test/test.cc
--- a/test/test.cc
+++ b/test/test.cc
@@ -1349,11 +1349,13 @@ class ServerTest : public ::testing::Test {
                std::this_thread::sleep_for(std::chrono::seconds(2));
                res.set_content("slow", "text/plain");
              })
+#if 0
         .Post("/slowpost",
               [&](const Request & /*req*/, Response &res) {
                 std::this_thread::sleep_for(std::chrono::seconds(2));
                 res.set_content("slow", "text/plain");
               })
+#endif
         .Get("/remote_addr",
              [&](const Request &req, Response &res) {
                auto remote_addr = req.headers.find("REMOTE_ADDR")->second;
@@ -2623,6 +2625,7 @@ TEST_F(ServerTest, SlowRequest) {
       std::thread([=]() { auto res = cli_.Get("/slow"); }));
 }
 
+#if 0
 TEST_F(ServerTest, SlowPost) {
   char buffer[64 * 1024];
   memset(buffer, 0x42, sizeof(buffer));
@@ -2640,7 +2643,6 @@ TEST_F(ServerTest, SlowPost) {
   EXPECT_EQ(200, res->status);
 }
 
-#if 0
 TEST_F(ServerTest, SlowPostFail) {
   char buffer[64 * 1024];
   memset(buffer, 0x42, sizeof(buffer));
@@ -3564,10 +3566,12 @@ TEST(StreamingTest, NoContentLengthStreaming) {
   Client client(HOST, PORT);
 
   auto get_thread = std::thread([&client]() {
-    auto res = client.Get("/stream", [](const char *data, size_t len) -> bool {
-      EXPECT_EQ("aaabbb", std::string(data, len));
+    std::string s;
+    auto res = client.Get("/stream", [&s](const char *data, size_t len) -> bool {
+      s += std::string(data, len);
       return true;
     });
+    EXPECT_EQ("aaabbb", s);
   });
 
   // Give GET time to get a few messages.
EOF_114329324912

# Explicitly build and run the specific test file (test/test.cc) within a subshell.
# This sequence replaces the 'make' command to ensure correct library linkages.
(
    cd test && \
    openssl genrsa 2048 > key.pem && \
    python3 ../split.py -o . && \
    openssl req -new -batch -config test.conf -key key.pem | openssl x509 -days 3650 -req -signkey key.pem > cert.pem && \
    openssl req -x509 -config test.conf -key key.pem -sha256 -days 3650 -nodes -out cert2.pem -extensions SAN && \
    openssl genrsa 2048 > rootCA.key.pem && \
    openssl req -x509 -new -batch -config test.rootCA.conf -key rootCA.key.pem -days 1024 > rootCA.cert.pem && \
    openssl genrsa 2048 > client.key.pem && \
    openssl req -new -batch -config test.conf -key client.key.pem | openssl x509 -days 370 -req -CA rootCA.cert.pem -CAkey rootCA.key.pem -CAcreateserial > client.cert.pem && \
    g++ -o test -I.. -g -std=c++11 -I. -Wall -Wextra -Wtype-limits -Wconversion  test.cc include_httplib.cc gtest/gtest-all.cc gtest/gtest_main.cc -DCPPHTTPLIB_OPENSSL_SUPPORT -lssl -lcrypto -DCPPHTTPLIB_ZLIB_SUPPORT -lz -DCPPHTTPLIB_BROTLI_SUPPORT -lbrotlicommon -lbrotlienc -lbrotlidec -pthread && \
    ./test
)
rc=$? # Capture the exit code of the test run

# Output the exit code for the test log analysis agent.
echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up: revert the changes made to test/test.cc by the patch.
# This ensures the repository is in a clean state after the evaluation.
git checkout e3e28c623165f9965efd2abbb7a31891c0fad684 "test/test.cc"