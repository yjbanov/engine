// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/shell/platform/common/cpp/client_wrapper/include/flutter/standard_method_codec.h"

#include "flutter/shell/platform/common/cpp/client_wrapper/include/flutter/method_result_functions.h"
#include "flutter/shell/platform/common/cpp/client_wrapper/testing/encodable_value_utils.h"
#include "gtest/gtest.h"

namespace flutter {

namespace {

// Returns true if the given method calls have the same method name, and their
// arguments have equivalent values.
bool MethodCallsAreEqual(const MethodCall<EncodableValue>& a,
                         const MethodCall<EncodableValue>& b) {
  if (a.method_name() != b.method_name()) {
    return false;
  }
  // Treat nullptr and Null as equivalent.
  if ((!a.arguments() || a.arguments()->IsNull()) &&
      (!b.arguments() || b.arguments()->IsNull())) {
    return true;
  }
  return testing::EncodableValuesAreEqual(*a.arguments(), *b.arguments());
}

}  // namespace

TEST(StandardMethodCodec, HandlesMethodCallsWithNullArguments) {
  const StandardMethodCodec& codec = StandardMethodCodec::GetInstance();
  MethodCall<EncodableValue> call("hello", nullptr);
  auto encoded = codec.EncodeMethodCall(call);
  ASSERT_NE(encoded.get(), nullptr);
  std::unique_ptr<MethodCall<EncodableValue>> decoded =
      codec.DecodeMethodCall(*encoded);
  ASSERT_NE(decoded.get(), nullptr);
  EXPECT_TRUE(MethodCallsAreEqual(call, *decoded));
}

TEST(StandardMethodCodec, HandlesMethodCallsWithArgument) {
  const StandardMethodCodec& codec = StandardMethodCodec::GetInstance();
  MethodCall<EncodableValue> call(
      "hello", std::make_unique<EncodableValue>(EncodableList{
                   EncodableValue(42),
                   EncodableValue("world"),
               }));
  auto encoded = codec.EncodeMethodCall(call);
  ASSERT_NE(encoded.get(), nullptr);
  std::unique_ptr<MethodCall<EncodableValue>> decoded =
      codec.DecodeMethodCall(*encoded);
  ASSERT_NE(decoded.get(), nullptr);
  EXPECT_TRUE(MethodCallsAreEqual(call, *decoded));
}

TEST(StandardMethodCodec, HandlesSuccessEnvelopesWithNullResult) {
  const StandardMethodCodec& codec = StandardMethodCodec::GetInstance();
  auto encoded = codec.EncodeSuccessEnvelope();
  ASSERT_NE(encoded.get(), nullptr);
  std::vector<uint8_t> bytes = {0x00, 0x00};
  EXPECT_EQ(*encoded, bytes);

  bool decoded_successfully = false;
  MethodResultFunctions<EncodableValue> result_handler(
      [&decoded_successfully](const EncodableValue* result) {
        decoded_successfully = true;
        EXPECT_EQ(result, nullptr);
      },
      nullptr, nullptr);
  codec.DecodeAndProcessResponseEnvelope(encoded->data(), encoded->size(),
                                         &result_handler);
  EXPECT_TRUE(decoded_successfully);
}

TEST(StandardMethodCodec, HandlesSuccessEnvelopesWithResult) {
  const StandardMethodCodec& codec = StandardMethodCodec::GetInstance();
  EncodableValue result(42);
  auto encoded = codec.EncodeSuccessEnvelope(&result);
  ASSERT_NE(encoded.get(), nullptr);
  std::vector<uint8_t> bytes = {0x00, 0x03, 0x2a, 0x00, 0x00, 0x00};
  EXPECT_EQ(*encoded, bytes);

  bool decoded_successfully = false;
  MethodResultFunctions<EncodableValue> result_handler(
      [&decoded_successfully](const EncodableValue* result) {
        decoded_successfully = true;
        EXPECT_EQ(result->IntValue(), 42);
      },
      nullptr, nullptr);
  codec.DecodeAndProcessResponseEnvelope(encoded->data(), encoded->size(),
                                         &result_handler);
  EXPECT_TRUE(decoded_successfully);
}

TEST(StandardMethodCodec, HandlesErrorEnvelopesWithNulls) {
  const StandardMethodCodec& codec = StandardMethodCodec::GetInstance();
  auto encoded = codec.EncodeErrorEnvelope("errorCode");
  ASSERT_NE(encoded.get(), nullptr);
  std::vector<uint8_t> bytes = {0x01, 0x07, 0x09, 0x65, 0x72, 0x72, 0x6f,
                                0x72, 0x43, 0x6f, 0x64, 0x65, 0x00, 0x00};
  EXPECT_EQ(*encoded, bytes);

  bool decoded_successfully = false;
  MethodResultFunctions<EncodableValue> result_handler(
      nullptr,
      [&decoded_successfully](const std::string& code,
                              const std::string& message,
                              const EncodableValue* details) {
        decoded_successfully = true;
        EXPECT_EQ(code, "errorCode");
        EXPECT_EQ(message, "");
        EXPECT_EQ(details, nullptr);
      },
      nullptr);
  codec.DecodeAndProcessResponseEnvelope(encoded->data(), encoded->size(),
                                         &result_handler);
  EXPECT_TRUE(decoded_successfully);
}

TEST(StandardMethodCodec, HandlesErrorEnvelopesWithDetails) {
  const StandardMethodCodec& codec = StandardMethodCodec::GetInstance();
  EncodableValue details(EncodableList{
      EncodableValue("a"),
      EncodableValue(42),
  });
  auto encoded =
      codec.EncodeErrorEnvelope("errorCode", "something failed", &details);
  ASSERT_NE(encoded.get(), nullptr);
  std::vector<uint8_t> bytes = {
      0x01, 0x07, 0x09, 0x65, 0x72, 0x72, 0x6f, 0x72, 0x43, 0x6f,
      0x64, 0x65, 0x07, 0x10, 0x73, 0x6f, 0x6d, 0x65, 0x74, 0x68,
      0x69, 0x6e, 0x67, 0x20, 0x66, 0x61, 0x69, 0x6c, 0x65, 0x64,
      0x0c, 0x02, 0x07, 0x01, 0x61, 0x03, 0x2a, 0x00, 0x00, 0x00,
  };
  EXPECT_EQ(*encoded, bytes);

  bool decoded_successfully = false;
  MethodResultFunctions<EncodableValue> result_handler(
      nullptr,
      [&decoded_successfully](const std::string& code,
                              const std::string& message,
                              const EncodableValue* details) {
        decoded_successfully = true;
        EXPECT_EQ(code, "errorCode");
        EXPECT_EQ(message, "something failed");
        EXPECT_TRUE(details->IsList());
        EXPECT_EQ(details->ListValue()[0].StringValue(), "a");
        EXPECT_EQ(details->ListValue()[1].IntValue(), 42);
      },
      nullptr);
  codec.DecodeAndProcessResponseEnvelope(encoded->data(), encoded->size(),
                                         &result_handler);
  EXPECT_TRUE(decoded_successfully);
}

}  // namespace flutter
