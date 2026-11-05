# Installed accent model execution

Both exact installed AR models now execute through the separate
`app/accent-engine` adapter and sandboxed worker. Ten-second file-only speech
tests pass for outbound and inbound. The output is finite, has speech-scale
energy, differs from the input and has no clipped samples. The original
catalog declares `us` as the target for both models. These results establish
local model execution and the recovered streaming contract. They do not
establish human accent quality, a complete original desktop pipeline or live
call acceptance.

The earlier Samantha and Rishi model-execution probes used no microphone,
audio device, playback, driver installation, account, remote service or
administrator operation. The later ElevenLabs source generation uses an
authorized remote TTS request with fixed text. Its AR conversion remains
local inside the deny-network worker. Every new original-artifact read and
execution ran through REA. Audio, original files, captures and analysis
scripts remain private outside the product repository.

## Bound artifacts and original mapping

The current original ASAR is
`40269da405babcd79c18780715c63625d0bb7035f03a480b1732fe067ba911b4`.
The native ARM64 addon is
`adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755`.
The current catalog reads, without executing its JavaScript:

| Catalog role | Exact external filename | Literal accent selector | Literal output | SHA256 |
| --- | --- | --- | --- | --- |
| `ar-outbound-wb-c` | `ar_outbound_wb_c_ma_3.11.0_1.0.kef` | `any` | `us` | `8ada1e4c3d2b3ef3c1440e39dfdfb825c7b0a4c0695c9e0ba6b06b576f124855` |
| `ar-inbound-wb-c` | `ar_inbound_wb_c_3.12.0_1.0.kef` | `inbound` | `us` | `73a59147ba88d0075e6a688f3cc641c5a46a6ffbb591c2f386b3affdb3e781df` |

Both entries have configured type 6. The mapping comes from decoded literal
catalog entries in the current archive, not model-filename interpretation.
`inbound` is retained as the original selector label, not a language claim.
This pass did not establish every original variant, user eligibility,
download decision, headset restriction or currently active desktop setting.
The local use of installed files does not establish redistribution rights.
The product contains neither model nor vendor binary.

## Native contract

The selected direct float factory at `0x485448` returns an owning libc++
shared pointer through the ARM64 indirect-result register. Its arguments are
SDK configuration, immutable stream descriptor, AR configuration, shared
AR supplier and shared const-result handler. It is a separate AR template.
Ordinary NC role admission and NC consumer types are unchanged.

The eight-byte descriptor is two signed 32-bit values: duration in milliseconds
and sample rate. The new adapter admits only 10 ms, 48 kHz mono Float32,
with exactly 480 samples per native call. The AR constructor stores the
descriptor address, so the session retains it through processor destruction.
`updateStreamDescriptor` is a no-op on this selected implementation.

The observed 56-byte AR configuration has sampling rate at `+0x00`, an owning
libc++ wide string at `+0x08`, model data pointer and length at `+0x20/+0x28`,
ringtone-enabled byte at `+0x30`, and ringtone threshold float at `+0x34`.
The adapter uses the exact external path, zero model data pointer/length,
ringtone disabled and threshold zero. That matches the wrapper's reviewed
default threshold path.

The original wrapper defaults noise suppression to 100 and accepts zero
through 100. Its outer supplier returns bytes `0,1` followed by zero bytes
and the level float. An intermediate wrapper replaces byte two with a KMS
stream flag. The selected AR process reads bit 8, bit 0 and the high-word
float using three supplier calls. The independent supplier is immutable,
returns `0,1,0,0,100.0f`, and has its own AR declaration. No other flag meaning
is invented. The selected direct processing path does not read byte two.

The direct AR factory forwards the SDK configuration argument into AR
construction. The reviewed constructor only forwards it to embedded BVC
initialization and ringtone initialization. With ringtone disabled, that
second branch returns before touching it. Embedded BVC forwards it to the
previously verified ordinary NC factory, whose selected body does not read
the argument. Only this bounded configuration uses the adapter's unused
address token. It is not a constructed SDK object or a claim that all SDK
paths ignore configuration. The AR model supplies its embedded BVC data.

