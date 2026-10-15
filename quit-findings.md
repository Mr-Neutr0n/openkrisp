# Save-before-quit evidence

Retained REA catalog only, reviewed 2026-10-15. No original runtime, settings, audio or administration actions occurred.

Current catalog Evidence `ev_58c2d2c98cd0dc8a434233efa30e9e4448d97ecb7441ea8fc36caaa79099b6f4`, `evidence/current-translations.json`, contains:

| Exact key | Exact text |
| --- | --- |
| `quit_confirmation_header` | Would you like to save the Meeting Notes?  |
| `quit_confirmation_text` | Krisp is capturing a meeting. Would you like to save it before leaving?  |
| `save_and_quit` | Save and quit |
| `wait_for_quit_text` | Krisp will quit after saving. |
| `quit_in_progress_text` | Quitting, please wait... |
| `btn_quit` | Quit |
| `nav_btn_quit` | Quit Krisp Completely |
| `context_menu_quit` | Quit Krisp Completely |
| `btn_cancel` | Cancel |
| `dialog_btn_cancel` | Cancel |

The first five labels support a confirmation and save-before-exit sequence for captured meeting notes. Generic Cancel labels do not prove which quit dialog uses them. Labels alone do not prove that every termination entry point reaches confirmation, how save completes, or whether failure cancels termination.

Related labels `save_and_relaunch` / “Save and relaunch”, `wait_for_relaunch_text` / “Krisp will automatically relaunch after saving.”, `save_and_sign_out` / “Save and sign out”, and `wait_for_sign_out_text` / “Krisp will sign out after saving.” name separate transitions. `relaunch_no_save` and `sign_out_no_save` both say “Don't save”; neither establishes a quit-specific discard action or its file-deletion semantics. Do not import those destructive semantics into an independent quit flow without evidence. Temporary-test keys `test_nc.cancel_testing` / “Recording is in progress” and `test_nc.cancel_testing_confirm` / “Are you sure you want to quit the test?” describe leaving that test, not application termination.

These labels belong to the retained 3.17.9 checkpoint, Info.plist Evidence `ev_3a54568811b26cf5484325645d4ec772d8a425f658baf6e523ffd035b522b820`. No current quit handler, failure dialog, cancellation behavior or discard implementation has been recovered. Original treatment of imports, transcription, recovery copies, background disk writes, helper-stop timeout, window close, OS logout and repeated quit requests remains unknown.

The independent review will check bounded admission around recording/import/recovery work, truthful save completion before termination, and cancellation of quit when preservation or helper shutdown fails. It will distinguish explicit user cancellation from failure and avoid automatic deletion of retained source data. These are independent preservation requirements, not recovered original runtime parity. No source or ledger changes are included in this findings checkpoint.

## Independent implementation review checkpoint

The stable independent coordinator/delegate/gates passed bounded read-only review after fixes to block inventory refresh during quit and keep microphone-test cleanup errors distinct from stale route errors. The delegate exempts only the actual busy recording activity ID. Recording save proof is checked separately from helper exit. Diagnostic export holds a quit-work token, and library/capture admission blocks new import/recovery/capture during finalization. Cancel and failure reopen admission; approval keeps it closed until exit. No material issue remains in this scope.

Worker reports eleven focused tests (eight coordinator/gate and three independent route/recording integrations) and final desktop `./verify` exit 0 with 97 tests plus signed release/resource checks, log `app/desktop/.build/quit-verify.log`. Tests use injected helpers and synthetic files. Native prompt, actual termination, process logout, forced kill, interrupted OS shutdown and original failure/discard parity remain unverified.
