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

## Persistent session results

On 2026-10-17, two further REA captures used `run_persistent_probe.cjs` with the same installed addon, model and deterministic signal. Each kept one processor open across five `process` calls of 1, 17, 3, 29 and 50 frames, then explicitly closed it. Both returned 100 callbacks, 48,000 finite samples and confirmed teardown. Both exited with code 0 and retained complete captures under the same network-denied profile. Loopback failed with `EPERM` before adapter loading.

| Run | Evidence ID | Comparison with retained single-call output |
| --- | --- | --- |
| `persistent-nc-on-20261017-v1` | `ev_99071294c29921e2053b1c07202b132deaf318a776f2882c32ed96ab98bab06b` | Byte-identical to `direct-nc-on-v1` |
| `persistent-nc-bypass-20261017-v1` | `ev_649e0bc972f011ec9611767d806b4acf591787e62b0eb3fbf7138cb7af3a0d94` | Byte-identical to `direct-nc-bypass-v1` |

The output hashes therefore match the Results table above. This establishes that these five API batch boundaries preserve the retained output for this fixture. It does not establish arbitrary session duration, timing, speech quality or tail behavior. The adapter digest for these captures is `1520a75cee741c8033b49877ac2e59a2156eb6a709ebbd34f28ee4053e8cbd35`. Addon, model and adapter hashes were unchanged before and after each run.

REA reported verified owned-process-group cleanup and removed temporary roots for both captures. The bypass capture also lists one unverified process with reason `platform_binary_environment_withheld`. That observation limits process attribution; it is not evidence of a leaked owned process. Scenario JSON, capture JSON, metadata and output files are retained locally under `evidence/model-probes/` with the run names above.

The existing complete `evidence/native-persistent-verify-20261017.log` records passing release and ASan/UBSan collector/ABI checks, launcher fixtures, 20 host-only validation cases, persistent native-session cases and persistent launcher fixtures. Its SHA256 is `276b2ea39b5f65eb31717a0e66b9a273be5ac7c98d2c8b510ca05daf566e9d2c`. These fixture checks do not load Krisp.

## Remaining work

This probe is not integrated into the desktop or routing helper. It uses one model and one synthetic fixture on one inspected binary. Actual speech quality, comparative original-app behavior, live microphone/speaker paths, sustained processing deadlines, startup cost, algorithmic delay, end-of-input tail handling and other models remain unverified. Equal output/input length does not imply zero latency or complete tail preservation. The selected finalizer is a no-op; these runs add no padding and make no tail claim.

The native adapter now supports bounded persistent sessions. The next implementation step is an isolated app provider using this call path, with explicit version/model validation, failure cleanup and app selection. Keep model redistribution separate from installed-file use. Full retained local parity is not complete.


## Final adapter check after close-contract fix

On 2026-10-17, the adapter gained a sticky failure for callbacks during processor destruction. Cleanup still releases the processor, callbacks, supplier and loaded image before explicit close reports that contract error. Repeated close reports the same error without repeating native deletion. A host-only fixture reproduced the missing error before the fix and passed afterward. The complete component verification passed; its retained log is `evidence/native-persistent-close-verify-20261017.log`, SHA256 `276b2ea39b5f65eb31717a0e66b9a273be5ac7c98d2c8b510ca05daf566e9d2c`.

The final adapter SHA256 is `4b53c9f15842680c3e6517a5df23cbcfff3c977781202da1ab7d31b2e22046c1`. Two v3 scenarios ran after the final verification build finished, with no concurrent rebuild. Both processed the installed model through five batches, exited 0, returned 100 callbacks and 48,000 finite samples, and recorded `teardownComplete: true`. Both metadata records show unchanged addon, model and adapter hashes before and after processing. Both record loopback denial `EPERM` under the same explicit network-denied sandbox profile.

| Final run | Retained capture | Output comparison |
| --- | --- | --- |
| `persistent-nc-on-20261017-v3` | Partial capture in the result envelope; no Evidence ID because REA cleanup failed | Byte-identical to `persistent-nc-on-20261017-v1`, SHA256 `fd389eb36788f4e2f707d63e987fd9205ff6dc1323ef94cd1ab3600960077290` |
| `persistent-nc-bypass-20261017-v3` | Evidence `ev_0351c467f523d0bfeaadcb82ad979cc17ca7a23d2edc89f7cb5dc393fc351d9b`, complete capture | Byte-identical to `persistent-nc-bypass-20261017-v1`, SHA256 `d65f14f3868eccb927bd4da5b9a2ae2bc61755e29ae08e432cb3129f67c4f671` |

The NC v3 launcher completed successfully, but REA returned `cleanup_incomplete`. It could not read an ownership token for live candidate PID 96318 and retained its temporary root. A subsequent read-only `ps` query identified that PID as a Google Chrome renderer. This query does not repair or replace REA's ownership proof. The partial capture and published output support the processing result, while owned-process-group cleanup and temporary-root removal remain unverified for this capture. No process was killed manually.

The bypass v3 capture reports verified owned-process-group cleanup and removed its temporary root. It lists two unrelated processes with `sysctl_failed_22`; REA left them untouched. These are process-attribution limits, not proof of a leaked owned process. Both captures retain the existing sampling, inherited-environment and absent network-trace limits. No tail, speech-quality, sustained-deadline or live-audio claim follows from these checks.

An earlier NC v2 capture has Evidence `ev_7cbcd8ed6430f7fd289bbaf51362c56738f735c57f1e9a9aaa3eee38ec2bc096` and verified cleanup. Its timing may overlap a rebuild, so it is retained as supplemental evidence only. The v3 metadata and byte comparisons above establish the final build's processing result independently. Scenario JSON, result envelopes, metadata and private outputs remain under `evidence/model-probes/`.