`ProcessorView` destruction slots precede `flush`, `finalize`, `process` and
descriptor update. On the reviewed digest, flush and finalize resolve to
the same no-op body. The direct process accepts a const vector and can emit
zero or one callback. Before its output ring has one full frame, it can
return with no callback. Each present callback has one descriptor-sized
vector at result offset `+0x28`, inside a 64-byte borrowed const `FrameInfo`.
The adapter copies samples during the callback and never owns that value.

The session retains configuration, descriptor, callback owners and image
while the vendor processor exists. It releases the returned shared pointer,
then callback owners, then unloads the image. Foreign exception objects are
destroyed before unloading their code image. Invalid samples, wrong or
duplicate callbacks, unexpected callbacks outside processing, native failures
and unconfirmed teardown terminate the session. Owned fixtures test these
contracts before any original invocation.

## Offline speech measurements

The first successful control used the existing authorized local Samantha
speech fixture, 480,000 samples at 48 kHz. It returned 479,520 samples through
999 callbacks. Construction took 276 ms and the complete operation took
about one second. This proved a callable AR path before the second fixture.

The second fixture uses macOS `say`, Rishi, English India, rate 155, written
to a file without playback. Its complete 8.132-second utterance says:
"Hello, this is a quick sales call. Our software helps your team work together.
Could we schedule a meeting for tomorrow afternoon?" The file was resampled
to mono 48 kHz and padded to exactly ten seconds. Its Float32 SHA256 is
`3f4f091849f8dcc48613f471ac2060cfbb8c9f46b3a88c9839cc183b46dcecbc`.

The following results use the complete production-shaped C++ broker,
sanitized environment, deny-network sandbox, AR worker, native adapter and
exact installed model. Every input request has a matching result or explicit
empty reply. The worker verifies artifact identities before model loading
and after native teardown.

| Measurement | Outbound | Inbound |
| --- | ---: | ---: |
| Input frames, 480 samples each | 1,000 | 1,000 |
| Empty startup reply | Sequence 0 | Sequence 0 |
| Model output frames | 999 | 999 |
| Raw output samples | 479,520 | 479,520 |
| Raw output duration | 9.99 s | 9.99 s |
| Output RMS | 0.09290 | 0.09116 |
| Output absolute peak | 0.70454 | 0.63084 |
| Clipped samples, absolute value at least 1 | 0 | 0 |
| Broker readiness time | 387 ms | 262 ms |
| Processing time for ten-second input | 1,129 ms | 1,218 ms |
| Confirmed teardown and process exit | Yes, 0 | Yes, 0 |

The input RMS is 0.13165 and its absolute peak is 0.88816. The outbound raw
output SHA256 is `74bf037242725c389f41a28c6a04a9bc43ce910557e1a951c6cba6ddb9c350b7`.
The inbound output SHA256 is `12f5f244de667886e4411558a2921fd5f0f2e7ab1c3ba561951e04db00d780d7`.
Their distinct outputs and changed waveform establish nonidentity inference.
They do not measure intelligibility or accent quality. The outbound direct-session and C++ broker runs returned byte-identical output on this fixture, so the broker preserved the observed native samples.

For a separate timing analysis, one 480-sample zero frame replaces the
explicit empty reply on an analysis-only fixed timeline. Raw saved model
output remains unpadded. A 10 ms RMS-envelope correlation search peaks at
21 frames, about 210 ms, for both directions. Correlation is 0.930 outbound
and 0.946 inbound. A known seven-frame synthetic shift verifies the lag
calculation. This sample-dependent envelope proxy is distinct from the
10 ms first-callback delay, host scheduling buffers and algorithmic latency.
No fixed compensation or exact delay contract is claimed.

## ElevenLabs fixed-script source

