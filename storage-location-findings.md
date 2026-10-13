# Local storage location settings

Current catalog Evidence `ev_58c2d2c98cd0dc8a434233efa30e9e4448d97ecb7441ea8fc36caaa79099b6f4` describes choosing a folder for local meeting transcripts and recordings, separate missing-folder and permission-denied states, and a location setting locked during calls. It does **not** establish migration of existing data, reopening another library, path persistence or a default directory. No original UI or setting was changed for this report.

The current labels are version-bound to Krisp 3.17.9 plist Evidence `ev_3a54568811b26cf5484325645d4ec772d8a425f658baf6e523ffd035b522b820`. Current catalog subject executable SHA-256 is `2af082b5bb26e71a540d08d200d56e12993fc50395b1d7d2ea989e38963c373d`; this is the REA subject identity, not an invented catalog-file digest.

## Exact observed labels

All rows cite the current catalog Evidence above. Labels describe available wording, not verified button actions or error enforcement.

| Key | Exact text | Supported meaning |
| --- | --- | --- |
| `note_taker_storage.title` | Storage location | A storage-location preference exists. |
| `note_taker_storage.description` | Choose where to store your meeting transcripts and recordings: | The setting concerns both transcripts and recordings. |
| `note_taker_storage.local` | Local | A local-storage option is named. |
| `note_taker_storage.local_info` | Save transcripts and recordings locally on your device. On-device storage currently supports English only. | Local save and product-language limitation are described. English support does not imply an audio encoding restriction. |
| `note_taker_storage.select_location` | Select the location where you want to store your meeting transcripts and recordings | A location-selection prompt exists. |
| `note_taker_storage.browse_for_location` | Browse For Location | A browse affordance exists. Picker mode, allowed paths and folder creation are unknown. |
| `note_taker_storage.choose_new_location` | Choose a new location | Changing a selection is described. This is not evidence that old data is moved. |
| `note_taker_storage.location_not_accessible` | Permission denied. The app can’t save files to the selected folder. | Write-access failure has a specific message. Probe/write method and recovery are unknown. |
| `note_taker_storage.location_not_available` | Selected folder doesn't exist. Please choose a valid folder on your device. | Missing path is distinguished from inaccessible path. Automatic folder creation is not established. |
| `note_taker_storage.call_in_progress` | This setting is locked during calls. End your call to change storage location. | A call-time setting lock is described. Exact definition of call, detection source and unlock timing are unknown. |
| `note_taker_storage.not_available` | Not available | An unavailable state label exists. Its specific cause is unknown. |
| `local_store_info` | Your transcripts and recordings are saved directly to your device, and stay private to you. | Local save/privacy is promised. It does not establish schema, encryption, backup or filesystem permissions. |

The same namespace contains Cloud/cloud-info, Business-plan trial expiry and admin-enforced storage type text. Cloud storage is excluded from OpenKrisp. Trial, plan and admin availability restrictions are not carried into established local folder-selection functionality.

## Related failures and boundaries

`note_taker_tooltip.recording_storage_is_full` says recordings cannot be made due to full storage. `error_storage_full` and `storage_is_full` say recording is blocked when storage is full; `error_storage_action` says “Manage storage”. These labels do not identify local disk exhaustion versus a cloud/account quota. Treat genuine local filesystem capacity failures independently; do not invent a commercial quota or infer a numeric free-space threshold.

`screen_recording_local_info` says screen recording is unavailable with on-device storage. `record_with_bot.storage_info` says bot recordings stay in the cloud even when on-device storage is selected. These are separate product-boundary observations. They do not establish that choosing local storage moves previous cloud content or converts bot recordings into local files. No cloud migration is requested.

`report_problem.browse_for_folder` belongs to problem-report/log handling, not the note-taker storage picker. Its existence does not prove the library chooser's behavior.

## Retained runtime/static evidence limits

Earlier original Settings records `ev_6323f9d592b8916ba54f0c50ee6f3014b5a8772faa49e4bb57f7304d284e4997` and `ev_4192036d13441abb4bb312cc3cc8282d561ad361fc18aa67db630500a56ac87c`, retained in `evidence/ui-settings-open.json` and `ui-note-taker-settings.json`, are bound to earlier executable SHA-256 `6aa8f7c8df3a963d77507014aa29d07ce368acc3ed2df9d7d011d7ae12bfd3c3`. They are not a current folder-selection or migration trace. The inspected retained accessibility fields do not establish a successful storage-location change. Do not infer current reachability or an original default from those older records.

Historical partial JavaScript Evidence `ev_a171e77e361a92e3a14ece5a0d849dd226d5669aaa7a8dbc9bafd807200e54ca`, ASAR SHA-256 `fbd6a39ce6fde8685c6ca4c2ca78343aa50551b1bac74f532fd6c5801a23b622`, names browser `localStorage`, `sessionStorage.setItem`, `STORAGE_SET`, `STORAGE_REMOVE` and `RECORDING_STORAGE_ERROR_DISMISSED`. These names do not reveal the recording folder preference key or a disk-library relocation contract. Browser storage is not proof of meeting-file storage. Partial semantic coverage leaves original picker callbacks, path persistence and migration behavior unresolved.

## Unknowns and independent implementation choices

| Question | Original evidence status | Independent decision needed |
| --- | --- | --- |
| Selecting a new empty folder | Prompt/browse labels only | Define a dedicated library root or owned child directory and explicit admission errors. |
| Selecting a folder with existing sessions | No reopen/import/merge contract recovered | Decide whether to reopen a compatible independent library. Do not present it as original behavior or read vendor user data. |
| Existing sessions in the old location | No move/copy/rename/delete promise recovered | Keep old data unchanged unless a separate explicit migration action is chosen. Location selection alone must not imply silent migration. |
| Picker cancel or failed admission | No transaction/rollback contract recovered | Keep the active library and saved preference unchanged until a new root is validated and admitted. |
| Restart persistence | No preference format/key or bookmark behavior recovered | Choose independent path/bookmark persistence and report missing or inaccessible roots on restart without silent fallback. |
| In-flight capture/import/export/delete/playback | Call-time lock label only | Define an independent busy-operation lock that prevents switching the store under active work. It is not proof of original call-detection parity. |
| Permissions and private file modes | Permission-denied message only | Use the independent store's own private files/directories; state what the chooser can admit. Do not claim original mode/ownership constraints. |
| Missing/full/unmounted volume | Missing/inaccessible/full messages only | Distinguish local filesystem errors, preserve failed staging and make retry explicit. No automatic deletion or commercial quota. |
| Data compatibility | No original disk schema recovered | Reopen only the independent app's format; vendor-library compatibility remains absent. |

A choose-and-reopen workflow that preserves the old library is a reasonable independent design. It is not a recovered original migration mechanism. No original app launch, UI retry, audio, permission change, administration or network publication occurred during this investigation.
