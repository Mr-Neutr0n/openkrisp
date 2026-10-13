# Native inventory

Static REA CLI inspection of `/Users/harikp/Applications/krisp.app`, 2026-10-13. The app was not launched. Original files were not changed. Full evidence is in `evidence/native/`. `native-boundaries-summary.json` selects observed symbols from those records; it is not a new REA observation.

## Identity

The bundle declares Krisp 3.16.8, identifier `ai.krisp.krispMac`, and minimum macOS 12.0. It requests microphone, system audio capture, and Bluetooth permissions. Its URL scheme is `aikrispapp`.

Source: `info-plist.json`, Evidence `ev_b99199071fe8d073714bd29112e5dac452c584678225d09bcdd4e1ce4756cf4c`.

## Integrity

The REA bundle inventory reports five ASAR companion mismatches: `kr-audio-dm`, `kr-ext-hub`, `kr-media-sp`, `kr-native-utils`, and `kr-node-logger`. Their observed native files do not match the digests declared by ASAR metadata. The investigation used `record-and-continue`. Conclusions from these companions describe the current local bytes. Their agreement with the original distribution remains untrusted.

Source: `artifact.json`, inspection Evidence `ev_8ffbd9d68802867df2fccd15b83cfd5ff1bf885be54d260d81bce84cac99d01d`, inventory Evidence `ev_e9c2f082e96a01b0b07c8d7592751b75938b3ad3d2ed21cf8e2db00c3618b818`, manifest `agm_66139049ad4022c72343794078563015945c24444cf08b3f1bea86fdcd283ff4`.

## Observed native boundaries

| Component | Observed static facts | Evidence |
| --- | --- | --- |
| `kr-audio-dm.node` | ARM64. Links CoreAudio and AudioToolbox. Exports N-API handlers for default audio devices, mute, volume, volume mapping, HID control, Krisp device configuration, mic volume locking, and audio enhancement. Imports CoreAudio device I/O and property listeners. | `ev_4cf13e26f268ec8f71085eb3d490dee1e91b5efbc12dff8a3669ed551efa6ca4` |
| `kr-media-sp.node` | ARM64. Links CoreAudio, Accelerate, ScreenCaptureKit, MP3 LAME, AEC, Daily, Socket.IO TLS, and Krisp WebSocket wrapper libraries. Exports N-API handlers for media graphs, model loading, processor settings, recording, ASR, diarization, language detection, translation, RTC transcription, and audio redaction. Imports `AudioHardwareCreateProcessTap` and aggregate-device APIs. | `ev_82a288cac329f8c56c70b229dab17784b6f6ae35d0d61b7bde9ed4b7015715d1` |
| `libaec-sdk.dylib` | Universal ARM64 and x86_64. Exports `krips_aec::Aec_WebRTC` stream processing, reverse-stream analysis, delay, configuration, and mute methods. Also exports WebRTC `EchoCanceller3` symbols. | `ev_f2e74c223103fdf553f18045b9e2493be2cb54ae62b7a47d5682c079f1206435` |
| `libdaily-core-sdk-wrapper.dylib` | ARM64. Exports virtual microphone and speaker frame APIs, VAD, device selection, call join/leave, recording, transcription, dialout, and telemetry callbacks. These symbols do not prove which app paths use them. | `ev_99203e8788bb23c3a6613415e79affe0b66e1cfeb94d12ca7fea0a82cf922fc4` |
| `kr-ext-hub.node` | ARM64. Links ApplicationServices, Carbon, CoreGraphics, and Foundation. Exports observation and action handlers. Symbol inventory includes Zoom process names and mute-state types. | `ev_c1ad68ae99baa784d241b972643e14f75234153730354c1a3f9e0c629082712b` |
| `kr-native-utils.node` | ARM64. Links IOKit, CoreAudio, AudioUnit, and Security. Exports device recording, secure storage, permissions, system events, process monitoring, app control, hardware information, ZIP extraction, and troubleshooting methods. No secure storage values were read. | `ev_d5a7c268a91fe74d0e1be67ea708c3c5c726c11cb293ee43f1ef2a3bcbe401dd` |

Mach-O exports and imports can be incomplete for stripped binaries. Symbol presence is static evidence of a declared boundary, not an execution trace or a full behavioral specification.

## Models and routing

