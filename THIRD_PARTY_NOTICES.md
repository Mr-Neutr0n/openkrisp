# Third-party notices

## RNNoise

`app/noise-engine/vendor/rnnoise/` contains source and the included model from [Xiph RNNoise](https://github.com/xiph/rnnoise), tag `v0.1.1`, commit `6cbfd53eb348a8d394e0757b4025c6ded34eb2b6`.

The upstream copyright and BSD-style redistribution terms remain in [COPYING](app/noise-engine/vendor/rnnoise/COPYING). Keep that notice with source distributions. Binary distributions must reproduce the notice and disclaimer in their documentation or accompanying materials. Desktop packaging includes the notice under `Contents/Resources/helper/notices/RNNoise-COPYING`.

[upstream.json](app/noise-engine/vendor/rnnoise/upstream.json) records the imported files and original SHA256 digests. [vendor-local.patch](app/noise-engine/vendor-local.patch) records local allocation-failure handling, initialization and invalid-activation changes. Modified files are not byte-identical to their recorded upstream digests.

## External installed providers

Optional providers use caller-selected local Krisp files and an external Node runtime. These files are not part of the repository or desktop bundle. Their own terms apply. File identities and recovered interface descriptions do not grant redistribution rights. Original model redistribution terms remain unresolved in [model-license-findings.md](model-license-findings.md).

No project license covers Krisp's external binaries, weights, icons, compatibility lists or trademarks. openkrisp is an independent project and is not affiliated with Krisp.
