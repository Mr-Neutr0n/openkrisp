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


## Supervised worker broker runtime results

On 2026-10-17, two REA process captures ran the new native `installed-worker-probe` against the installed addon and outbound model. The parent built the fixed sandbox command, started Node with only PATH and the reviewed DYLD library directory, checked exact readiness, and exchanged 100 framed requests with one persistent native processor. The worker required loopback denial EPERM and checked the fixed addon/model digests plus the supplied Node/adapter digests before loading the adapter. Each request carried one 480-sample frame. The parent sent close, half-closed requests, validated the close acknowledgement and response EOF, and reaped a successful direct-child exit before publishing output. No audio graph, microphone, playback, administrator action or CoreAudio operation was used.

| Run | Processing result | Startup / 100-frame processing | REA evidence and cleanup |
| --- | --- | --- | --- |
| `supervised-worker-nc-20261017-v1` | Exit 0; 100 frames; 48,000 samples; teardown confirmed | 246 ms / 64 ms | No Evidence ID. REA returned cleanup_incomplete and retained a partial capture. |
| `supervised-worker-bypass-20261017-v1` | Exit 0; 100 frames; 48,000 samples; teardown confirmed | 126 ms / 49 ms | Evidence `ev_b3a8b624dc15c550a28ec23f5d92a3f133185e8a256ad71d916c430f4c8e9cb5`; complete capture; owned-process-group cleanup verified; temporary root removed. |

Both outputs contain 192,000 bytes and match the corresponding retained `direct-nc-on-v1/output.f32le` and `direct-nc-bypass-v1/output.f32le` byte for byte. Their SHA256 values are `fd389eb36788f4e2f707d63e987fd9205ff6dc1323ef94cd1ab3600960077290` and `d65f14f3868eccb927bd4da5b9a2ae2bc61755e29ae08e432cb3129f67c4f671`. The complete finite input was validated before spawning; its SHA256 is `6ef4b0e40cf74b1bbe3b97b5d36ee79a2e42b9e7eadb9240afe92a2fc2fc7b5b`. The Node runtime is `/opt/homebrew/Cellar/node/26.7.0/bin/node`, SHA256 `1ef99ea25fe70c9b67e7efe768ef8ee22148d3cabc703db6131b57aeb617d040`. Addon and model digests remain the pinned values above.

The following own-code identities were recorded for these runs. Paths are relative to `app/native-model-probe`.

| Artifact | SHA256 |
| --- | --- |
| `build/installed-worker-probe` | `fa1ba7a07f3191a7d19a8e13b0762df4b1f62e1c30a237f1b85e10579aa70c41` |
| `installed_worker_probe.cpp` | `279c22af7002ce6b948201094eebd12e90620eb0f8a9212a25f8a9a1045e14cd` |
| `installed_worker_launch.hpp` | `0dcae60860d0d87acd64e046e4a5db5f96dd8f45e1c6e2a72e12f77accea4832` |
| `worker_broker.hpp` | `5fe88279133265f1f3e504a835859d0e4e3712c5fd30983214cc108d48ea2c09` |
| `worker_broker.cpp` | `91c438fd3dd48dfa5556783d4fe9f3bcca20849089a8053c76ddb1d67f61e054` |
| `audio_worker.cjs` | `08a475a7cead72d44a6e027eb06423c4479034e7c465a021d9a529bf764cbceb` |
| `worker_session.cjs` | `3071ac60f848f3109f8f608eea57a82feaeb3eb02d2ce36fa276f250ffcf8888` |
| `worker_protocol.cjs` | `2d9f55e44af128f36216f7206f4235f4020c9b0fb45eabfebd2e6a56a8c32adc` |
| `worker_protocol.hpp` | `ae539679aef1fc12d56da20ba2affc8ecaa3222aa12a1ddeec402fdef9d94226` |
| `native_probe.cpp` | `f484a163df812979459acd558beadca876c7b53aa491cefe346dbef87ec3992c` |
| `abi_factory.hpp` | `dd8154707024d253312f6542fe874a170fa7562691b30a3e7c34ec8e1a06964f` |
| `abi_supplier.hpp` | `dbbd7c0f8b26e854b66b1ea78cb75d8d54a4977b0c05a5a208001286fff3a3bb` |
| `abi_result.hpp` | `7c31440ec799ae1bcbf08fef6df00de818fe1b22acdd922402de3a0f2a309572` |
| `result_collector.hpp` | `d2f12eacdbfd05d4a6e33dd67c82bdfc34be756b68cf7136fe3eb879ad44bcc9` |
| `build/native-probe.node` | `4b53c9f15842680c3e6517a5df23cbcfff3c977781202da1ab7d31b2e22046c1` |