The authenticated inventory contains eight audio `.kef` resources and `models.json`. The files range from about 0.9 MB to 32.6 MB. Names include `diar_2.0.0_1.0.kef` and seven `c5`, `c6`, `c8`, or `hs.c6` variants. The inventory does not decode model contents or establish their semantics. No driver bundle or kernel extension path occurs in the bundle inventory. The installed HAL driver was inspected separately below.

Source: artifact inventory Evidence above. ARM64 dyld traversal is complete within its declared boundary, Evidence `ev_495d5179c1cfd10691b76e585ffdf155db8ab9006070248ad9d724519710ccf0`, saved as `dyld-resolution.json`. System libraries, signing enforcement, environment fallback paths, and runtime loads remain outside its coverage.


## Installed HAL driver

`/Library/Audio/Plug-Ins/HAL/KrispAudio.driver` declares version 2.1.8, identifier `ai.krisp.krispMac.audioDriver`, and minimum macOS 10.12. Its CFPlugIn factory UUID is `18D8EC73-96AE-4B58-A299-B2D9F12BB568`, with factory symbol `KAD_Create`. Its declared plug-in type UUID is `443ABAB8-E7B3-491A-B985-BEB9187030DB`. The binary contains ARM64 and x86_64 slices.

Sources: `driver-plist.json`, Evidence `ev_3b54be07a9d8b8d471f695b74de5c6389ec93a56e2cf8ed0760a4fab1181131c`; `driver-macho.json`, Evidence `ev_34cd25253410b24d95f4233aae3eacec699792b460c1dcce9a11a56df8825a90`.

Signature metadata names Developer ID Application Krisp Technologies, Inc., team `U5R26XM5Z2`, with hardened runtime enabled. REA inspected a digest-verified snapshot. It did not validate installed filesystem trust or prove that the current OS accepts this driver.

Source: `driver-signature.json`, Evidence `ev_9940414d63490450c244cfe3e3c452e69efaec9389975a6af51aae33b514f43d`.

Observed symbols define `KAD_MicDevice`, `KAD_SpeakerDevice`, and `KAD_AppIODevice`. Each device has client registration, start/stop I/O, begin/do/end I/O operations, timestamps, configuration-change methods, and property getters/setters. `KAD_AppIODevice` exports `WriteFramesToKrisp(unsigned int, double, void*)` and `ReadFramesFromKrisp(unsigned int, double, void*)`. `CARingBuffer` exports frame storage, retrieval, and time-bound methods. Controls include mute, volume scalar, volume dB, raw volume, and applying volume to audio. The base device exposes visibility and Krisp connection/disconnection methods. Client tracking records active audio clients. An app watcher monitors the Krisp process.

These declarations support an independent design with separate microphone and speaker devices, an app-facing audio channel, time-indexed frame buffers, mute/volume controls, and application connection lifecycle. To verify parity, check channel counts, sample formats and rates, latency, zero-timestamp periods, behavior on missing frames, device visibility, concurrent clients, app crash/reconnect, and property notifications. The current symbols do not establish these values or the wire protocol. Mach-port dispatch symbols occur, but they do not prove that audio samples travel through Mach messages.

The deep search attempt is preserved in `driver-strings.json`. REA Ghidra refused the universal Mach-O because it cannot enforce a selected slice. The separate CLI also lacks Ghidra configuration. No advertised REA thinning operation was available. No external binary transformation was used. Driver load, unload, installation, and removal were not attempted.

## Reconstruction implications and unknowns

The local processing implementation needs CoreAudio device routing and process capture, a media processing graph, model lifecycle management, echo cancellation, recording, and native permissions. The observed ASR and diarization entry points show that removing cloud code alone does not remove all speech functions. Their offline availability and required models still need code and behavior evidence.

Noise suppression quality, accent conversion, voice conversion, model format, processing latency, exact graph configuration, and virtual device installation remain unresolved. The current inspection does not recover neural weights, training data, or rights to redistribute Krisp binaries and models. An independent public implementation needs independently licensed processing and model assets. Static API similarity cannot verify full parity.

## Focused inference follow-up

Electron Framework declares version 40.8.5, Evidence `ev_89e1fc43bfba806f7a602eb93548b60e3c78330f852fd683e44835a6ed23428a`, saved in `electron-plist.json`.

