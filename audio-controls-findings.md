# Audio mute and volume controls

The evidence establishes separate system-device mute, Krisp virtual-device mute, device volume and microphone volume mapping. The virtual driver's scalar setter clamps to 0 through 1. It does not establish the UI slider scale, the optimal microphone level, or settings persistence. These gaps must remain explicit in an independent implementation.

## Current evidence and identity

- Current catalog: `ev_58c2d2c98cd0dc8a434233efa30e9e4448d97ecb7441ea8fc36caaa79099b6f4`, `evidence/current-translations.json`. Root's current app identity is 3.17.9. Labels establish vocabulary, not reachability or selected defaults.
- Current audio-device-manager focused disassembly: `ev_40c3d30f5402cd2db1686a714fbfa29b4d8397234167ce21d7b91b00ad74717d` and `ev_f05fb423432fd2a02f99b0d2fa32fbf0c3f9b5a27a3d0b21915582463d57eec9`, `evidence/audio-controls/dm-controls.result.json` and `dm-values.result.json`. Both check SHA-256 before/after and exit 0. Addon digest is `ef833e13e87064f51cbb547295b1c65138871906bcae651160b0daeeb3fcb3e6`.
- Installed original HAL focused disassembly: `ev_f450cb2b574459e56ac510c77e19f1be1d03fcd2aa396df46f272726073dec84`, `evidence/audio-controls/driver-controls.result.json`. Digest before/after is `50751bd7a50f4f8f2e2f116769cad75aab9b811344b7711174f41ce2ca695c30`. This matches retained original HAL inventory `ev_34cd25253410b24d95f4233aae3eacec699792b460c1dcce9a11a56df8825a90`.

All new original reads ran through REA capture-process using the declared static disassembly helper. No original app launch, mute/volume change, device start, IO callback registration or audio capture occurred. The `.txt` files beside the records are derived raw-frame projections for navigation; canonical Evidence remains in the result JSON.

## User controls

| Catalog key | Exact text | Supported meaning |
| --- | --- | --- |
| `your_mic_is_muted` | Your microphone is muted from Krisp. | App/virtual-path mute has a distinct message. |
| `mic_device_muted` | Microphone is muted from the system. | System input mute is distinct. |
| `spk_device_muted` | Speaker is muted from the system. | System output mute is distinct. |
| `krisp_spk_device_muted` | Krisp Speaker is muted from the system. | The virtual output can also be muted through system controls. |
| `pref_audio_section_mic_volume_title` | Microphone Volume | A microphone-volume preference exists. |
| `pref_audio_section_krisp_mic_volume_sub_title` | Krisp Microphone | The preference separates the Krisp microphone. |
| `pref_audio_section_krisp_mic_volume_sub_text` | Automatically adjust microphone volume at call start. | A call-start adjustment is described, but target value is not recovered. |
| `pref_audio_section_working_mic_volume_sub_title` | Working Device | The preference separates the working microphone. |
| `pref_audio_section_working_mic_volume_sub_text` | Select how your microphone volume is being adjusted. | An adjustment policy is exposed. |
| `pref_audio_section_volume_lock` | Lock at optimal level | A lock mode label exists. Optimal value remains unknown. |
| `pref_audio_section_volume_sync_with_krisp` | Sync with Krisp | A synchronization mode label exists. |
| `pref_descr_call_started_mic_muted` | Warns that your microphone is Muted from the Krisp App and allows unmuting it. | The app-mute state participates in a call-start reminder. |

All rows cite the current catalog Evidence above. These labels do not prove that system mute and app mute share one state.

## Native contract

Current `ChangeMuteStateNapi` checks three arguments and extracts a numeric device type, string device identifier and boolean mute value. `SetDeviceVolumeNapi` checks three arguments and extracts numeric device type, string device identifier and numeric volume, converted from double to Float32 for the native call. `LockKrispMicVolumeNapi` takes numeric device type and numeric level. Evidence: `ev_f05fb423432fd2a02f99b0d2fa32fbf0c3f9b5a27a3d0b21915582463d57eec9`. These recovered parsers are not tested by executing their setters.

