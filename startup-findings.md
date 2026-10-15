# Launch at startup evidence

Retained REA evidence only, reviewed 2026-10-15. No original settings, login items, runtime or UI were changed or queried for this task.

## Observed labels

Current retained translation catalog Evidence `ev_58c2d2c98cd0dc8a434233efa30e9e4448d97ecb7441ea8fc36caaa79099b6f4`, `evidence/current-translations.json`, contains:

| Exact key | Exact text | Supported conclusion |
| --- | --- | --- |
| `pref_label_launch_at_startup` | Launch at startup | A startup preference is named. |
| `pref_description_launch_at_startup` | Auto-start Krisp on computer boot-up. | The description presents automatic startup as its purpose. It does not distinguish system boot from user login. |
| `pref_label_open_meetings_window_at_launch` | Open meetings window at launch | A separate launch-window preference is named. Its relationship to startup launch versus manual launch is not established. |

The catalog belongs to the retained 3.17.9 checkpoint identified by Info.plist Evidence `ev_3a54568811b26cf5484325645d4ec772d8a425f658baf6e523ffd035b522b820`. Labels do not establish reachability, defaults or executed behavior.

## Supporting evidence and limits

The retained JavaScript analysis records in `evidence/javascript-initial.json` do not expose a matching login-item/startup implementation in their bounded normalized results. Those records concern historical ASAR SHA256 `fbd6a39ce6fde8685c6ca4c2ca78343aa50551b1bac74f532fd6c5801a23b622`, including application analysis Evidence `ev_a171e77e361a92e3a14ece5a0d849dd226d5669aaa7a8dbc9bafd807200e54ca`. This is limited coverage, not proof that the implementation is absent. Retained NativeUtils symbol evidence `ev_d5a7c268a91fe74d0e1be67ea708c3c5c726c11cb293ee43f1ef2a3bcbe401dd` provides no recovered startup contract in the searched names. No current original binary or ASAR was read for this report.

## Unknowns and independent implementation boundary

- Original default for either preference, persistence key and storage mechanism.
- Whether enabling startup registers an Electron login item, ServiceManagement helper or another mechanism; whether macOS approval is required.
- Whether automatic launch is hidden, opens the main window, restores prior windows or follows the separate meetings-window preference.
- Whether startup activates audio routing, processing or recording, and how missing devices or permissions affect launch.
- Whether the original distinguishes user-disabled registration from an application preference, or repairs stale registration.

Independent launch-at-login support is a retained local capability candidate. An implementation can use an explicit user-controlled macOS login item and report actual registration status, but its chosen default, hidden-window behavior and lack of automatic audio activation must be documented as independent choices until further original evidence exists. Do not infer original hidden launch or automatic routing from these labels.
