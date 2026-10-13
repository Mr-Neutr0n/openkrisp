# Original virtual-device declarations

A read-only CoreAudio probe ran through REA process capture. The source is `probes/audio-device-inventory.swift`. It creates no audio callback, starts no stream, records no audio and writes no property. The REA capture retains the probe executable digest and terminal output.

With Krisp stopped, the public device list contained no name or UID matching Krisp. Evidence `ev_9b9a4b956a42a9c36195a15375c818744bda4c49e05677b69ff17eb46843c5bf`.

After Krisp started through macOS LaunchServices, the same probe found these devices. Evidence `ev_8c479ebb5f10eda0d5ad1463591ea34d9366cb49d378fa647ccbe2f4bfd64668`.

| Property | Microphone | Speaker |
| --- | --- | --- |
| Name | krisp microphone | krisp speaker |
| UID | KrispAudioDeviceMic | KrispAudioDeviceSpeaker |
| Input channels | 1 | 0 |
| Output channels | 0 | 2 |
| Declared sample rates | 48,000 Hz only | 48,000 Hz only |
| Current physical and virtual format | 32-bit packed Float PCM | 32-bit packed Float PCM, interleaved stereo |
| Bytes per frame | 4 | 8 |
| Current buffer frames | 480 | 512 |
| Declared buffer frame range | 15 to 480 | 15 to 960 |
| Device and stream latency fields | 0 frames | 0 frames |
| Safety offset field | 0 frames | 0 frames |
| Running-somewhere field | 0 | 0 |

The format ID is `lpcm` and flags are 9, the combination of float and packed flags. The transport type is `virt`. Both devices declared manufacturer Krisp and alive=1.

These are property declarations at two instants, not active-stream measurements. Zero declared latency does not mean zero real latency. The current buffer sizes are not proven defaults. This does not establish the exact visibility transition rule, hidden app-I/O devices, concurrent-client behavior, stream timestamps, processing quality or hardware reconnection behavior. Names and UIDs select devices but do not authenticate the loaded driver bytes.

No replacement driver is installed. The independent implementation must use distinct bundle and device identities to coexist during comparison, while matching retained routing behavior. `driver-declarations.json` preserves this baseline for later comparison.
