# Recording recovery evidence and review scope

Retained REA evidence reviewed 2026-10-15. No original runtime, recordings, settings, devices or administration were accessed.

## Original observations

Current catalog Evidence `ev_58c2d2c98cd0dc8a434233efa30e9e4448d97ecb7441ea8fc36caaa79099b6f4` names local storage and save failures:

| Key | Exact text | Limit |
| --- | --- | --- |
| `local_store_info` | Your transcripts and recordings are saved directly to your device, and stay private to you. | No recovery format or discovery policy is specified. |
| `note_taker_storage.location_not_accessible` | Permission denied. The app can’t save files to the selected folder. | Retry, fallback and partial-save policy are unknown. |
| `note_taker_storage.location_not_available` | Selected folder doesn't exist. Please choose a valid folder on your device. | No implicit relocation or data move is established. |
| `error_storage_full` | You can't record.\nThe storage is full. | Local disk exhaustion versus account/cloud quota is not resolved by this label. |
| `note_taker_messages.meeting_saved` | Meeting successfully saved. | No durable-commit or finalization contract is specified. |
| `quit_confirmation_text` | Krisp is capturing a meeting. Would you like to save it before leaving?  | Explicit save-before-exit is described, not post-crash recovery. |
| `wait_for_quit_text` | Krisp will quit after saving. | Ordering is described; failure handling remains unknown. |
| `note_taker_saving` | The meeting is processing... | Processing is not proof of completed local save. |

No explicit recovery, unsaved-recording restoration, interrupted-file repair or corrupt-file recovery workflow was found in the retained current catalog leaves. This is a bounded catalog observation, not proof that runtime recovery is absent. Catalog labels belong to the retained 3.17.9 checkpoint, Info.plist Evidence `ev_3a54568811b26cf5484325645d4ec772d8a425f658baf6e523ffd035b522b820`.

Current native static evidence provides failure context, not a recovery algorithm. Device recorder lifecycle/start Evidence `ev_03e31793b114208efefd2e68567f4341ad706c16f1bd65c44fbcbcf7688f3102` and `ev_40ab92b005f05d1ca15e14b38419d9339ff5e6ebab8122c1c42d08f414ba06a7` checks unchanged NativeUtils SHA256 `17eb466b1092c37b0bbc8e04d4a29163a9fbef1a5e1e802be7c842dd59bc94ea`. It has encoder-open and write failures and releases encoder/device state on stop. Graph lifecycle Evidence `ev_f5df68333651c84d4ff750f1a8f2b785ca8eac0c0baf7a4d84c6353cc0cd9d53`, MediaSP SHA256 `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755`, closes FileRecorder media on stop and logs a nonzero close error. These static paths do not establish a finalized output after failure, restart discovery, source-file repair, product UI linkage or safe recovery of incomplete WAVs. See `recording-findings.md` and `storage-location-findings.md` for full limits.

## Independent acceptance boundary

The proposed recovery feature is an independent preservation workflow. It must describe copying an already finalized independent recording into the currently admitted library, not repairing arbitrary original or incomplete audio. Review will check explicit user action, strict finalized-media validation, unchanged source bytes, fixed owned staging locations rather than manifest-selected arbitrary paths, exclusion of active capture, destination/library revision binding, stale async result rejection and truthful failure/cleanup states. No copy, move, delete or import is authorized merely by discovering a candidate. Tests must use independent synthetic files; real recording and native UI acceptance remain separate.

Original recovery discovery locations, manifest schema, crash consistency, restart prompts, retention/deletion policy, save retries and incomplete-container salvage remain unknown. No implementation or ledger changes are included in this report.

## Independent source review checkpoint

Read-only review of the stable `RecordingRecovery.swift`, controller and view found no remaining material issue in the bounded copy workflow. Discovery uses only fixed independent staging files. Save revalidates private finalized 48 kHz stereo PCM16 WAV and metadata identity, snapshots without modifying the source, retains the destination LocalStore through publication, and rejects source or destination replacement. Temporary cleanup verifies owned directory identity; successful save plus cleanup warning is distinct from copy failure, and both unconfirmed-cleanup outcomes identify the temporary path. Controller confirmation binds the review generation and library revision, and shared capture/library leases exclude active capture and folder switching through asynchronous work. Invalid entries cannot be copied; repeated explicit copies create distinct sessions.

Backend reports nine focused synthetic filesystem tests passed. Controller reports four focused tests passed, including actual synthetic stage-to-backend-to-controller copy and history notification, stale confirmation and suspended operation admission. Worker reports final desktop `./verify` exit 0 with 86 tests plus signed release/resource checks, local log `app/desktop/.build/recovery-verify.log`. No partial-WAV salvage, LocalStore `.pending` recovery, original crash parity, native recovery UI or live audio was exercised or established.
