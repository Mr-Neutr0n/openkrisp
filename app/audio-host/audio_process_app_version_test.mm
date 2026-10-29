#include "audio_process_app_version.hpp"
#include <cassert>
#include <iostream>
using namespace labvoice;
int main() {
    @autoreleasepool {
        AudioProcessApp app;
        assert(audioProcessAppVersion(nil, app).empty());
        assert(audioProcessAppVersion(@{}, app).empty());
        assert(audioProcessAppVersion(@{@"CFBundleShortVersionString": @"2.3", @"CFBundleVersion": @"44"}, app) == "2.3");
        assert(audioProcessAppVersion(@{@"CFBundleShortVersionString": @"", @"CFBundleVersion": @"44"}, app).empty());
        assert(audioProcessAppVersion(@{@"CFBundleShortVersionString": @2, @"CFBundleVersion": @"44"}, app) == "44");
        assert(audioProcessAppVersion(@{@"CFBundleVersion": @44}, app).empty());
        const unichar nul[] = {'1', 0, '2'};
        NSString* embedded = [NSString stringWithCharacters:nul length:3];
        assert(audioProcessAppVersion(@{@"CFBundleShortVersionString": embedded}, app) == "1");
        NSString* oversized = [@"x" stringByPaddingToLength:4097 withString:@"x" startingAtIndex:0];
        assert(audioProcessAppVersion(@{@"CFBundleShortVersionString": oversized, @"CFBundleVersion": @"44"}, app).empty());
        assert(app.errors.size() == 1);
    }
    std::cout << "Application-version metadata fixture tests passed.\n";
}