The CoreAudio helpers select input scope for device type 0 and output scope otherwise. `SetDeviceMuteState` writes the boolean mute property (`bcvl`) through `AudioObjectSetPropertyData` on the resolved mute control. `SetDeviceVolumeScalarValue` checks for a volume control and whether it is settable, then calls `CAHALAudioDevice::SetVolumeControlScalarValue`. Failure paths include missing appropriate channels and property write errors. Thus this path changes a CoreAudio device/control property. It is not merely a gain factor inside the NC graph. It can address a physical working device or a virtual device, depending on the resolved identifier. Exact public identifier encoding and all device-type enum values remain unresolved. Evidence: the same current values record.

`SetVolumeMappingModeNapi` accepts numeric device type and numeric mode. `DeviceTuneUpController::UpdateVolumeMappingMode` stores the mode in memory and calls `SyncDeviceVolumes` when mode equals 1. `SetKrispDeviceVolumeControlMode` derives a control-state value from whether mode differs from 1. This gives mode 1 a concrete synchronization branch. It does not establish the complete enum vocabulary, mapping direction, optimal level or UI selection. The controller constructor initializes its stored mapping mode to 0. That constructor default is not proof of the app's selected persisted preference. Evidence: `ev_40c3d30f5402cd2db1686a714fbfa29b4d8397234167ce21d7b91b00ad74717d` and the current values record.

## Virtual HAL semantics

`KAD_VolumeControl::SetVolumeScalar` clamps the Float32 argument with max(0) and min(1), converts scalar to raw through `CAVolumeCurve`, then calls `SetVolumeRaw`. These instructions establish normalized scalar bounds. They do not establish a linear sample-amplitude curve or a 0-to-100 UI slider. The focused follow-up below resolves constructor range constants and the default transfer curve.

`ApplyVolumeToAudioRTE` requires the will-apply flag. Its enabled path uses stored gain and `vDSP_vsmul` except within a unity-adjacent interval. This is actual software scaling in the virtual driver. The constructor clears the will-apply flag; later configuration can change it. The focused follow-up below resolves constructor enabling and IO call sites; app-time control mode remains unresolved.

`KAD_MuteControl` initializes its boolean state to false. Its boolean property setter accepts a 32-bit value, normalizes any nonzero value to true, changes state under the control mutex and dispatches a property-change task only when the state changes. The observed setter does not write a settings file. Sample-zeroing call sites were not traced, so property behavior alone is not proof of the final microphone/speaker sample mute behavior. All virtual HAL statements cite `ev_f450cb2b574459e56ac510c77e19f1be1d03fcd2aa396df46f272726073dec84`.

## Persistence and implementation boundary

Retained historical JavaScript application Evidence `ev_a171e77e361a92e3a14ece5a0d849dd226d5669aaa7a8dbc9bafd807200e54ca` names `ChangeMuteState`, `SetDeviceVolume`, `GetDeviceVolume`, `SetVolumeMappingMode`, `ChangeVolumeMappingDevice`, `PreventVolumeExternalChange`, `DisableVolumeChangePrevention`, `LockKrispMicVolume` and `UnlockKrispMicVolume`. Its artifact digest is `fbd6a39ce6fde8685c6ca4c2ca78343aa50551b1bac74f532fd6c5801a23b622`; bind these wrapper observations to that earlier artifact. Its partial semantic coverage does not expose the persistence keys, restore timing or exact settings defaults. Current wrapper recovery was unavailable because the Wakaru provider is not configured; its failure envelope is retained in `dm-wrapper-recovery.result.json` and is not successful artifact Evidence.

For OpenKrisp, implement separate explicit app-route mute and selected-device system mute states. Keep virtual gain as normalized 0-to-1 state and expose device gain only when the selected CoreAudio control exists and is settable. Persist independent preferences using the independent app's store. This is a recommended independent contract, not a claim that the original uses that storage model. Do not silently make a software slider change the physical device. Keep lock and synchronization as separate pending semantics until their levels, direction and event response are established. Trial or paid gates are outside this contract.

Remaining parity gaps: UI slider scale/default, optimal lock level, full mapping enum/direction, app-time control mode, app mute versus HAL mute linkage, external hardware mute/HID synchronization, persisted values/keys and restore timing. The follow-up resolves the virtual curve and identifies conditional sample-zeroing paths, but does not exercise them. No audio processing or setter runtime test has been performed.


## Focused follow-up: default virtual curve and IO gates

Additional current static Evidence, all bound to unchanged installed HAL SHA-256 `50751bd7a50f4f8f2e2f116769cad75aab9b811344b7711174f41ce2ca695c30`:

