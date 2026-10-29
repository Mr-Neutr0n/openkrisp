#include "audio_process_usage.hpp"
#include "audio_process_app_version.hpp"
#import <AppKit/AppKit.h>
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <libproc.h>
#include <cstring>
#include <stdexcept>

namespace labvoice {
namespace {
AudioObjectPropertyAddress address(UInt32 selector, UInt32 scope = kAudioObjectPropertyScopeGlobal) {
    return {selector, scope, kAudioObjectPropertyElementMain};
}
void check(OSStatus status) { if (status != noErr) throw std::runtime_error("CoreAudio property OSStatus=" + std::to_string(status)); }
template<class T> T scalar(AudioObjectID id, UInt32 selector) {
    auto a = address(selector); T result{}; UInt32 size = sizeof result;
    check(AudioObjectGetPropertyData(id, &a, 0, nullptr, &size, &result));
    if (size != sizeof result) throw std::runtime_error("Unexpected scalar size.");
    return result;
}
std::string string(AudioObjectID id, UInt32 selector) {
    auto value = scalar<CFStringRef>(id, selector);
    if (!value) throw std::runtime_error("Null string property.");
    const auto length = CFStringGetLength(value);
    if (length > 16384) { CFRelease(value); throw std::runtime_error("String exceeds snapshot bound."); }
    const auto size = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8) + 1;
    std::vector<char> bytes(static_cast<size_t>(size));
    const bool valid = CFStringGetCString(value, bytes.data(), size, kCFStringEncodingUTF8);
    CFRelease(value);
    if (!valid) throw std::runtime_error("Invalid string encoding.");
    return bytes.data();
}
std::string text(NSString* value, AudioProcessApp& app, const char* field) {
    if (!value) return "";
    NSData* bytes = [value dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    if (!bytes || bytes.length > 4096) { app.errors.push_back(std::string(field) + ": invalid or oversized UTF-8 metadata."); return ""; }
    return std::string(static_cast<const char*>(bytes.bytes), bytes.length);
}
}
AudioProcessSnapshot observeAudioProcessUsage() {
    if (@available(macOS 14.4, *)) {} else {
        return {"unavailable", {}, {"The retained newer audio-process source requires macOS 14.4. Older-source fallback is unavailable."}};
    }
    @autoreleasepool {
        AudioProcessReader reader;
        reader.hasList = [] { auto a = address(kAudioHardwarePropertyProcessObjectList); return AudioObjectHasProperty(kAudioObjectSystemObject, &a); };
        reader.scalar = [](AudioObjectID id, UInt32 selector) { return scalar<UInt32>(id, selector); };
        reader.text = string;
        reader.array = [](AudioObjectID id, UInt32 selector, UInt32 scope) {
            auto a = address(selector, scope); UInt32 size = 0;
            check(AudioObjectGetPropertyDataSize(id, &a, 0, nullptr, &size));
            if (size > 1048576 || size % sizeof(AudioObjectID)) throw std::runtime_error("Invalid or oversized object list.");
            std::vector<AudioObjectID> values(size / sizeof(AudioObjectID));
            const auto capacity = size;
            if (size) check(AudioObjectGetPropertyData(id, &a, 0, nullptr, &size, values.data()));
            if (size > capacity || size % sizeof(AudioObjectID)) throw std::runtime_error("Object list changed size during read.");
            values.resize(size / sizeof(AudioObjectID)); return values;
        };
        reader.responsiblePID = [](int pid) -> std::optional<int> {
            using Resolve = pid_t (*)(pid_t);
            const auto resolve = reinterpret_cast<Resolve>(dlsym(RTLD_DEFAULT, "responsibility_get_pid_responsible_for_pid"));
            if (!resolve) return std::nullopt;
            return resolve(pid);
        };
        reader.app = [](int pid) {
            AudioProcessApp result;
            NSRunningApplication* app = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
            result.name = text(app.localizedName, result, "app_name"); result.bundleID = text(app.bundleIdentifier, result, "responsible_bundle_id");
            NSURL* infoURL = [app.bundleURL URLByAppendingPathComponent:@"Contents/Info.plist"];
            NSDictionary* info = infoURL ? [NSDictionary dictionaryWithContentsOfURL:infoURL] : nil;
            result.version = audioProcessAppVersion(info, result);
            char path[PROC_PIDPATHINFO_MAXSIZE]{};
            if (proc_pidpath(pid, path, sizeof path) > 0) {
                const auto slash = std::strrchr(path, '/');
                NSString* name = [NSString stringWithUTF8String:slash ? slash + 1 : path];
                if (!name) result.errors.push_back("binary_name: invalid UTF-8 path.");
                result.binaryName = text(name, result, "binary_name");
            }
            return result;
        };
        return readAudioProcessUsage(reader);
    }
}
}
