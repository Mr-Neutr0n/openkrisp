# Bundled Node runtime

`./prepare` downloads and verifies the exact official Node 26.13.0 ARM64 release recorded in [upstream.json](upstream.json). Python 3.9 or later, `gpgv`, and macOS development tools are build requirements. They are not installer or consumer requirements.

```sh
./app/node-runtime/prepare
./app/node-runtime/verify
```

The output is `build/runtime/{node,LICENSE,provenance.json}`. Desktop packaging copies those three files to `Contents/Resources/helper/node-runtime/`. `LICENSE` is the complete release notice, including Node's bundled dependencies. No npm, npx, headers, global files or original Krisp files are included.

Preparation checks the pinned official release keyring and signed checksum manifest before downloading the archive. It admits one release signer, one archive digest and exact executable/license bytes. Only two regular archive members are read. The runtime keeps its original Node.js Foundation Developer ID signature. Do not re-sign it or use `codesign --force --deep` on the enclosing app. Signing changes its exact admission hash.

`./verify --runtime <directory>` checks an existing staged or relocated resource directory without downloading or executing anything. Checks cover exact files, digests, complete license, provenance, ARM64, macOS 13.5 metadata, upstream signature and the four Apple system dynamic dependencies. The preparation cache retains `signature-verification.txt` for review. Generated files are ignored. Preparation uses the exact pinned versions even if a newer release exists.

The bundled distribution requires macOS 13.5. Owned RNNoise and driver source can retain macOS 12 deployment targets. The runtime identity was tested separately with the current external NC and AR providers. A future runtime update needs a new pinned release record, signature/digest validation and exact-byte REA compatibility checks before admission. The reviewed external Homebrew runtime remains a separate explicit option. No arbitrary Node fallback is permitted.