- `ev_093d19187f011b55c87fa0e10469a48280f3284900ee4d065d19c08014bb98de`, `driver-curve.result.json`: raw setter, scalar/raw/dB conversion, microphone/speaker constructors and IO methods.
- `ev_3599d1c322739c673d4fdc02adfc6cb1747872aad8f6fb89be49b00da117573e`, `driver-constants.result.json`: bounded constant-section lines covering addresses `0x14b20` through `0x14b34`.
- `ev_505125edd638b8b7cef06385c8517f2167e65ed85f6dcc870ac274207dcaed0d`, `curve-transfer.result.json`: curve constructor, transfer setter and raw-to-scalar conversion.
- `ev_f3e85d6dd6819b2918d950cc78196bdaab4ba93e479544ec90db67d24c4d323a`, `curve-exponent-window.result.json`: bounded constant-section lines covering the constructor's `0x14d80` exponent pair. An earlier exponent-window record omitted `0x14d80` due to output-line alignment; it is retained as an incomplete read, not supporting the exponent.

The constructor constants decode as raw minimum 0, raw maximum 96, dB minimum -96 and dB maximum 0. The constructor copies raw minimum into the initial raw value. The curve constructor enables its transfer function, sets selector 5 and loads Float32 exponent parameters 2 and 1. For this single 96 dB range, scalar-to-raw applies exponent 1/2, multiplies by 96 and rounds to nearest integer using `fcvtas`. Raw-to-scalar clamps the raw value and returns `(raw/96)^2`. Raw-to-dB interpolates the single range as `raw - 96`; scalar-to-dB first performs the quantized scalar-to-raw conversion. This is derived from the instructions plus decoded little-endian constants. No original function was invoked.

The sample gain uses an additional conversion. For finite normalized scalar `s`, the default constructed curve gives approximately:

```text
r = round_nearest_away(96 * sqrt(clamp(s, 0, 1)))
v = (r / 96)^2
q = trunc_toward_zero(96 * v)
amplitude = (q / 96)^2
```

`SetVolumeRaw` first obtains `v` from raw-to-scalar, converts `96*v` to an integer with `fcvtzs`, then calls raw-to-scalar again and stores the result as amplitude gain. Thus the default virtual sample gain is quantized and approximately `s^2`, not exactly linear `s`, and not `10^(dB/20)`. Float32 arithmetic and both integer conversions matter at boundaries. Changing the transfer function or range would invalidate this simplified formula. The targeted constructors do not change the curve constructor's transfer selector. Other later mutation paths have not been excluded.

The amplitude application function treats gains from the Float32 constants near 0.99 through 1.01 as unity and returns without multiplying. Outside that inclusive interval it invokes `vDSP_vsmul` on twice the supplied frame count. This helper's stereo sample-count assumption is explicit in the instruction `lsl w5, w2, #1`; microphone IO passes its frame count directly too. The device's actual buffer allocation/layout must be checked before copying that behavior into an independent mono implementation.

Both `KAD_MicDevice` and `KAD_SpeakerDevice` constructors call `SetVolumeScalar(1)` followed by `SetWillApplyVolumeToAudio(true)`. These are virtual-device constructor defaults, not persisted UI preferences. Both also initialize the separate control-state field at offset `0x2e8` to 0. In microphone `DoIOOperation` for the read operation and speaker `DoIOOperation` for the write operation, gain application requires a control-active byte and that separate control-state field to equal 1. Therefore will-apply=true alone does not prove gain is active when the device is constructed. The running app's selected mode and change timing remain unknown.

The same IO methods contain conditional mute-zeroing branches: microphone read zeroes `4*frames` bytes and speaker write zeroes `8*frames` bytes when the two inspected mute-related flags are set. Otherwise the paths continue toward their buffer source/sink and possible gain application. Their offsets are consistent with the embedded mute object from the constructors, but the meaning of the companion active flag and its runtime updates have not been fully traced. This narrows the earlier sample-zeroing gap without claiming an exercised mute path.

OpenKrisp's existing app-route linear attenuation must remain labeled as its own behavior. These recovered virtual HAL formulas establish a specific original default curve for a future explicit parity choice. They do not justify changing physical device volume or silently replacing the independent curve in this reporting task.
