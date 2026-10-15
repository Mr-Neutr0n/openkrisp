# Local troubleshooting and report export

Current catalog Evidence `ev_58c2d2c98cd0dc8a434233efa30e9e4448d97ecb7441ea8fc36caaa79099b6f4` explicitly names local debug-log export, destination selection, optional system information and a sample recording, issue/date/description inputs, and separate remote report submission. It does not recover a report schema, default options, log contents or collection rules. JSON reports or diagnostic bundles in OpenKrisp are independent formats, not original compatibility.

The catalog is bound to the retained Krisp 3.17.9 checkpoint, version Evidence `ev_3a54568811b26cf5484325645d4ec772d8a425f658baf6e523ffd035b522b820`; its REA subject executable SHA-256 is `2af082b5bb26e71a540d08d200d56e12993fc50395b1d7d2ea989e38963c373d`. Labels do not prove reachability or actual collection. No original UI, runtime, logs, recordings, system settings or permissions were read or changed for this report beyond retained REA evidence.

## Observed local export controls

All exact text below comes from the current catalog Evidence above.

| Keys | Relevant exact text | What this supports |
| --- | --- | --- |
| `nav_btn_get_debug_logs`, `context_menu_get_debug_logs`, `report_problem.btn_get_debug_logs` | Get debug logs | Entry/action labels exist. Exact menu reachability is not exercised. |
| `report_problem.select_log_save_path` | Select destination where you want to export logs | Destination selection for local export is explicit. File versus directory output remains unknown. |
| `report_problem.browse_for_folder` | Browse For Folder | A folder browse control is named in this diagnostic context, distinct from the session-library picker. |
| `report_problem.saving_logs_text` | Saving debug logs locally... | A local saving/progress state is described. |
| `report_problem.logs_saved_text` | Your logs are saved in | A result-location message exists. It does not prove opening/revealing the result automatically. |
| `report_problem.download_logs`, `get_log_manually` | Download logs; Get logs | Retrieval affordances exist. “Download” alone does not establish a network requirement. |
| `report_problem.sign_out_state_text` | Download debug logs and contact Support for assistance. | Log retrieval is described even in signed-out troubleshooting. Remote Support contact is separate. |
| `report_problem.include_system_information`, `include_system_information_logout` | Include system information for debugging | System-information inclusion is an option. Default, exact fields, permission requirements and signed-in/out differences are unknown. |
| `report_problem.include_recordings` | Include the sample recording in the report | Sample inclusion is named. Source selection, whether it means a user-selected file, automatic attachment, length, format and default are unresolved. |
| `report_problem.select_the_date`, `text_now` | Please select the date when the issue occurred; Now | An issue date/time context exists. A date filter over logs, precision, timezone and default are not established. |
| `report_problem.describe_the_problem`, `placeholder_describe_problem` | Describe the problem; Please be as detailed as possible. Tell us what you did to arrive at the problem. | User-authored description is part of the troubleshooting UI. Requiredness and maximum length are unknown. |
| `report_problem.file_can_not_be_found`, `invalid_format`, `text_smt_went_wrong` | File cannot be found; Invalid format; Something went wrong | Generic error vocabulary exists. Exact local-export error mapping is not recovered. |

## Observed issue categories

Category headings and issue labels support a taxonomy, not a verified hierarchy or capability implementation. An issue about an unimplemented engine may still be report metadata; it must not claim that engine runs.

| Family | Exact supporting keys and representative wording |
| --- | --- |
| Audio quality and routing | `audio_quality`: “Having issues with Audio quality”; `others_can_not_hear_me`; `can_not_hear_others`; `my_voice_breaking`; `my_voice_lagging`; `others_state_my_voice_robotic`; `others_state_my_audio_volume_is_low` |
| Noise, nearby voices and headset | `having_issue_with_bvc`; `bv_are_not_canceling`; `bv_human_voice_not_canceling`; `some_specific_noise`; `my_voice_is_canceled`; `bvc_not_compatible_headset`; `unable_to_turn_nc_toggle_on` |
| Echo | `echo_is_not_canceling`: “Echo is not cancelling and being heard”; `hear_my_echo`: “I hear echo or I can hear myself” |
| Setup and device visibility | `issue_with_setup`; `do_not_see_krisp_device_in_calling_app`; `do_not_see_krisp_device_in_krisp_app`; `widget_is_not_responding` |
| Performance and stability | `system_performance_issue`; `high_cpu_usage`; `high_memory_usage`; `crashing_or_freezing`; `getting_error` |
| Accent and Voice Translation | `having_issue_with_accent`; `accent_not_working`; `accent_still_strong_accent`; `accent_difficulty_in_understanding`; `accent_lagging_voice`; `accent_robotic_voice`; `accent_strange_voices`; `test_voice_interpreter_issue` |
| Installation and updates | `issue_with_updating_or_uninstalling`; `receive_error_while_update`; `receive_error_while_uninstalling` |
| Test and uncategorized issues | `test_nc_issue`; `other`; `not_in_the_list`; `select_issue_title`; `select_one_of_categories`; `select_from_list` |