After the Rishi test, one authorized ElevenLabs request generated a different
source for listening. The request sent only a 195-character non-sensitive
sales script. It did not upload a microphone recording or any user audio.
The selected account voice is Raj - Professional Indian English,
`wJ5MX7uuKXZwFqGdWM4N`. Saved metadata labels it English, Indian, male and
conversational, with verified locale `en-IN` for `eleven_v4`. The available
model metadata marks v4 as TTS-capable with English and no alpha requirement.
Settings were stability 0.5, similarity boost 0.75 and `language_code: en`,
using the [official synthesis endpoint](https://elevenlabs.io/docs/api-reference/text-to-speech/convert).
Exactly one generation request succeeded and reported a character cost of
195. No purchase, model training, voice creation or automatic retry occurred.

The returned mono 44.1 kHz MP3 decodes to 10.4 seconds. The complete source
was resampled to mono 48 kHz Float32, then extended with trailing silence to
15 seconds. The input SHA256 is
`b1927ed0605c81887c58898626800016a37f3a1d42241770ae7059e25f563642`.
No speech was cut, time-stretched or gain-normalized. The same frozen adapter
`ae9cce3336f44c03de752d15554635c039e47692488469784e7ddedab2e105f1`
and exact external outbound model ran under REA through the complete broker
and worker.

| Measurement | Result |
| --- | ---: |
| Input frames | 1,500 |
| Explicit empty startup reply | Sequence 0 |
| Native output frames | 1,499 |
| Raw output samples / duration | 719,520 / 14.99 s |
| Output RMS / absolute peak | 0.07703 / 0.74514 |
| Clipped samples | 0 |
| Broker readiness / processing time | 310 ms / 1,476 ms |
| Teardown and process exit | Confirmed / 0 |

REA `ev_7701dc33ee8b66f6375caf44c86543af42af0fb7887fb2ddff94b8e2a0b03220`
retains all raw terminal bytes, verifies owned process-group cleanup and
removes the temporary root. An unrelated platform process had withheld
environment attribution. This limit is retained. The 10 ms RMS-envelope
analysis again peaks near 210 ms lag, correlation 0.911. It remains a
sample-dependent proxy, not a fixed latency contract or an accent-quality
score.

The private directory `../evidence/model-probes/elevenlabs-accent-20261105/`
contains the API voice/model metadata, generation settings and response
metadata, original MP3/WAV, padded input, raw output, converted listening WAV,
owned finite probe source/binary, REA scenario/result and metrics. Credential
values were read only in memory and were not written into those files. The
metrics file SHA256 is
`cc27d2af779a0c3b15d5b24f8d81a49ed6a7a68ba827875c95d213eea41702cd`.
The source metadata and nonidentity inference do not certify that this
sample sounds better, preserves identity or reaches the declared US accent.
Those judgments need human listening. No playback or real call was performed.
The generated audio remains private.

## Worker and host integration

The separate C++ API and exact readiness identity are documented in
[app/accent-engine/README.md](app/accent-engine/README.md).
`WorkerBroker::process480` reports `produced=false` for an explicit model-empty
reply. It never labels host-inserted silence as a converted model frame.
The host must report its own startup scheduling buffer and keep stale
asynchronous configuration rejection. No broker operation belongs on an
audio callback.

The wire uses distinct `OKAR` magic, not the NC wire. Readiness includes
direction, the declared `us` target, rate, frame size and addon/model/adapter/
Node hashes. The current native adapter used in the accepted probes is
`ae9cce3336f44c03de752d15554635c039e47692488469784e7ddedab2e105f1`.
The reviewed Node executable is
`1ef99ea25fe70c9b67e7efe768ef8ee22148d3cabc703db6131b57aeb617d040`.

There is no recovered EOF drain or model-tail contract. Closing destroys
the model without automatic zero submissions or delayed output recovery.
Finite test padding and live scheduling padding must be recorded separately.
Live HAL, desktop admission, mutually exclusive microphone routing and a
real call sample are separate integration acceptance steps.

## Evidence and preserved failures

Captures are retained privately under
`../evidence/model-probes/nc-speech-comparison-20261105/`.

| Capture | REA Evidence |
| --- | --- |
| Original AR catalog role and declared target mapping | `ev_1ff9926dfea6973889b4c1e261378f75e5b8e969d8a977fb732a93ba0dbf42ff` |
| Original wrapper defaults and validation | `ev_5f43586d77652f063abafdf660fe46d92a7851b9506a5e7b692fad98f319cbc8` |
| Factory, constructor, direct process and destruction | `ev_5606436fb0a63321efdc069a96f8835550642e78c942c749d2e562dea28f99ed` |
| Embedded BVC and ringtone preparation | `ev_d9be873ad2edd5d6f121a2e04b4780e7b7799188adeeb7433f8275fddc68396d` |
| Concrete AR vtable words | `ev_ba2843184f8d687bbad198de1b62ecc773faba876c7218e88bce3feb7dfd7392` |
| First outbound speech inference | `ev_7bc7c790e6e36837df7c3daad2ec316afff3ed30827e78229b421ca41a0b7745` |
| Rishi outbound direct persistent session | `ev_e58f41a87d88d87107bf72de7f285ce905be73985b4276eb1b50f3a5dfb76bda` |
| Rishi outbound complete C++ broker/worker | `ev_74788d7e089aec201ae4b0c2e6b85bbffd1b8e93d75a606742070d0108b4db61` |
| Rishi inbound complete C++ broker/worker | `ev_f9332ac19df943e8fdc903ec93e48f2b841ab867b33c637173561cc30e77508f` |

Accepted runtime captures exited 0, retained all raw terminal bytes and
verified owned process-group cleanup and temporary-root removal. Some
captures also list unrelated platform processes whose environment REA could
not inspect. This is a process-attribution limit, not evidence about those
processes' ownership. Sampling can miss short-lived descendants and file
hashing before native path reopening is not atomic image binding. Selected
library-directory dependencies were not independently identity-pinned here.

The initial outbound attempt, `accent-outbound-clean-v1`, exited 1 because
`libmp3lame.dylib` was not on its loader path. Evidence
`ev_d0af225bc9ab07d06759a1dca83c3af2cb0dab4692d4df9b4b2b0d4237207a6c`
is preserved. The next scenario uses the same explicit local library
directory policy as the existing NC worker. No dependency was downloaded.

The first Rishi attempt, `accent-outbound-rishi-v1`, exited 1 before loading
the model because the generated file did not contain whole 480-sample frames.
Evidence `ev_25b8c23330be4de0108c0937baba33c849b8ab30fff31fc619f5bbe18ee5ff68`
is preserved. The corrected fixture is a separate file with a new digest and
keeps the complete utterance.

`accent-inbound-rishi-v1.result.json` is a retained REA `cleanup_incomplete`
error. Its partial observation reports completed processing, but REA could
not read an ownership environment for a live candidate and retained its
temporary root. It is not an accepted inbound runtime proof. The later
separate C++ broker capture above supplies the accepted inbound result.
Historical PIDs from that error must not be reused as live process handles.

## Verification and remaining work

`app/accent-engine/verify` passes against owned fixtures. It checks delayed
startup, copied callback buffers, persistent state, wrong or nonfinite
callbacks, invalid inputs and receivers, destructor callbacks, foreign
exception lifetime, garbage collection, role/hash admission, fragmented wire
messages, explicit empty replies, malformed packets, sequence errors,
startup/frame/close timeouts, crashes, trailing output and child reaping.
Wire and broker cases pass release and AddressSanitizer/UndefinedBehaviorSanitizer.
The model catalog now records both current AR hashes, and its release build
passes. Local Command Line Tools still lack XCTest, so its updated Swift
test was not run here.

Remaining acceptance includes live route integration, default-off UI and
clear provider admission, speech listening by a person, real microphone and
call samples, source/target variant coverage, sustained CPU/deadline behavior,
headset restrictions, tail behavior and comparison with the full original
desktop workflow. Offline AR execution closes a concrete implementation gap;
it does not close the accent feature family or full retained-feature parity.
