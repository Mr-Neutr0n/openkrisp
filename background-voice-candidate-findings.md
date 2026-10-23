# Background voice candidate processing gate

The HVC-lfb asset constructed and processed through the existing ordinary-NC frame factory in two bounded CPU children. Both children completed and tore down cleanly. The outer capture failed because its runner incorrectly required bypass output to equal the raw fixture. Retained ordinary-NC captures show the same bypass output byte for byte. This is a candidate load/processing observation, not a successful overall assertion run or proof of background-voice isolation.

## Capture and identities

REA `ev_56b1a5141f8d1e8f0eee9728b1d110f18bb2d9e628735ed0e21cca79d2bbb9fe` is retained at `evidence/model-probes/hvc-candidate-20261023-v1.result.json`. Its raw output retains all 5928 bytes, without truncation. REA reports verified owned-process cleanup and removed temporary root. The outer process exits 1 with `Bypass differs from exact fixture`; neither native child fails.

Before/after pins match:

| Artifact | SHA256 |
| --- | --- |
| HVC-lfb `hs.c6.f.m.75df8f.berlin.kef` | `54e2913ea45734adc3323407e43f55b14afade256ab4da6226c2b6e30604cbf4` |
| Installed MediaSP addon | `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755` |
| Own packaged native adapter | `216d95381d62f24605103a179d2782c967621baccdf7f06493d76f06b8d26025` |
| Node executable | `1ef99ea25fe70c9b67e7efe768ef8ee22148d3cabc703db6131b57aeb617d040` |

The deterministic noise/triangle-tone input SHA256 is `6ef4b0e40cf74b1bbe3b97b5d36ee79a2e42b9e7eadb9240afe92a2fc2fc7b5b`. Each fresh child uses 48 kHz mono Float32, 480-sample frames and suppression 100. Active and bypass each report 100 processed frames, 100 callbacks, processor construction, direct processing, 48000 finite output samples and `teardownComplete: true`. Each output has 192000 bytes. The harness backend label remains `ordinary-nc-direct`; it identifies the selected ABI path, not original desktop BVC dispatch.

| Mode | Output SHA256 | RMS |
| --- | --- | --- |
| Active | `a04779babdf940bc4c3f3d44b8cb020e4b159cf44b23ec92783b08acf6b21fd1` | 0.004810434738109847 |
| Bypass | `d65f14f3868eccb927bd4da5b9a2ae2bc61755e29ae08e432cb3129f67c4f671` | 0.09160575567011363 |

## Corrected bypass comparison

Read-only review compared the actual candidate bypass bytes with two retained ordinary outbound-NC outputs:

- `direct-nc-bypass-v1/output.f32le`, REA `ev_abb78582f1221125c4d65f66935d0711799541a1b7e308fe5d8dcf209abcc5e7`.
- `persistent-nc-bypass-20261017-v1/output.f32le`, REA `ev_649e0bc972f011ec9611767d806b4acf591787e62b0eb3fbf7138cb7af3a0d94`.

All 192000 bytes match, with the bypass SHA256 above. These baselines use the same fixture, frame dimensions, suppression, bypass setting and addon. They use the ordinary outbound model `12110c114a3c6c4e2a00c26b22d06463239d096da9f7b71a948fd3a7005b355d` and different earlier own adapter builds.

The candidate bypass contains 500 initial zero samples. All 48000 samples differ numerically from the raw fixture; RMS difference is 0.05919646892 and maximum absolute difference is 0.2230224758. These observations invalidate raw-input equality as this gate's bypass oracle. The zero prefix does not establish complete latency, its cause, resampling behavior or tail preservation. The outer capture remains failed; the later comparison does not rewrite its recorded status.

## Active comparison and limits

The retained ordinary active output, `direct-nc-on-v1/output.f32le`, REA `ev_7034d8272ba48730207d483805f9ad9da71049b1a7b812222aecd0a9c637fc45`, has SHA256 `fd389eb36788f4e2f707d63e987fd9205ff6dc1323ef94cd1ab3600960077290`. Against that file, 47500 of 48000 candidate active samples differ. RMS difference is 0.004819544490219629; maximum absolute difference is 0.042005964089185. Ordinary active RMS is 0.0004894399792978428.

The historical active comparison alone changes both model and own adapter build. A subsequent same-adapter ordinary control closes that particular confound: REA `ev_2f7141d178b135212d4f829f61124b34f138dcc284d300ba85dc65837dd2e446`, retained at `evidence/model-probes/ordinary-nc-hvc-control-20261023-v1.result.json`, uses the same current Node, probe, adapter, addon, fixture and active settings as the HVC child. It selects the ordinary outbound model instead. It exits zero, retains untruncated output, matches before/after pins and reports verified owned cleanup with temporary root removed. Its child processes 100 frames with 100 callbacks, 48000 finite samples and clean teardown.

The control output is byte-identical to the old ordinary active file, with SHA256 `fd389eb36788f4e2f707d63e987fd9205ff6dc1323ef94cd1ab3600960077290`. Against this current control, HVC active still differs in 47500 samples with RMS difference 0.004819544490219629 and maximum absolute difference 0.042005964089185. This supports a bounded model-dependent output observation in the tested harness. Noise/tones and output amplitude cannot measure primary-speaker preservation or nearby-voice rejection.

The HVC catalog's declared 32 kHz work rate does not contradict this bounded 48 kHz interface observation, but no internal rate conversion is established. HVC-sfb, persistent HVC workers, settings/RD/energy variants, enrollment/conditioning elsewhere, production admission and the complete original BVC graph remain unproved. See `background-voice-native-findings.md` for the static construction gaps.

The next runtime gate should use the retained bypass output as a named comparison and preserve the failed raw-input assertion in history. The same-adapter control supports the tested output difference; any BVC quality gate still needs independent target/background speech controls. No production switch should be enabled from this candidate capture alone.

The two candidate children and the ordinary control ran through REA with a deny-network sandbox and recorded loopback EPERM. Hashes are sampled file checks, not atomic loader binding. No physical audio, administrator operation or original application UI ran. This report performed only retained-evidence and output review; it did not rerun original code.