MediaSP retains useful named symbols for model parsing and inference. This makes focused static recovery plausible. It does not establish that all model behavior can be recovered. Selected exact names and addresses are in `model-inference-candidates.json`, derived from MediaSP Evidence `ev_82a288cac329f8c56c70b229dab17784b6f6ae35d0d61b7bde9ed4b7015715d1`.

| Candidate | Mach-O symbol address | Question for focused decompilation |
| --- | --- | --- |
| `LoadModelsNapi` | `0x1f7ac` | Which JavaScript fields select each model? |
| `LoadModelsWorker::Execute` | `0x681c` | How does model loading reach the SDK? |
| `KefBlobLoader::readHeader` | `0x4809f0` | What header and integrity fields does KEF require? |
| `KefBlobLoader::init` | `0x4803dc` | How does initialization handle model bytes? |
| `KefBlobLoader::readConfigurationData` | `0x480b84` | Which configuration data does the loader parse? |
| `KefBlobLoader::readFilesMapData` | `0x480df0` | How does KEF identify contained files? |
| `KefBlobLoader::readFiles` | `0x481064` | How are model files decoded? |
| `KefConfigReader::getInferenceConfig` | `0x48698c` | Which backend and tensor configuration fields matter? |
| `InferenceEngine::loadNetwork` | `0x4961c4` | How does the SDK select ONNX or native GRU inference? |
| `NoiseCancellation::DfProcessor::initInferEngine` | `0x1c8f84` | How does noise cancellation configure inference? |
| `NoiseCancellation::DfProcessor::process` | `0x1c9168` | Which preprocessing and per-frame settings apply? |
| `NoiseCancellation::DfProcessor::infer` | `0x1ca0ec` | What tensors and state feed noise inference? |
| `NoiseCancellation::MainCleaner::cleanNoise` | `0x1cff48` | How do inference results modify audio? |
| `NoiseCancellation::MainCleaner::preProcess` | `0x1d0a34` | Which features and windows feed the model? |
| `NoiseCancellation::MainCleaner::postProcess` | `0x1d1750` | How does reconstruction produce output frames? |
| `OnnxExecutableNetwork::evaluate` | `0x49a048` | What input/output and recurrent-state rules apply? |
| `OnnxExecutableNetworkRuntime::Run` | `0x49b610` | Which ONNX Runtime options and invocation apply? |

Additional exports name native GRU evaluators and ONNX state propagation. `KefBlobLoader::_decryptMutex` is a symbol. It suggests a synchronized decoding step, but it does not prove encryption, reveal an algorithm, or authorize reuse of model contents. Addresses above are Mach-O symbol values. Resolve them in the selected Ghidra import before treating them as provider procedure addresses. The local companion remains untrusted against the ASAR digest. No long deep analysis or runtime probe was started.

## Verified KEF header boundary

One focused Ghidra dossier completed for ARM64 `KefBlobLoader::readHeader`, exact identity `__ZN5KRISP9KefReader13KefBlobLoader10readHeaderEPKhm`, address `0x4809f0`. Saved in `kef-header-function.json`, Evidence `ev_ebf047a853a651e85a42b22315e059029e8cbe7241bbfb1222f0d7f92a93846b`. This is recovered pseudocode corroborated by the included assembly. It is not original source or a runtime observation.

The function rejects a blob shorter than 52 bytes. It copies bytes 0 through 39 into a string field. It reads three 32-bit words at byte offsets 40, 44, and 48. It stores these words in separate object fields, sums them with 32-bit arithmetic, and rejects a sum greater than the supplied blob length. Both failures raise `KmsFileReadFailureException` with an invalid-size message. No comparison against magic bytes, version bytes, or a digest occurs in this function. Such checks may occur elsewhere.

This establishes a 52-byte minimum structural header. The meanings of the first 40 bytes and the three words remain unknown. The result does not establish that a packaged KEF model can be independently decoded or used. Configuration parsing, file boundaries, model representation, and network initialization still need separate evidence. No secret keys, model contents, or decryption bypass were extracted.

The one function required a fresh Ghidra import and analysis lasting roughly three minutes. The CLI closes its ephemeral program after the operation. A second dossier would require another import, so `LoadModelsWorker::Execute` was not analyzed in this bounded pass. Native model parity remains unresolved.
