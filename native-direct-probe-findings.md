# Native NC processing observed

On 2026-10-15, two REA process captures ran the reviewed direct-factory adapter against the installed outbound NC model. Both completed 100 synchronous callbacks and returned 48,000 finite Float32 samples. This is actual native processing in an isolated helper, not just model loading or a synthetic factory fixture.

No microphone, speaker playback, audio graph, HAL device, CoreAudio restart or administrator operation was used. Original weights stayed at their installed path. No vendor artifact or generated output is included in Git.

## Evidence and identity

- `direct-nc-on-v1`: Evidence `ev_7034d8272ba48730207d483805f9ad9da71049b1a7b812222aecd0a9c637fc45`, exit `0`, complete raw capture, verified owned-process cleanup. Scenario/result and private output are under `evidence/model-probes/direct-nc-on-v1`.
- `direct-nc-bypass-v1`: Evidence `ev_abb78582f1221125c4d65f66935d0711799541a1b7e308fe5d8dcf209abcc5e7`, exit `0`, complete raw capture, verified owned-process cleanup. Scenario/result and private output are under `evidence/model-probes/direct-nc-bypass-v1`.

Both metadata records agree on before/after hashes:

- addonPath: `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755`.
- modelPath: `12110c114a3c6c4e2a00c26b22d06463239d096da9f7b71a948fd3a7005b355d`.
- adapterPath: `80d8c9e3c5023303508a5283daa662052264fe3a9db99623d9b3106b63364fa5`.

The model is `c8.f.m.528d1f-1.0.1_1.0.kef`. Each scenario runs `/usr/bin/sandbox-exec` with `(version 1) (allow default) (deny network*)` before Node. The launcher requires loopback denial `EPERM` before loading the adapter, then checks the exact reviewed addon digest. Both runs passed that prerequisite. REA does not supply a syscall-level network trace; the claim is execution under the recorded denial profile, not a whole-program absence of network code or attempted connections.

## Results

Both runs use the same deterministic one-second signal, 48 kHz, 480 samples per frame, 100 frames. It contains seeded noise and triangle tones, with no speech or recorded user audio. The second run changes only the recovered bypass flag. Both return constructed/direct-process/teardown success, and the launcher validates counts and finite samples before publishing private output.

| Run | Output RMS | Peak absolute sample | Output SHA256 |
| --- | ---: | ---: | --- |
| direct-nc-on-v1 | 0.000489439979 | 0.007924040779 | `fd389eb36788f4e2f707d63e987fd9205ff6dc1323ef94cd1ab3600960077290` |
| direct-nc-bypass-v1 | 0.091605755670 | 0.235997900367 | `d65f14f3868eccb927bd4da5b9a2ae2bc61755e29ae08e432cb3129f67c4f671` |

The outputs differ in 47,500 samples. Difference RMS is 0.091577960558. This supports distinct NC-versus-bypass processing on this fixture. Reduced level is not a speech-quality score or proof that desired speech is preserved.

## Implementation and validation

`app/native-model-probe` contains typed ABI views, a separate-library synthetic factory fixture, the Node adapter, gated launcher and reusable tests. The factory uses its original shared-pointer control block. The adapter keeps descriptor, callbacks and image alive through processor destruction, copies callback samples before return and catches vendor exceptions before unloading. It directly invokes the concrete processor; it does not patch state or claim SDK registration state is enabled.

`./verify` passed collector and cross-library ownership tests in release and ASan/UBSan, launcher fail-closed/output fixtures, and 20 host-only Node input-validation cases. Verification log `evidence/native-direct-probe-verify.log`, SHA256 `af5d72df9a55d5ebe11bf51b5d8b0e57e10152dec0579f2ae779b92044711cd3`. A subsequent rebuild produced the same adapter digest as the actual runs. Independent review checked the native ABI/lifetimes and separately audited retained runtime exits, output bytes, metadata and hashes.

## Remaining work

This probe is not integrated into the desktop or routing helper. It uses one model and one synthetic fixture on one inspected binary. Actual speech quality, comparative original-app behavior, live microphone/speaker paths, sustained processing deadlines, startup cost, algorithmic delay, end-of-input tail handling and other models remain unverified. Equal output/input length does not imply zero latency or complete tail preservation. The selected finalizer is a no-op; these runs add no padding and make no tail claim.

The next implementation step is a persistent isolated provider using this proven call path, with explicit version/model validation, failure cleanup and app selection. Keep model redistribution separate from installed-file use. Full retained local parity is not complete.
