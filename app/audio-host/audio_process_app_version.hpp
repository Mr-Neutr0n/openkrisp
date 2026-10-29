#pragma once
#import <Foundation/Foundation.h>
#include "audio_process_usage.hpp"

namespace labvoice {
// The original prefers a valid short-version string even when it is empty.
// Resource bounds are independent carrier limits, not fallback conditions.
inline std::string audioProcessAppVersion(NSDictionary* info, AudioProcessApp& app) {
    for (NSString* key in @[@"CFBundleShortVersionString", @"CFBundleVersion"]) {
        id value = info[key];
        if (![value isKindOfClass:[NSString class]]) continue;
        const char* utf8 = [value UTF8String];
        if (!utf8) continue;
        const auto length = [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        if (length > 4096) {
            app.errors.push_back("app_version: oversized UTF-8 metadata.");
            return "";
        }
        // Match the native C-string conversion, including embedded NUL.
        return std::string(utf8);
    }
    return "";
}
}
