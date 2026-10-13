# Catalog capability map

Source is REA Evidence `ev_ece7c942d90e27f063fd1be188d354a1a8d0f289e59aadea32bb6dc209566fa7`, saved in `evidence/translations.json`. The normalized English catalog contains 997 leaf keys. This report groups every key once. The JSON companion retains exact key membership.

Labels are observations. Local scope assignments are candidates. Reachability, defaults, persistence, behavior and enforcement remain unknown. The catalog does not show every runtime capability. It cannot establish the absence or full boundary of silent analytics, telemetry or crash reporting. Windows runtime errors and coming-soon accent choices occur in the Mac package.

## Limits that affect local parity

- Local storage is described as English-only. Transcripts are described as generated on the device.
- Screen recording is described as unavailable with on-device storage. Trace this boundary before promising local screen recording parity.
- Accent conversion names both microphone and speaker processing. Model preparation has an internet error. Offline availability needs separate evidence.
- Live in-person recording names a four-hour maximum and disables noise cancellation, accent conversion and talk time.
- Catalog text does not expose model weights, algorithms, media formats, timing, hotkeys or numeric defaults.

## Grouped inventory

### Candidate local functions

#### Local transcript and recording storage

19 keys. Folder selection, inaccessible or missing folders, local storage and storage-full errors are named. English-only support is a catalog statement, not a verified runtime limit.

- `note_taker_storage.local_info`: "Save transcripts and recordings locally on your device. On-device storage currently supports English only."
- `note_taker_storage.call_in_progress`: "This setting is locked during calls. End your call to change storage location."
- `note_taker_storage.location_not_accessible`: "Permission denied. The app can’t save files to the selected folder."
- `note_taker_storage.location_not_available`: "Selected folder doesn't exist. Please choose a valid folder on your device."

#### Local troubleshooting, logs and diagnostic errors

71 keys. The catalog names local log export and issue categories for routing, noise, echo, accent, volume, lag, CPU, memory and crashes. Network diagnostics need a local-only boundary.

- `app_menu_help.generate_har`: "Generate HAR file"
- `app_menu_help.stop_har`: "Stop generating HAR file"
- `app_menu_help.troubleshooting`: "Troubleshooting"

Native support: `ev_d5a7c268a91fe74d0e1be67ea708c3c5c726c11cb293ee43f1ef2a3bcbe401dd`. Native permissions, process control, recording and troubleshooting handler symbols.

#### Background voice cancellation and headset compatibility

25 keys. Nearby voice removal, headset detection and manual activation are named. Native DSP quality and actual device compatibility remain unknown.

- `bvc.only_work_with_headset`: "Background Voice Cancellation \nonly works with a headset."
- `bvc.turn_on_bvc_manually_for_unrecognized_devices`: "Turn on Background Voice \nCancellation manually for \nunrecognized devices."
- `bvc.make_sure_to_be_compatible`: "Make sure a headset is selected.\nUsing Background Voice Cancellation with other microphones may cause audio degradation."

Native support: `ev_82a288cac329f8c56c70b229dab17784b6f6ae35d0d61b7bde9ed4b7015715d1`. Native media graph, model, recording, ASR, diarization and translation handlers. Individual catalog paths are not proven to call these handlers.

#### Audio performance modes, load warnings and defaults

15 keys. Catalog names Auto, CPU Optimized and Best Noise Cancellation modes, system-load alerts and restore defaults. Numeric thresholds and default values are not established.

- `pref_auto_mode_sub_text`: "Adjusts Noise Cancellation mode to give the best experience for your conditions."
- `pref_cpu_optimized_sub_text`: "Provides good Noise Cancellation while saving battery and power."
- `pref_hd_voice_mode_sub_text`: "Provides the best Noise Cancellation. May consume more battery."
- `pref_audio_section_restore_btn_description_text`: "This will restore settings for optimal audio clarity."

#### Microphone and speaker mute and volume

25 keys. Volume lock, sync, call-start adjustment and mute controls are named. Native handlers corroborate control boundaries, not exact behavior.

