# Model license evidence

Redistribution terms for the original Krisp KEF weights remain unresolved. The retained evidence does not establish a grant to publish those files on GitHub. This report makes no conclusion about legal permission or prohibition. No vendor model was copied or published.

## Retained bundle inventory

REA inventory Evidence `ev_e9c2f082e96a01b0b07c8d7592751b75938b3ad3d2ed21cf8e2db00c3618b818` is embedded in `evidence/native/artifact.json`, inspection Evidence `ev_8ffbd9d68802867df2fccd15b83cfd5ff1bf885be54d260d81bce84cac99d01d`. Root bundle SHA-256 is `b5ba67c87a38685ea1097718d127ad525113abfd8fd68f5cb3c9c3cb3e070d6f`. The inventory retains 56 notice files under `Contents/Resources/licenses/` and 8 bundled KEF files.

Named notices include Electron, ONNX Runtime, WebRTC, MKL, FFTW, LAME, libcurl, miniaudio, sentencepiece, XNNPACK and JavaScript dependencies. Their filenames identify dependency notice candidates. Their contents were not recovered in this pass. No filename is a license grant for Krisp KEF weights.

The following license-name candidates occur outside the dependency notice directory:

No additional license, notice, copyright or terms path name matched in this retained bundle path inventory. This is a bounded filename search, not proof that terms are absent.

## Bundled model boundary

- `Contents/Resources/resources/models/audio/c5.n.s.20949d_1.2.kef`.
- `Contents/Resources/resources/models/audio/c6.b78b81_1.0.kef`.
- `Contents/Resources/resources/models/audio/c8.f.m.528d1f-1.0.1_1.0.kef`.
- `Contents/Resources/resources/models/audio/c8.f.s.17aa82-1.0.1_1.0.kef`.
- `Contents/Resources/resources/models/audio/c8.w.m.d15e29_1.0.kef`.
- `Contents/Resources/resources/models/audio/diar_2.0.0_1.0.kef`.
- `Contents/Resources/resources/models/audio/hs.c6.f.m.75df8f.berlin.kef`.
- `Contents/Resources/resources/models/audio/hs.c6.f.s.de56df.bucharest.kef`.

`models.json` was decoded by REA `inspect_plist`, Evidence `ev_016bcec295d94aa5289ae0b5d7b20c241a7d45e880bb797083c9fd4b59c89def`, saved in `evidence/models-configuration.json`. It maps model names, categories, rates, performance values and defaults to KEF filenames. No license, copyright, redistribution or attribution field occurs in its decoded value.

The configuration also references `asr_eng_6.2.0_1.0.kef`, `ar_inbound_wb_c_3.12.0_1.0.kef` and `ar_outbound_wb_c_ma_3.11.0_1.0.kef`. These references do not establish the contents or licensing of downloaded files. The saved `downloaded-model-inventory.json` and individual downloaded-model records are REA failures without successful artifact evidence. They cannot establish a download-directory notice inventory.

## Runtime licenses and weights

A framework or inference runtime notice applies according to its own terms and identified subject. The inventory supplies no evidence that any such notice covers the separately named KEF weights. Do not classify the weights as MIT, Apache, BSD or another license from a runtime filename. The independent implementation needs a separate recorded license source for each external model it distributes.

## New REA probe and limits

The supported probe was:

```text
bin/rea inspect-artifact /Users/harikp/Applications/krisp.app/Contents/Resources/licenses/onnx-runtime_license.txt --format json --full-output
```

REA 6.4.0 returned `target_unavailable`, category `unavailable`, with reason `unsupported binary format`. It produced no successful Evidence ID and no notice text. The failure record stayed in `/tmp/krisp-onnx-license-inspection.json`. It was not treated as a notice observation.

The shipped `inspect-plist` implementation accepts plist or JSON decoding through `plutil`; it has no plain-text notice read mode. `extract-artifact` extracts all regular artifact contents. This pass did not use it because extracting the bundle would also copy vendor model assets, outside this review scope. No shell read or extraction of original notice bytes was used.

No Krisp website or account terms were fetched. No original app runtime was launched. The filename search covers the retained bundle inventory only. It does not cover internal KEF metadata, downloads, external agreements, vendor grants or account-specific terms.

