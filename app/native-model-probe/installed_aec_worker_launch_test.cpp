#include "installed_aec_worker_launch.hpp"
#include <cassert>
#include <iostream>
#include <sys/stat.h>

using namespace krisp_probe;
template<class F> void rejects(F&& action) { bool rejected = false; try { action(); } catch (const std::exception&) { rejected = true; } assert(rejected); }
int main() {
    char directory[] = "/tmp/own-aec-launch-XXXXXX";
    assert(mkdtemp(directory));
    const std::string worker = std::string(directory) + "/own worker", link = std::string(directory) + "/link";
    const int fd = open(worker.c_str(), O_WRONLY | O_CREAT | O_EXCL, 0700);
    assert(fd >= 0 && write(fd, "abc", 3) == 3 && close(fd) == 0);
    InstalledAECWorkerSettings settings{worker,
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "/unread-vendor-path/libAEC.dylib"};
    aec_wire::Token token{};
    for (unsigned i = 0; i < token.size(); ++i) token[i] = static_cast<std::uint8_t>(i);
    const auto config = buildInstalledAECWorkerLaunch(settings, token);
    const std::vector<std::string> expected{"-p", "(version 1) (allow default) (deny network*)", worker,
        settings.libraryPath, installedAECLibrarySHA256, "000102030405060708090a0b0c0d0e0f", std::to_string(getpid())};
    assert(config.executable == "/usr/bin/sandbox-exec" && config.arguments == expected);
    assert(config.environment == std::vector<std::string>{"PATH=/usr/bin:/bin"});
    assert(config.expectedReadyLine == std::string("OKAEC1 ") + installedAECLibrarySHA256 + " 48000 1 48000 2\n");
    assert(config.token == token && config.startupTimeout.count() == 30000 && config.frameTimeout.count() == 500 && config.shutdownTimeout.count() == 1000);
    auto bad = settings; bad.workerSha256[0] = 'f'; rejects([&]{buildInstalledAECWorkerLaunch(bad,token);});
    bad = settings; bad.workerSha256[0] = 'A'; rejects([&]{buildInstalledAECWorkerLaunch(bad,token);});
    bad = settings; bad.libraryPath = "relative"; rejects([&]{buildInstalledAECWorkerLaunch(bad,token);});
    bad = settings; bad.libraryPath.push_back('\0'); rejects([&]{buildInstalledAECWorkerLaunch(bad,token);});
    assert(symlink(worker.c_str(), link.c_str()) == 0);
    bad = settings; bad.workerPath = link; rejects([&]{buildInstalledAECWorkerLaunch(bad,token);});
    bad = settings; bad.workerPath = directory; rejects([&]{buildInstalledAECWorkerLaunch(bad,token);});
    assert(chmod(worker.c_str(), 0600) == 0); rejects([&]{buildInstalledAECWorkerLaunch(settings,token);});
    assert(chmod(worker.c_str(), 0700) == 0);
    const int changed = open(worker.c_str(), O_WRONLY | O_TRUNC); assert(changed >= 0);
    assert(write(changed,"xyz",3) == 3 && close(changed) == 0); rejects([&]{buildInstalledAECWorkerLaunch(settings,token);});
    assert(truncate(worker.c_str(), 64 * 1024 * 1024 + 1) == 0);
    rejects([&]{buildInstalledAECWorkerLaunch(settings,token);});
    assert(truncate(worker.c_str(), 0) == 0); rejects([&]{buildInstalledAECWorkerLaunch(settings,token);});
    const auto fifo = std::string(directory) + "/fifo";
    assert(mkfifo(fifo.c_str(), 0700) == 0);
    bad = settings; bad.workerPath = fifo; rejects([&]{buildInstalledAECWorkerLaunch(bad,token);});
    assert(unlink(fifo.c_str()) == 0);
    assert(unlink(link.c_str()) == 0 && unlink(worker.c_str()) == 0 && rmdir(directory) == 0);
    std::cout << "Installed AEC launch admission tests passed\n";
}