- `pref_audio_section_volume_lock`: "Lock at optimal level"
- `pref_audio_section_volume_sync_with_krisp`: "Sync with Krisp"
- `pref_audio_section_krisp_mic_volume_sub_text`: "Automatically adjust microphone volume at call start."

Native support: `ev_4cf13e26f268ec8f71085eb3d490dee1e91b5efbc12dff8a3669ed551efa6ca4`. Native audio device, mute and volume N-API handler symbols.

#### Physical and virtual audio devices, app routing and setup

66 keys. Virtual microphone and speaker, physical device selection, unavailable or disabled devices, Bluetooth failures, app selection and exclusive-access warnings are named.

- `audio_block_mic_title`: "Krisp Microphone"
- `audio_block_spk_title`: "Krisp Speaker"
- `bluetooth_device_failed_reminder.description`: "Try reconnecting."

Native support: `ev_4cf13e26f268ec8f71085eb3d490dee1e91b5efbc12dff8a3669ed551efa6ca4`. Native audio device, mute and volume N-API handler symbols.

#### Mic and speaker noise cancellation and echo

37 keys. Catalog names inbound and outbound noise cancellation, echo-related warnings and call-state indicators. Native AEC symbols corroborate an echo boundary.

- `call_indicator.noise_cancelling`: "Canceling your noise..."
- `call_started_nc_off_1`: "Noise Cancellation is "
- `call_started_nc_off_2`: "Off"

Native support: `ev_82a288cac329f8c56c70b229dab17784b6f6ae35d0d61b7bde9ed4b7015715d1`. Native media graph, model, recording, ASR, diarization and translation handlers. Individual catalog paths are not proven to call these handlers.

Native support: `ev_f2e74c223103fdf553f18045b9e2493be2cb54ae62b7a47d5682c079f1206435`. AEC stream processing and WebRTC EchoCanceller3 symbols.

#### Audio test recording and comparison

26 keys. Catalog names at least a five-second sample, original versus processed playback, repeat recording and local unsaved samples.

- `test_nc.min_record_info`: "Record at least a 5-second sample to hear the difference."
- `test_nc.recording_will_not_leave_device`: "Your recording will never leave your device and won’t be saved."
- `test_nc.without_krisp`: "Without Krisp"
- `test_nc.with_krisp`: "With Krisp ✨"

#### macOS permission setup and degraded operation

12 keys. Microphone, others' audio, screen capture and Accessibility are named. Native permission handlers corroborate a boundary; actual prompts and fallback states require runtime evidence.

- `permissions_backdrop.mic_desc`: "Transcribe what you say and remove noises."
- `permissions_backdrop.app_calls_rec_desc`: "Transcribe what others say."
- `permissions_backdrop.accessibility_desc`: "Integrate and work well with meeting apps."

Native support: `ev_d5a7c268a91fe74d0e1be67ea708c3c5c726c11cb293ee43f1ef2a3bcbe401dd`. Native permissions, process control, recording and troubleshooting handler symbols.

#### Automatic activation, blocked apps and competing calls

43 keys. Automatic call activation, blocked apps, switch-between-call messages and start indicators are named. Detection rules, supported apps and defaults remain unknown.

- `pref_label_auto_activation_desc`: "Auto-start AI Note-taker with calling apps when a call begins."
- `pref_menu_blocked_apps_description`: "Krisp will not auto-start AI Note Taker when these apps are detected."
- `pref_label_auto_activation_toggle_off_tooltip`: "This setting is locked during calls. End your call to enable Automatic activation."

#### On-device transcription, language handling and speaker identification

45 keys. The catalog explicitly says transcripts are generated on the device. Search, save, history, pause, resume, English support, no-speech errors and speaker identification are named. Available ASR models remain unknown.

- `pref_info_call_transcript`: "Transcripts are private and generated on your device. "
- `identifying_speakers_text`: "Identifying the speakers, please wait..."
- `supports_english_language_text`: "Supports only English language"
- `asr_model_load_error`: "Note Taker couldn't start due to insufficient system memory. Please close unused applications to free up memory, then click"