The NC REA cleanup error named live candidate PID 2051 with an unreadable environment ownership token, so REA did not verify owned-process-group cleanup and retained its temporary root. A later read-only process query found no such PID, but that does not restore the missing ownership proof. The partial capture still records parent exit 0 and successful processing/publication. The broker's own close result establishes the direct worker's acknowledgement, EOF and reaped successful exit; it does not replace REA's broader cleanup proof. The bypass capture lists one unrelated process with `platform_binary_environment_withheld`, left untouched. No process was killed manually.

Scenario JSON, result envelopes and output files use the run names above under `evidence/model-probes/`. The NC result envelope SHA256 is `01e4717aa17f6ce5c768990e7e2feec8a57d37047097d097ccacc652700259e5`; bypass is `bc27aa1b5e9884da39713757e3ee1fad1e702ca0f7e8f00c6d236804a130dc4b`. Full host-only verification passed before these captures with no concurrent builds. Its log is `evidence/supervised-worker-verify-20261017.log`, SHA256 `f0d275655817140d47dd3d16073b933bbc4511b012fdf2b88dfbe3df5d3e2b1a`.

These measurements establish bounded synthetic processing through the native broker and isolated worker, with preserved fixture output. They do not establish real-time scheduling, speech quality, tail preservation or live routing. Startup digest checks sample files before loading; reopening paths does not provide an atomic binding between sampled bytes and loaded images. REA samples process trees and filesystem states and does not trace network syscalls. The broker supervises its direct child and assumes sole waitpid ownership. Normal EOF can close the worker, but abrupt parent death while the worker remains permanently inside a hung native call can leave that worker alive. This parent-death case remains unresolved.


## Paced provider and native parent-watch results

A later build on 2026-10-17 adds a native parent-loss guard before vendor loading. The builder passes the broker's PID through the exec chain. Native code checks that it is still the current parent, then a separate thread checks getppid every 25 ms. Parent loss calls _exit(72) in the worker itself, even when its main thread is blocked in native processing. It never signals another PID. Normal stop wakes and joins the guard after session cleanup. Release and ASan/UBSan host fixtures cover graceful parent exit, SIGKILL parent loss with a blocked child main thread, invalid parent values, and repeated stop. This addresses the prior build's parent-death gap for a worker whose guard thread can still run. The polling interval is not a hard exit deadline; scheduling or a whole-process suspension can delay it. Abrupt exit reclaims OS resources and does not perform C++ or vendor teardown. These installed-model captures do not deliberately kill a parent.

Two new REA captures ran `timed-worker-probe` through ProviderWorker and its broker thread with the final guarded adapter. Each paced 112 CPU callbacks at nominal 10 ms intervals: 100 deterministic input frames followed by 12 zero frames. Each exchange uses the fixed transport queue; pipe IO and inference stay on the broker thread. The probe checked the initial 5,760 transport-delay samples were silent, then removed exactly those samples and retained the next 48,000. It drained all 112 model requests and required confirmed worker shutdown before exclusive publication.

| Run | Evidence ID | Maximum exchange duration | Maximum scheduling lateness | Result |
| --- | --- | ---: | ---: | --- |
| `timed-worker-nc-20261017-v1` | `ev_1e069d57847168a68cb3c388899494a69908eba65b1a2f2803a96984d72c94da` | 10 us | 2,478 us | Exit 0, 112 processed frames, zero transport deadline failures, teardown confirmed |
| `timed-worker-bypass-20261017-v1` | `ev_aaddd212cf3baed2368d6b1626a14238711366740a68edcc61ec0ba09220a321` | 281 us | 11,444 us | Exit 0, 112 processed frames, zero transport deadline failures, teardown confirmed |

