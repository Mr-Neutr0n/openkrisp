# Security reports

openkrisp is a development project. There is no supported production release or fixed security-response schedule. Reports against the current default branch are useful.

Use [GitHub private vulnerability reporting](https://github.com/Mr-Neutr0n/openkrisp/security/advisories/new) when available. If private reporting is unavailable, open an issue that asks for a private contact method. Do not include the vulnerability details in that issue.

Include the affected commit, macOS version, reproduction steps and the expected impact. Use a minimal synthetic example. Do not send private call recordings, credentials, proprietary binaries or model weights.

The desktop app, audio helper and system driver have different privileges and lifetimes. State which component you tested. A passing synthetic test does not establish safe driver installation, real-device cleanup or capture-permission behavior.