Native support: `ev_82a288cac329f8c56c70b229dab17784b6f6ae35d0d61b7bde9ed4b7015715d1`. Native media graph, model, recording, ASR, diarization and translation handlers. Individual catalog paths are not proven to call these handlers.

#### Audio recording, live in-person notes and capture state

50 keys. Audio recording, transcript-only mode, live notes, mode switching, pause, finish and save are named. Live recording has a stated four-hour limit and disables noise cancellation, accent conversion and talk time.

- `in_person_recording.long_meeting_dialog.description`: "Krisp supports recordings of up to 4 hours. Your recording was saved successfully."
- `in_person_recording.nc_tooltip`: "Noise Cancellation is disabled\nduring Live Recording."
- `in_person_recording.ac_tooltip`: "Accent Conversion is disabled\nduring Live Recording."
- `in_person_recording.tt_tooltip`: "Talk Time is disabled\nduring Live Recording."

Native support: `ev_82a288cac329f8c56c70b229dab17784b6f6ae35d0d61b7bde9ed4b7015715d1`. Native media graph, model, recording, ASR, diarization and translation handlers. Individual catalog paths are not proven to call these handlers.

#### Participant notification and recording announcement

21 keys. Notification templates and consent reminders are named. Announcement timing and call-app integration remain unknown.

- `custom_notify_about_using_krisp_message_prefix`: "Krisp.ai: "
- `default_notify_about_using_krisp_text`: "Just a heads-up, I'm using Krisp.ai to transcribe and take notes in this meeting."
- `indicator_inform_participants`: "Inform participants"

#### Floating widget, captions toggle and meeting display

18 keys. Widget visibility, automatic show, hide for now, title/time display, talk time and speaking assistance are named. Talk-time calculation is not established.

- `pref_description_show_widget`: "Show Krisp widget at the start of each meeting."
- `widget_talk_time_tooltip`: "Time you have talked on this meeting"
- `pref_info_speaking_assistant`: "May use more CPU."

#### App menus, lifecycle, startup and window controls

52 keys. Preferences, menu commands, startup, sleep/wake, save-before-exit and relaunch states are named. Developer-tools labels may not be public runtime commands.

- `about_copy_right_text`: "© {{date}} Krisp Technologies, Inc. All right reserved."
- `app_menu_edit.title`: "Edit"
- `app_menu_file.file_upload`: "Upload a file"

Native support: `ev_d5a7c268a91fe74d0e1be67ea708c3c5c726c11cb293ee43f1ef2a3bcbe401dd`. Native permissions, process control, recording and troubleshooting handler symbols.

#### Notification controls and reminders

9 keys. Catalog names functional, call-health and setup notifications plus dismissal controls. Delivery path and defaults remain unknown.

- `call_health_warning_notifications`: "System"
- `pref_notifications_functional`: "Functional"
- `pref_notifications_on_off_indicator_body`: "Shows key features’ states at the start of each meeting and reminds to inform other participants if recording"

#### Common actions, settings labels and transient status

59 keys. Shared buttons, duration choices, status text and generic errors support the preceding groups. They are not independent capability claims.

- `12_hour`: "12 hours"
- `1_hour`: "1 hour"
- `30_mins`: "30 mins"

### Explicit exclusions

#### Accounts, licensing, plans and administrative policy

94 keys. Sign-in, seat allocation, daily limits, subscriptions and admin enforcement are outside the requested local reconstruction.

- `accent_conversion.main_ui.enforced_by_admin`: "This Accent Conversion\n option is disabled by admin."
- `accent_conversion.minutes_expired`: "Daily Accent Conversion\nminutes used up. Upgrade to\ncontinue."
- `account_switch_confirmation.description`: "You are about to sign in to a different Krisp account. This will log you out of your current account and switch to the new one."

#### Cloud storage, meeting bots and web dashboard

52 keys. Cloud storage, remote bot attendance and web dashboard access are explicit exclusions.

- `cloud_store_info`: "Your transcripts and recordings are securely stored in the cloud and accessible from any device."
- `record_with_bot.record_via_bot`: "Send Bot"
- `web_dashboard.offline_body`: "Oops! It looks like you're not connected. Check your connection and refresh to continue."

