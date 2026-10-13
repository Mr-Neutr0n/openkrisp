# Current UI runtime map

This map uses retained REA captures of the running Krisp UI. It covers the main screen and five settings panels. It is not a complete parity specification. Account values, emails, meeting titles, and personal device names are omitted. Raw captures and screenshots remain private.

The companion `ui-runtime-map.json` records exact Evidence IDs, label paths, snapshot indices, current states, and screenshot digests. Scope classifications below are reconstruction choices. They do not prove the original app's local or cloud data flow.

## Evidence and action outcomes

| Capture | Evidence | Verified result |
| --- | --- | --- |
| `access-granted-ui.json` | `ev_1bd54ca1a2caae597e12864e2a82d77a2ed0ccff14c16c38156e628d33285f4c` | Main UI AX tree captured. No scenario actions. |
| `ui-main-current.json` | `ev_48b8e8d98cc30f95bd3d162c0e88725ce85918fc4096f7325c88375226aac184` | Main UI AX tree captured in the later process. No scenario actions. |
| `ui-settings-action.json` | `ev_18a5f3faae1552f0b4dbb3d8a09142b5586345561b75cc4e93b03da9118643c4` | Delayed snapshot after completed click and wait shows Account settings and settings navigation. |
| `ui-noise-settings.json` | `ev_c4357d34f9930aaa0a531568873fb58781f7db66da1b1ae97d99d744a580f62c` | Delayed snapshot after completed click and wait shows Noise Cancellation content. |
| `ui-app-notifications.json` | `ev_863fa62cc9335b90ad0b5bfcdc772725d760872b970ebbcb45b07b0d8a8c2ade` | Delayed snapshots after each completed click and wait show App, then Notifications content. |
| `ui-note-taker-settings.json` | `ev_4192036d13441abb4bb312cc3cc8282d561ad361fc18aa67db630500a56ac87c` | Delayed snapshot after completed click and wait shows AI Note Taker content. |
| `ui-appearance-roundtrip.json` | No Evidence ID in failed envelope | Scenario failed with ambiguous-window geometry. No completed theme change or restoration is established. Root-agent resolution remains pending. |

The immediate settings-click capture has truncation and AX errors. Its delayed snapshot has neither. Several immediate panel captures show only a new heading or prior content. The report uses the delayed snapshots to confirm panel reachability.

I viewed the Noise Cancellation, App, Notifications, and AI Note Taker screenshots. Each PNG's SHA256 matches the embedded screenshot digest for the cited delayed snapshot. State claims below use those viewed screenshots. They describe current selections, not factory defaults. Factory defaults remain unknown.

## Main screen and settings navigation

The main screen represents Meeting Assistant. AX buttons include Search, New, Create folder, Invite teammates, Upgrade, and Work email +7d. This capture does not establish what those buttons do after use. Search, local creation, and folder organization are possible local adaptations. Invitations, upgrades, and work-email entitlement prompts are excluded account or cloud surfaces.

The settings navigation exposes Account; Admin Settings; Users; Billing; AI Note Taker; Templates; Integrations; Privacy & Consent; Personalization; Calendar; Language; Action Items; Vocabulary; Tags; Noise Cancellation; App; and Notifications. Workspace, Meeting Assistant, Audio, and App Behavior & System are section labels.

Account, Noise Cancellation, App, Notifications, and AI Note Taker content was reached. Other navigation labels do not prove those pages were opened or their controls tested. Account, workspace administration, billing, external integrations, and calendar connections are excluded from the requested local rebuild. The remaining unvisited pages need further evidence before their local scope can be defined.

The Account panel has profile fields and controls for changing email, two-factor authentication, support access, and account deletion. No account control was used. No field values are included here.

## Noise Cancellation

Source: `ev_c4357d34f9930aaa0a531568873fb58781f7db66da1b1ae97d99d744a580f62c`, `steps[1].after`.