All keys in this table are under `report_problem.`. “Robotic voice” is a local audio artifact, not evidence of a cloud bot. Free-minute-renewal reporting (`minutes_are_not_renewed`) belongs to removed account/quota support and need not be carried into independent local diagnostics.

## Explicit exclusions and unresolved collection boundaries

Remote submission is explicit: `btn_send_report`/`send_report`, `report_process_pending`, `report_process_success_text` (“Our team will have a look at your report.”), `report_process_fail_text`, and `could_not_upload_file`. Submission/privacy/participant-consent wording describes sharing with the vendor. OpenKrisp excludes that service, upload, analytics and remote event reporting. A local export must not silently submit or contact Support.

`add_attachment`, `upload_or_drop_file`, and `allowed_file_formats_for_attachment` list image/audio/video/text/log formats. The five-file and 100 MB messages explicitly describe uploads. They are not established local-export constraints and are not independent usage quotas. Any practical file-size/memory bound in an independent exporter must be explained as its own technical constraint.

Active network collection is separately named: `include_network_diagnostics`, `run_and_include_network_diagnostics` (“Run and include network diagnostics (~10 sec)”), `network_diagnostics.title`, `recorder.recording_network_log`/`stop_recording_network_log`, and `app_menu_help.generate_har`/`stop_har`. Their transport, captured data and privacy behavior are not recovered. Do not silently run network probes, capture HAR traffic, collect cookies/credentials or integrate vendor telemetry. Exporting a bounded local failure/state snapshot is distinct from reproducing active network diagnostics.

Historical partial JavaScript Evidence `ev_a171e77e361a92e3a14ece5a0d849dd226d5669aaa7a8dbc9bafd807200e54ca`, ASAR SHA-256 `fbd6a39ce6fde8685c6ca4c2ca78343aa50551b1bac74f532fd6c5801a23b622`, exports names `getCrashFilePath` and `getDriverAppLogPath`; wrapper reads include `GetCpuArch`, `GetHardwareInfo`, `FetchKrispDriverVersion`, `RegisterTroubleshootingNotifications`, `UnregisterTroubleshootingNotifications`, and logger methods. These names corroborate diagnostic boundaries only. They do not establish current log files, option defaults, report payload fields, collection permission or current invocation. Vendor crash-path helpers do not justify reading or redistributing vendor/user logs in the independent app.

## Independent implementation acceptance

Observed labels support an explicit local export workflow with issue/date/description metadata and optional system-information/sample inclusion. The independent implementation must define its own artifact format, destination/exclusive-write policy, bounded app-owned diagnostic fields, attachment consent, progress/cancellation and error states. Label its contents accurately: a current-state JSON report is not historical debug logs or a verified original report format. Treat the selected issue date as user metadata unless an actual log filter is implemented.

System-information and sample options must state what they include. Do not infer checked defaults, scan recordings automatically or collect unrelated device/user data. Explicitly selected samples can be handled as an independent attachment choice after validation; actual original attachment source remains unknown. Do not represent sample export as preserving the temporary NC-test “won’t be saved” promise without an explicit user save/share choice.

Remaining original unknowns: export directory/archive layout; compression/encryption; actual log source/retention/redaction; report schema and field limits; system fields/defaults; sample source/copying; date-to-log selection; local error/retry behavior; cancellation atomicity; whether partial output is removed or retained; offline availability; default menu visibility. No new original runtime or system action was performed.