#### Report submission, feedback and external links

30 keys. Remote report submission, feedback and third-party links are excluded. Local log export has a separate group.

- `app_menu_help.contact_us`: "Contact us"
- `app_menu_help.give_feedback`: "Give Feedback"
- `app_menu_help.help_center`: "Open help center"

### Ambiguous dependencies

#### Calendar, agenda, meeting history and join reminders

35 keys. Catalog names meeting events, event filters and join actions. Calendar source, account dependence and offline history are unknown.

- `add_agenda`: "Add Agenda"
- `all_day_event`: "All-day"
- `all_done_today`: "All done for today ✅"

#### Screen recording and capture permissions

13 keys. A shipped message says screen recording is unavailable with on-device storage. A local capture equivalent is a design choice until the cloud dependency is traced.

- `screen_recording_local_info`: "Screen recording isn't available with\non-device storage. To use it, update\n the storage location in your settings."
- `permissions_backdrop.screen_capture_desc`: "Capture screen and video in meetings."

Native support: `ev_82a288cac329f8c56c70b229dab17784b6f6ae35d0d61b7bde9ed4b7015715d1`. Native media graph, model, recording, ASR, diarization and translation handlers. Individual catalog paths are not proven to call these handlers.

#### Accent conversion, language variants and tests

90 keys. Mic and speaker conversion, tests, headset constraints and model preparation are named. Download requirements and offline inference are not proven. Accent variant labels can include coming-soon choices.

- `accent_conversion.mic_title_expanded`: "Convert my accent"
- `accent_conversion.speaker_title_expanded`: "Convert others' accent"
- `accent_conversion.error.model_preparation_no_connection`: "Failed to prepare models. Please check your internet connection and try again."
- `accent_conversion.recording_notice`: "Your recording will never leave you device and won’t be saved."

Native support: `ev_82a288cac329f8c56c70b229dab17784b6f6ae35d0d61b7bde9ed4b7015715d1`. Native media graph, model, recording, ASR, diarization and translation handlers. Individual catalog paths are not proven to call these handlers.

#### Live captions and companion panel

6 keys. Captions are named. This Mac catalog also contains a Microsoft Visual C++ error, so platform reachability cannot be assumed.

- `companion.show_captions`: "Turn on Captions"
- `companion.live_captions_runtime_error.title`: "Microsoft Visual C++ Runtime is missing or not installed correctly."

#### AI notes, summaries and call insights

32 keys. Labels name summaries, notes, auto-open behavior, insights and summary errors. Local generation and dependencies remain unknown.

- `auto_summarization`: "Auto-summarization"
- `auto_summarization_off`: "Auto-summarization is Off"
- `auto_summarization_on`: "Your meetings will be Auto-\nsummarized"

#### Updates, repair and installation

40 keys. Local repair and restart actions are candidates. Vendor update checks and downloads cross the network boundary and should be replaced by independent distribution decisions.

- `audio_interruption_info`: "You might experience an audio interruption while\ninstalling the update."
- `btn_install`: "Install"
- `btn_repair`: "Repair"

#### Connectivity, sync and proxy errors

12 keys. Error labels refer to connectivity and sync. A local equivalent must trace each caller to decide which failures disappear with cloud exclusion.

- `cant_find_page_text`: "Can’t find the page?"
- `check_internet`: "Please check your internet connection"
- `connect`: "Connect"

## Cross-check and next evidence

`feature-checklist.json` records 97 matching native N-API handler symbols. JavaScript export registration and runtime invocation remain unverified. `native-findings.md` corroborates CoreAudio controls, media graphs, AEC, recording, ASR, diarization, process observation and permissions. None of these symbols proves a complete catalog-to-handler path.

Five native companions differ from their ASAR declared digests. Native corroboration applies to current local bytes. Runtime tests should resolve settings defaults, model download boundaries, local storage formats, caption availability, screen capture dependence, calendar sources and exact call detection. No app was launched for this map.
