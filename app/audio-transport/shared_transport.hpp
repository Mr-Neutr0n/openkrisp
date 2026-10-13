#pragma once
#include <bit>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <fcntl.h>
#include <stdexcept>
#include <string>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

namespace krisp_local {
// ABI v1: little-endian ARM64 macOS, naturally aligned integer words.
// Clang __atomic operations, never C++ atomic objects or process-local pointers.
struct alignas(8) SharedHeader {
    uint32_t state; // atomic: 0 initializing, 1 ready, 2 closed
    uint32_t version;
    uint64_t magic;
    uint32_t channels;
    uint32_t capacity;
    uint32_t sample_rate;
    uint32_t max_callback_frames;
    uint64_t heartbeat_ns; // atomic
    uint64_t end_frame; // atomic, exclusive end of most recent publication
    uint64_t bytes;
    uint64_t reserved;
};
struct alignas(8) SharedSlot {
    uint64_t revision; // atomic
    uint64_t frame; // atomic
    uint32_t samples[2]; // atomic IEEE754 Float32 bits
    uint64_t reserved;
};
static_assert(sizeof(SharedHeader) == 64 && offsetof(SharedHeader, heartbeat_ns) == 32);
static_assert(sizeof(SharedSlot) == 32 && offsetof(SharedSlot, samples) == 16);
static_assert(__atomic_always_lock_free(8, nullptr) && __atomic_always_lock_free(4, nullptr));
static_assert(std::endian::native == std::endian::little);

class SharedTransport {
    static constexpr uint64_t magic = 0x4b4c415544494f31ULL;
    std::string name_;
    int fd_ = -1;
    void* mapping_ = MAP_FAILED;
    size_t bytes_ = 0;
    bool owner_;
    bool linked_ = false;
    uint32_t channels_ = 0, capacity_ = 0;
    uint64_t next_ = 0, last_time_ = 0;
    SharedHeader* header() const noexcept { return static_cast<SharedHeader*>(mapping_); }
    SharedSlot* slots() const noexcept { return reinterpret_cast<SharedSlot*>(static_cast<char*>(mapping_) + 64); }
    template<class T> static T load(const T* p) noexcept { return __atomic_load_n(p, __ATOMIC_SEQ_CST); }
    template<class T> static void store(T* p, T v) noexcept { __atomic_store_n(p, v, __ATOMIC_SEQ_CST); }
    void cleanup() noexcept {
        if (mapping_ != MAP_FAILED) {
            if (owner_) store(&header()->state, uint32_t(2));
            munmap(mapping_, bytes_);
            mapping_ = MAP_FAILED;
        }
        if (fd_ >= 0) { close(fd_); fd_ = -1; }
        if (linked_) { shm_unlink(name_.c_str()); linked_ = false; }
    }
public:
    // Owner creates exclusive 0600 object. Attachers pass channels=capacity=0.
    // Publish the name to peers only after this constructor returns.
    SharedTransport(std::string name, uint32_t channels = 0, uint32_t capacity = 0)
        : name_(std::move(name)), owner_(channels != 0 || capacity != 0) {
        if (name_.size() < 2 || name_.size() > 30 || name_[0] != '/' ||
            name_.find('/', 1) != std::string::npos) throw std::invalid_argument("invalid local shm name");
        try {
            if (owner_ && ((channels != 1 && channels != 2) || !capacity || capacity > 1048576))
                throw std::invalid_argument("invalid shared audio dimensions");
            fd_ = shm_open(name_.c_str(), owner_ ? O_RDWR | O_CREAT | O_EXCL : O_RDONLY, 0600);
            if (fd_ < 0) throw std::runtime_error("shm_open failed");
            linked_ = owner_;
            if (fcntl(fd_, F_SETFD, FD_CLOEXEC) < 0) throw std::runtime_error("close-on-exec failed");
            if (owner_) {
                bytes_ = 64 + size_t(capacity) * 32;
                if (ftruncate(fd_, off_t(bytes_))) throw std::runtime_error("shm sizing failed");
            }
            struct stat st{};
            if (fstat(fd_, &st) || st.st_uid != geteuid() || (st.st_mode & 0777) != 0600 ||
                st.st_size < 96 || st.st_size > off_t(65536 + 1048576 * 32))
                throw std::runtime_error("shm ownership, mode, or size invalid");
            bytes_ = size_t(st.st_size);
            mapping_ = mmap(nullptr, bytes_, owner_ ? PROT_READ | PROT_WRITE : PROT_READ, MAP_SHARED, fd_, 0);
            if (mapping_ == MAP_FAILED) throw std::runtime_error("mmap failed");
            auto* h = header();
            if (owner_) {
                // Fresh ftruncate pages are zero. Only this owner can initialize.
                h->version = 1; h->magic = magic; h->channels = channels; h->capacity = capacity;
                h->sample_rate = 48000; h->max_callback_frames = 960; h->bytes = 64 + size_t(capacity) * 32;
                store(&h->state, uint32_t(1));
            }
            if (load(&h->state) != 1 || h->version != 1 || h->magic != magic ||
                (h->channels != 1 && h->channels != 2) || !h->capacity || h->capacity > 1048576 ||
                h->sample_rate != 48000 || h->max_callback_frames != 960 ||
                h->bytes != 64 + size_t(h->capacity) * 32 || h->bytes > bytes_ ||
                bytes_ - h->bytes >= 65536 || h->reserved)
                throw std::runtime_error("shared ABI mismatch or owner not ready");
            channels_ = h->channels; capacity_ = h->capacity;
        } catch (...) { cleanup(); throw; }
    }
    ~SharedTransport() { cleanup(); }
    SharedTransport(const SharedTransport&) = delete;
    SharedTransport& operator=(const SharedTransport&) = delete;
    uint32_t channels() const noexcept { return channels_; }
    uint64_t end_frame() const noexcept { return load(&header()->end_frame); }
    bool write(uint64_t first, const float* input, uint32_t count, uint64_t now_ns) noexcept {
        if (!owner_ || !input || !count || count > 960 || first < next_ || now_ns < last_time_ ||
            first > UINT64_MAX / 2 - count) return false;
        for (uint32_t i = 0; i < count; ++i) {
            auto* s = &slots()[(first + i) % capacity_];
            auto rev = load(&s->revision);
            store(&s->revision, rev + 1);
            store(&s->frame, first + i);
            for (uint32_t c = 0; c < channels_; ++c)
                store(&s->samples[c], std::bit_cast<uint32_t>(input[size_t(i) * channels_ + c]));
            store(&s->revision, rev + 2);
        }
        next_ = first + count; last_time_ = now_ns;
        store(&header()->heartbeat_ns, now_ns);
        store(&header()->end_frame, next_);
        return true;
    }
    // count > 960 rejects the call without touching output. Valid-sized calls
    // always fill output, with zero for each unavailable frame.
    uint32_t read(uint64_t first, float* output, uint32_t count, uint64_t now_ns, uint64_t timeout_ns) const noexcept {
        if (!output || count > 960) return 0;
        auto* h = header();
        const auto end = load(&h->end_frame);
        const auto heartbeat = load(&h->heartbeat_ns);
        const bool fresh = end && load(&h->state) == 1 && now_ns >= heartbeat && now_ns - heartbeat <= timeout_ns;
        uint32_t copied = 0;
        for (uint32_t i = 0; i < count; ++i) {
            float samples[2]{};
            bool valid = false;
            if (fresh && first <= UINT64_MAX - i) {
                const uint64_t frame = first + i;
                auto* s = &slots()[frame % capacity_];
                const auto before = load(&s->revision);
                const auto stamp = load(&s->frame);
                for (uint32_t c = 0; c < channels_; ++c) samples[c] = std::bit_cast<float>(load(&s->samples[c]));
                const auto after = load(&s->revision);
                valid = before && !(before & 1) && before == after && stamp == frame;
            }
            for (uint32_t c = 0; c < channels_; ++c) output[size_t(i) * channels_ + c] = valid ? samples[c] : 0;
            copied += valid;
        }
        return copied;
    }
};
} // namespace krisp_local
