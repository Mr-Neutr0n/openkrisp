# openkrisp

This is an independent macOS reconstruction of Krisp's local features. Cloud,
analytics, account, trial and payment services are excluded. Full parity is not
yet established.

## Resume and evidence

- Read the latest section linked at the top of `CHECKPOINT.md` before resuming.
  Check Git and runtime state before relying on historical verification or PIDs.
- Use `feature-parity-ledger.md` and its JSON counterpart for scope and evidence.
  Feature counts are not completion percentages.
- Inspect or execute the installed original only through REA. Use ordinary
  development tools for this repository's source and fixtures. Preserve REA
  failures, evidence identities, artifact hashes and coverage limits.
- Consult the relevant `*-findings.md` report before changing recovered behavior.
  Static findings and synthetic tests do not prove runtime or acoustic parity.

## Implementation and verification

- Keep component code in `app/` and cross-component fixtures in `verification/`.
- Run the changed component's `./verify`; root `./verify` runs all components.
  Desktop verification includes packaging, signing and relocated resources.
- Preserve exact installed-provider role/hash admission and stale asynchronous
  result checks. A permission result must not admit a superseded configuration.
- Treat physical capture, audible playback, driver installation and CoreAudio
  restart as separate acceptance steps. Follow `app/audio-driver/install-notes.md`
  for driver work. Do not reinstall a driver merely to restart its service.
- Update the checkpoint and source fingerprints after verified changes. Record
  what was tested and which runtime requirements remain open.

## Workspace layout

- This repository is `product/` in the grouping workspace. The private marketing
  repository is its sibling `../website/`. Keep Git commands inside the selected repository.
- Private evidence and the analysis runtime live at `../evidence/` and
  `../analysis-runtime/`. Historical capture paths remain unchanged. Create new
  scenarios for new source paths instead of editing accepted evidence.

## Repository boundaries

- Keep original models, binaries, assets and compatibility lists external.
  Redistribution rights have not been established. Retain RNNoise notices.
- Do not commit raw private evidence, generated audio, builds or analysis runtime.
  These remain excluded by `.gitignore` and component ignore files.
- Inspect the repository Git identity before committing. Do not add agent
  coauthors. Publish product source to the configured `Mr-Neutr0n/openkrisp` remote. Keep
  marketing source in its separate private repository. Audit tracked files and
  reachable history before widening repository visibility.