Both aligned outputs contain 192,000 bytes and match the corresponding retained direct-v1 output byte for byte. NC output SHA256 is `fd389eb36788f4e2f707d63e987fd9205ff6dc1323ef94cd1ab3600960077290`; bypass is `d65f14f3868eccb927bd4da5b9a2ae2bc61755e29ae08e432cb3129f67c4f671`. The input remains `6ef4b0e40cf74b1bbe3b97b5d36ee79a2e42b9e7eadb9240afe92a2fc2fc7b5b`. The selected Node remains `1ef99ea25fe70c9b67e7efe768ef8ee22148d3cabc703db6131b57aeb617d040`; addon/model identities remain pinned as above. There were no concurrent builds during these sequential captures.

Both REA captures are complete, with verified owned-process-group cleanup and removed temporary roots. NC lists three unrelated processes with `platform_binary_environment_withheld`; bypass lists one. REA left them untouched. Sampled process attribution, inherited capture environment and absent syscall/network tracing limits still apply. Result envelope SHA256 is `59dc45ce68e0a3b9c95f309f11e59b2fd649a81e2fea2a6e23da211862e7ff71` for NC and `8d5c53b5b1501d0c841b9636d7718e6507b411a1120931de5ae05f42e92b47c2` for bypass. Scenarios, envelopes and private output files are retained under `evidence/model-probes/` with the run names above.

The final build identities are recorded below, relative to `app/native-model-probe`.

| Artifact | SHA256 |
| --- | --- |
| `build/timed-worker-probe` | `5e8ababc20b29d64f9ddf8a7989d9b1a654ae1393dabc649e2018d2433b0b127` |
| `timed_worker_probe.cpp` | `6952ed9ca6e8bb60bbaa5aad7a9995377f1de390cd2c65df5f4dd8a64c402b8b` |
| `build/native-probe.node` | `adfc9cf06066bafc58bfdc9a6fb08eb99ea08f42ce215912865c80de40a80552` |
| `native_probe.cpp` | `57569a2751b8e7e9bdf84c689acefe12d13fc28282828e8a09ab622771fa23cb` |
| `parent_watch.hpp` | `e0fa1322d70384a494a944a64e351a8366938f2df1e8e1e85b3dbfacdc6d983b` |
| `audio_worker.cjs` | `65007442983c3ac03f2a6efe27f77ace71f5cd67879c3a7e90bbde70f2c6e424` |
| `installed_worker_launch.hpp` | `bf85ec420bed8b43b030f0989287b79ed740063cf1ef77adfe27ad70e59a27fa` |
| `provider_worker.hpp` | `51fd5a2fdbaafbf0b01f1bcf50194072ae980b547aed51733e9d103be2fe0836` |
| `provider_transport.hpp` | `cfae8bcacee8d7f144522231398b50bbdad199fbdc10a208a6b81e22bfc87bfa` |
| `worker_broker.hpp` | `5fe88279133265f1f3e504a835859d0e4e3712c5fd30983214cc108d48ea2c09` |
| `worker_broker.cpp` | `91c438fd3dd48dfa5556783d4fe9f3bcca20849089a8053c76ddb1d67f61e054` |
| `worker_protocol.hpp` | `ae539679aef1fc12d56da20ba2affc8ecaa3222aa12a1ddeec402fdef9d94226` |
| `worker_protocol.cjs` | `2d9f55e44af128f36216f7206f4235f4020c9b0fb45eabfebd2e6a56a8c32adc` |
| `worker_session.cjs` | `3071ac60f848f3109f8f608eea57a82feaeb3eb02d2ce36fa276f250ffcf8888` |

Full verification passed before these runs. `evidence/parent-watch-timed-build-verify-20261017.log` has SHA256 `86d16e88d656ef1368cc20ba936a0f0e5938c4bbc09a90a65d350f6a7e762fc5`.

This is a paced CPU simulation, with no hardware audio callback or routing path. The bypass scheduling lateness exceeded one nominal callback interval, despite zero transport deadline failures in this short run. These observed maxima are not scheduling bounds. The explicit transport buffer adds 120 ms; removing that known delay for file comparison does not make it accepted product latency, remove model latency, establish speech quality, or prove complete model-tail preservation. The extra zero input is only sufficient here to extract the known transport-delay window. Startup identity checks remain pre-load file hashes rather than an atomic binding to loaded images.