| Control | Represented options or label | Current state | Reconstruction scope |
| --- | --- | --- | --- |
| Voice Isolation | Off; Auto (recommended) | Auto selected in screenshot | Local audio candidate |
| Performance mode | Auto (recommended); Maximum removal; Battery saver | Auto selected in screenshot | Local audio candidate |
| Krisp Microphone | Auto-adjust Krisp Mic volume at call start | Unknown, control below viewed viewport | Local audio candidate |
| Restore defaults | Restore button | Not used | Local audio candidate |

The UI describes Voice Isolation as reducing nearby voices and echo. It says Auto activates with a headset. Performance mode descriptions refer to noise removal and battery or CPU use. These are UI claims, not measured processing results. No mode was changed, no audio was processed, and no defaults were restored.

## App

Source: `ev_863fa62cc9335b90ad0b5bfcdc772725d760872b970ebbcb45b07b0d8a8c2ade`, `steps[1].after`.

| Control | Current state | Reconstruction scope |
| --- | --- | --- |
| Open links in desktop app | On | Local app candidate |
| Show widget | On | Local app candidate |
| Show my talk time percentage | Checked | Local app candidate |
| Appearance | System selected; Light and Dark buttons present | Local app candidate |
| Launch at startup | On | Local app candidate |
| Open Desktop app | On, lower description clipped | Local app candidate |

No startup registration, link handling, widget display, or talk-time behavior was tested. The screenshot proves the displayed appearance selection only. The failed appearance scenario does not prove a completed roundtrip or unchanged state after that attempt.

## Notifications

Source: `ev_863fa62cc9335b90ad0b5bfcdc772725d760872b970ebbcb45b07b0d8a8c2ade`, `steps[3].after`.

| Control | Current state | Reconstruction scope |
| --- | --- | --- |
| Upcoming meeting notifications | On | Calendar integration excluded |
| Meeting recap | On | Candidate for a local session-completion notification |
| Comments and mentions | On | Cloud collaboration excluded |
| Device Setup Reminders | On | Local device candidate |

The UI describes device reminders when the meeting app does not select the Krisp microphone or speaker. No notification delivery or meeting-app detection was tested. The local recap interpretation is a proposed adaptation, not an observed offline behavior.

## AI Note Taker

Source: `ev_4192036d13441abb4bb312cc3cc8282d561ad361fc18aa67db630500a56ac87c`, `steps[1].after`.

| Control | Current state or represented choices | Reconstruction scope |
| --- | --- | --- |
| Auto-start AI Note Taker | On | Local call-detection candidate |
| Automatically open meeting page | On | Local session-page candidate |
| Automatically summarize meeting notes | Off; Core badge visible | Model-dependent local adaptation |
| Automatically generate AI meeting title | On | Model-dependent local adaptation |
| Exclude these apps from AI Note-taker | Select apps field visible; options not opened | Local app-detection candidate |
| Auto-share Meeting Notes | All meeting invitees; Only Team invitees; Manually send recap. Selection unknown. | Cloud sharing excluded |
| Default link permission | Public; Invite only. Selection unknown. | Cloud sharing excluded |

The last two groups exist in AX text below the screenshot viewport. Their selections are not verified. The Core badge does not prove whether the summary control is disabled, licensed, or available offline. No recording, transcription, summarization, renaming, app exclusion, or sharing action was tested.

## Names and remaining limits

Use current runtime labels such as Meeting Assistant, AI Note Taker, Voice Isolation, Performance mode, App Behavior & System, and Device Setup Reminders when building the next parity checklist. Do not assume they are exact aliases of older 997-catalog identifiers. This report uses only the new retained UI captures and does not resolve those older mappings.

Many switches and option groups appear as unnamed AX groups with text labels. Their AX values do not expose checked or selected state. Screenshot state fills only the entries explicitly listed above. Hidden controls, dropdown choices, persistence across restart, defaults, processing quality, and cloud dependencies remain unresolved.

The failed theme envelope contains no successful action sequence. A failed after-capture can follow an action, so failure alone does not establish absence of an application effect. The root agent owns fresh geometry validation and any required restoration. This worker did not launch or interact with the original app, change desktop files, or restore settings.
