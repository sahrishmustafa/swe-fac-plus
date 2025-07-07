#!/bin/bash
set -uxo pipefail

cd /testbed
git checkout 3c522386e961d61768ea527d04713b5402356dd4 "test/test.cc"

git apply -v - <<'EOF_114329324912'
diff --git a/test/test.cc b/test/test.cc
--- a/test/test.cc
+++ b/test/test.cc
@@ -8,6 +8,8 @@
 #include <sstream>
 #include <stdexcept>
 #include <thread>
+#include <type_traits>
+#include "../httplib.h"
 
 #define SERVER_CERT_FILE "./cert.pem"
 #define SERVER_CERT2_FILE "./cert2.pem"
@@ -40,6 +42,11 @@ MultipartFormData &get_file_value(MultipartFormDataItems &files,
   throw std::runtime_error("invalid mulitpart form data name error");
 }
 
+TEST(ConstructorTest, MoveConstructible) {
+  EXPECT_FALSE(std::is_copy_constructible<httplib::Client>::value);
+  EXPECT_TRUE(std::is_nothrow_move_constructible<httplib::Client>::value);
+}
+
 #ifdef _WIN32
 TEST(StartupTest, WSAStartup) {
   WSADATA wsaData;
EOF_114329324912

# ✅ Rebuild the test binary so the new test is included
cd /testbed/test
g++ -o test -I.. -g -std=c++11 -I. -Wall -Wextra -Wtype-limits -Wconversion test.cc include_httplib.cc gtest/gtest-all.cc gtest/gtest_main.cc \
    -DCPPHTTPLIB_OPENSSL_SUPPORT -lssl -lcrypto \
    -DCPPHTTPLIB_ZLIB_SUPPORT -lz \
    -DCPPHTTPLIB_BROTLI_SUPPORT -lbrotlicommon -lbrotlienc -lbrotlidec -pthread

# ✅ Run the test binary
./test
rc=$?
echo "OMNIGRIL_EXIT_CODE=$rc"

# ✅ Clean up
cd /testbed
git checkout 3c522386e961d61768ea527d04713b5402356dd4 "test/test.cc"