## Publication consequence

Original-model publication cannot be justified from these records. Keep original weights out of the proposed GitHub payload until a weight-specific source or vendor grant establishes the intended redistribution scope. This is an evidence requirement for the proposed action, not a legal conclusion. Independently licensed models and a local user-supplied model path can be documented separately.

## Notice path index

- `Contents/Resources/licenses/MKL_license.txt`.
- `Contents/Resources/licenses/WebRTC_license.txt`.
- `Contents/Resources/licenses/adm-zip_license.txt`.
- `Contents/Resources/licenses/archiver_license.txt`.
- `Contents/Resources/licenses/async-mutex_license.txt`.
- `Contents/Resources/licenses/auto-launch_license.txt`.
- `Contents/Resources/licenses/bzip2_license.txt`.
- `Contents/Resources/licenses/classnames_license.txt`.
- `Contents/Resources/licenses/ctc-decoder_license.txt`.
- `Contents/Resources/licenses/date-fns_license.txt`.
- `Contents/Resources/licenses/dayjs_license.txt`.
- `Contents/Resources/licenses/electron-squirrel-startup_license.txt`.
- `Contents/Resources/licenses/electron.txt`.
- `Contents/Resources/licenses/fast-xml-parser_license.txt`.
- `Contents/Resources/licenses/fftw_license.txt`.
- `Contents/Resources/licenses/flat_license.txt`.
- `Contents/Resources/licenses/fmt_license.txt`.
- `Contents/Resources/licenses/fs-extra_license.txt`.
- `Contents/Resources/licenses/glob_license.txt`.
- `Contents/Resources/licenses/grpc-grpc-js_license.txt`.
- `Contents/Resources/licenses/https-proxy-agent_license.txt`.
- `Contents/Resources/licenses/i18next_license.txt`.
- `Contents/Resources/licenses/jsonwebtoken_license.txt`.
- `Contents/Resources/licenses/lame_license.txt`.
- `Contents/Resources/licenses/libcurl_license.txt`.
- `Contents/Resources/licenses/libresample_license.txt`.
- `Contents/Resources/licenses/libsamplerate_license.txt`.
- `Contents/Resources/licenses/libzip_license.txt`.
- `Contents/Resources/licenses/lodash_license.txt`.
- `Contents/Resources/licenses/lottie-react_license.txt`.
- `Contents/Resources/licenses/miniaudio_license.txt`.
- `Contents/Resources/licenses/nedb-promises_license.txt`.
- `Contents/Resources/licenses/nlohmann-json_license.txt`.
- `Contents/Resources/licenses/onnx-runtime_license.txt`.
- `Contents/Resources/licenses/punycode_license.txt`.
- `Contents/Resources/licenses/react-datepicker_license.txt`.
- `Contents/Resources/licenses/react-dom_license.txt`.
- `Contents/Resources/licenses/react-router-dom_license.txt`.
- `Contents/Resources/licenses/react-scroll-to-bottom_license.txt`.
- `Contents/Resources/licenses/react-transition-group_license.txt`.
- `Contents/Resources/licenses/react_license.txt`.
- `Contents/Resources/licenses/retry_license.txt`.
- `Contents/Resources/licenses/semver_license.txt`.
- `Contents/Resources/licenses/sentencepiece_license.txt`.
- `Contents/Resources/licenses/sentry-electron_license.txt`.
- `Contents/Resources/licenses/socket.io-client_license.txt`.
- `Contents/Resources/licenses/socket.io_license.txt`.
- `Contents/Resources/licenses/source-map-support_license.txt`.
- `Contents/Resources/licenses/spdlog_license.txt`.
- `Contents/Resources/licenses/systeminformation_license.txt`.
- `Contents/Resources/licenses/tough-cookie_license.txt`.
- `Contents/Resources/licenses/utf8proc_license.txt`.
- `Contents/Resources/licenses/xnnpack_license.txt`.
- `Contents/Resources/licenses/xz-utils_license.txt`.
- `Contents/Resources/licenses/zlib_license.txt`.
- `Contents/Resources/licenses/zstd_license.txt`.
