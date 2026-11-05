# Third-party notices

## RNNoise

`app/noise-engine/vendor/rnnoise/` contains source and the included model from [Xiph RNNoise](https://github.com/xiph/rnnoise), tag `v0.1.1`, commit `6cbfd53eb348a8d394e0757b4025c6ded34eb2b6`.

The upstream copyright and BSD-style redistribution terms remain in [COPYING](app/noise-engine/vendor/rnnoise/COPYING). Keep that notice with source distributions. Binary distributions must reproduce the notice and disclaimer in their documentation or accompanying materials. Desktop packaging includes the notice under `Contents/Resources/helper/notices/RNNoise-COPYING`.

[upstream.json](app/noise-engine/vendor/rnnoise/upstream.json) records the imported files and original SHA256 digests. [vendor-local.patch](app/noise-engine/vendor-local.patch) records local allocation-failure handling, initialization and invalid-activation changes. Modified files are not byte-identical to their recorded upstream digests.

## Node.js

Desktop distributions include the official Node.js 26.13.0 ARM64 executable. The complete upstream `LICENSE`, including notices for Node's bundled dependencies, accompanies it at `Contents/Resources/helper/node-runtime/LICENSE`. Its original Node.js Foundation signature remains intact. [upstream.json](app/node-runtime/upstream.json) pins the official archive, release signer/keyring, executable and license digests. [Runtime preparation](app/node-runtime/README.md) verifies those identities before packaging. Node's license permits redistribution with its notice; the complete versioned terms are [upstream](https://github.com/nodejs/node/blob/v26.13.0/LICENSE).

No npm, npx or global Node installer is distributed. The bundled runtime requires macOS 13.5 or later. Node and the original external providers have separate licenses.

## External installed providers

Optional providers use caller-selected local Krisp files. These original files are not part of the repository or desktop bundle. Their own terms apply. The bundled official Node runtime is the default; the separately reviewed external runtime remains an explicit option. File identities and recovered interface descriptions do not grant redistribution rights. Original model redistribution terms remain unresolved in [model-license-findings.md](model-license-findings.md).

No project license covers Krisp's external binaries, weights, icons, compatibility lists or trademarks. openkrisp is an independent project and is not affiliated with Krisp.
