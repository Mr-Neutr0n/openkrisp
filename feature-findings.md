# Krisp static feature evidence

This report reads the REA-produced bundle `evidence/javascript-initial.json`. It does not inspect extracted source or run the target. It supports a partial investigation, not a claim of feature parity.

## Evidence boundary

Parent Evidence ID: `ev_a171e77e361a92e3a14ece5a0d849dd226d5669aaa7a8dbc9bafd807200e54ca`.
ASAR SHA-256: `fbd6a39ce6fde8685c6ca4c2ca78343aa50551b1bac74f532fd6c5801a23b622`.

REA reports 19 parsed JavaScript files, 37 relevant files, 309 findings, and partial graph coverage. The summary reports zero recovered IPC operations and zero context bridge APIs. Those counts do not prove absence. Resource limits affect the main UI, bootstrap and other major files.

All native method rows below are exact static JavaScript property reads. Their labels are candidate requirements. They do not prove native export existence, invocation, parameters, results, Mac support or offline execution. Windows registry methods in the Mac artifact show why names alone cannot establish supported behavior.

## Observed application structure

`package.json` declares `.vite/build/index.js` as the main entrypoint. REA resolves HTML script entrypoints for `main_window`, `widget`, `companion`, `web_window`, `notification_indicator`, and `notification_reminder`. Locations are the corresponding `.vite/renderer/<name>/index.html` paths in the same parent evidence. Their presence does not establish their visible state or interactions.

REA records localStorage and sessionStorage syntax in the main window, widget and reminder bundles. Key names remain unresolved. Preferences, defaults and actual persistence are unknown.

Five wrapper files require native namespaces under `.vite/build/node_modules/`: `kr-audio-dm`, `kr-media-sp`, `kr-native-utils`, `kr-ext-hub`, and `kr-node-logger`. Each binding appears on line 1 of its `index.js`. All five observed native payloads contradict ASAR integrity metadata. No equivalence to the declared payload is established.

## Native wrapper requests

### `.vite/build/node_modules/kr-audio-dm/index.js`

| Static property request | Source line and columns | Semantic node |
| --- | --- | --- |
| `Initialize` | 15:14 to 15:29 | `jsrg_node_e22a1b66eb585db904648e0891cfa0d6ccade209d018885dce0adbfb8c9d0ebb` |
| `Destroy` | 19:11 to 19:23 | `jsrg_node_a4973a6b9333f4555282969d1ec1a8c42fd32ae686bf69dfc70cd911b8f11a3c` |
| `ConfigureKrispDevice` | 25:24 to 25:49 | `jsrg_node_dc026aaaa440a52967678a204eef4585fb4d8e6c8fcbc3d349a5e2c405d575b8` |
| `ChangeMuteState` | 31:19 to 31:39 | `jsrg_node_34fa9c907f57625d3cff1deb63897c52941f6f63b27bb106e2ee432e6c70674d` |
| `SetAudioEnhancementState` | 37:28 to 37:57 | `jsrg_node_06679fe39c131210789386a912e2013be1eeab6136ebdc9e07772c0d34837a05` |
| `SetDefaultAudioDevice` | 42:25 to 42:51 | `jsrg_node_d8f9003e46c43f0fe7b9a03604273c23cf0f66d568a3422e313503f4b2e25579` |
| `CollectReportingData` | 46:24 to 46:49 | `jsrg_node_27fae87c397adb451da82695694eb1b2e4c2f7c9e0c70dd763d6ddfb229f1ddf` |
| `SetDeviceVolume` | 51:19 to 51:39 | `jsrg_node_fbc6355cfc055e61931ba0ceb416c091ef85f66341b562b491f9fc2abb5dee4e` |
| `GetDeviceVolume` | 56:19 to 56:39 | `jsrg_node_c4b0d87ae374b910e26411865cfe8423fc0f3d2d8e95a0a18e75eacade9e5c62` |
| `ChangeVolumeMappingDevice` | 61:29 to 61:59 | `jsrg_node_d7005538fc2d9309db784bdf1c3d8e9d59be07f96a0f86efafe4808130a59a92` |
| `SetVolumeMappingMode` | 65:24 to 65:49 | `jsrg_node_afe347f685094e33ab50c531de58bdf215665e012ba5c9a09ded52367c669244` |
| `PreventVolumeExternalChange` | 70:31 to 70:63 | `jsrg_node_18a978fe8f5aa4b810d7b9aa6b516760b146ae51da8f9128a068f21aacaa7141` |
| `DisableVolumeChangePrevention` | 75:33 to 75:67 | `jsrg_node_6c322c083c1f3391d3d505fa55aa0779f386a169c2420a03b70dc8618208462f` |
| `SetHidControlMode` | 79:21 to 79:43 | `jsrg_node_3c18b2f5f3232c52c0759821bc30b5044c710f719b1fa9bd02314813e81b1f16` |
| `GetApplicationIconByPID` | 83:27 to 83:55 | `jsrg_node_65097144fa08ae15e6f13190683c644a08ee8c129ac7dcfe30bc6e45cbc46159` |
| `LockKrispMicVolume` | 88:22 to 88:45 | `jsrg_node_98a382182804d53b513812689f84814ba9d9b4b9ac268b2dfe53ccc11c9a31de` |
| `UnlockKrispMicVolume` | 93:24 to 93:49 | `jsrg_node_b335eaea9d58820ad226d61dfef29962256330820b937b2dd4a695547ab867da` |

### `.vite/build/node_modules/kr-ext-hub/index.js`

| Static property request | Source line and columns | Semantic node |
| --- | --- | --- |
| `Initialize` | 4:14 to 4:33 | `jsrg_node_6ffdaf57595ede75659264a2f3cfb88d96afc33f302958d3a3aa96cbf8747614` |
| `Destroy` | 5:11 to 5:27 | `jsrg_node_1ef38f5a9c8947dd0d1a0f286be678e9a5e1b80092c1c6581b6d63d84c0aa479` |
| `ExecuteAction` | 6:17 to 6:39 | `jsrg_node_9b5b809c23202382d2d86cd8f422f9f902d9efa355ee1f7cf5c675dd3c1963cf` |
| `CancelAction` | 7:16 to 7:37 | `jsrg_node_30c4d7d2d403b92752bdc211d7857fae9a2abf0c73c33f0129681dc33888b976` |
| `StartObservation` | 8:20 to 8:45 | `jsrg_node_aad7d2edcbf30f4a46c8361b735c1d0e9a098d0b670110e61eab67c86b55618f` |
| `StopObservation` | 9:19 to 9:43 | `jsrg_node_7a8946b647c550940d9f59b9e5787be28c4f35b166299896dd173188928057b8` |

### `.vite/build/node_modules/kr-media-sp/index.js`

| Static property request | Source line and columns | Semantic node |
| --- | --- | --- |
| `Initialize` | 4:14 to 4:37 | `jsrg_node_ed720b71aac930c11d72dc2c7c80ea98e60697e206cec075ecd2192802136686` |
| `Destroy` | 5:11 to 5:31 | `jsrg_node_f25acb248585ba6440005163f9688cc68f6989a601e8371bbed6adfadbf9c7e0` |
| `LoadModels` | 6:14 to 6:37 | `jsrg_node_a8a8423f579964799c9997e4402b25fb0c890f25f12a2f84ea481bd612a16ac8` |
| `LoadASRModel` | 7:16 to 7:41 | `jsrg_node_b0b05cd5289c97676d5d14cbdeff6d55416818e6f61bd7e16191f17f3f8d7c04` |
| `StartASRProcessing` | 8:22 to 8:53 | `jsrg_node_e2d8bd862062c5f7fa62f4f8ded06ebc93fb40e6a5b3d0d58a451b01f6794dba` |
| `YieldASRResult` | 9:18 to 9:45 | `jsrg_node_8cd97e46ea1a5b03fe78f84842711da8af77cf4906bd8d54772a7c292713b1fa` |
| `StopASRProcessing` | 10:21 to 10:51 | `jsrg_node_990d9f3e858938d215a73a58dd3727f53b95696a52bc2eeacd9a90cfd2f25131` |
| `CreateGraph` | 11:15 to 11:39 | `jsrg_node_7132f074e690ccd917e6481d4073de2cfb3eb446299d813486e49007b57415eb` |
| `StartGraph` | 12:14 to 12:37 | `jsrg_node_119ead2134e69a7e6acf007e90c126f610e7645c190e63025bd4d3d36409e88b` |
| `StopGraph` | 13:13 to 13:35 | `jsrg_node_83ad70a514178a39c5edf3889efdaccd7ebcb487877448ace4ee4bb53777e4ab` |
| `DeleteGraph` | 14:15 to 14:39 | `jsrg_node_35ab2a208591797bfd88fba17008cc40634339b89c312519cd062bcf06d5116b` |
| `ChangeGraphSettings` | 15:23 to 15:55 | `jsrg_node_f817c5beedfcd2e78a0aa3238981c423dbf0074849fba224449908f5f442d6ee` |
| `CollectReportingData` | 16:24 to 16:57 | `jsrg_node_cc7f19d3b642cf15b3337deac729b6bec681fad4c7806f2f6a11dc657080f8c4` |
| `SuspendProcessor` | 17:20 to 17:49 | `jsrg_node_ec98d6874821b0b64ad9deb20ccf08f0bf3e8cf30c1a662c6c4e0fe802464ad7` |
| `ResumeProcessor` | 18:19 to 18:47 | `jsrg_node_ce8ef5c4e1d7171142dbc18a7996889260eb9a8519b456ced7e96a60a0e85987` |
| `ChangeProcessorSettings` | 19:27 to 19:63 | `jsrg_node_47205442c61e56908a16fe1cd5d6e14fef2c4b7162785f22ad19e071fa203c29` |
| `CreateRecording` | 20:19 to 20:47 | `jsrg_node_25f191c12a1eb9ad1a8ec65dffbbb384080642b3df2617db32c3b9eb537bbc82` |
| `DestroyRecording` | 21:20 to 21:49 | `jsrg_node_87ad1a62e8e861642043d9af3ff503832250ca97a45fbb27f15ea596a80044ae` |
| `RedactAudioToMp3` | 22:20 to 22:49 | `jsrg_node_df333e0e80bbb0544a004f58a3062e8e35f57a62b89c25e89391a9d9740db0fa` |
| `EnableTranslations` | 23:22 to 23:53 | `jsrg_node_cc206e6cb2acd117b1c03cef580691d742e7a0a252ae92f2be93c9ca839c488a` |
| `CreateTranslation` | 24:21 to 24:51 | `jsrg_node_67556e6626d3602ac81812982a5794d92ebbf8bdbd0bac36e203fe4798164d08` |
| `DestroyTranslation` | 25:22 to 25:53 | `jsrg_node_8154dce78967c8ed2791064e324f0d116e45c8f830207b9f4496e4b0165c9886` |
| `PlayTranslationText` | 26:23 to 26:55 | `jsrg_node_2f0be7003cda8d516f3ff60dd3c2f8755a707b6ae3ddb504c7bd1ea7712200e3` |
| `InterruptTranslation` | 27:24 to 27:57 | `jsrg_node_20654294786d0ba2397a9a5abd4f42890ffc5fad40f92e534355e0edd324b1f4` |
| `CreateRtcTranscriber` | 28:24 to 28:57 | `jsrg_node_6e8014d9f726d65388e19dd3068b7c9b482d9e639aab21751b2066e1e484102d` |
| `DestroyRtcTranscriber` | 29:25 to 29:59 | `jsrg_node_0f257dfec3bfbdfdfa739af6929b303e2d62038cd5fdfbeb188bd9cf3a7f7675` |
| `StartDiarization` | 30:20 to 30:49 | `jsrg_node_e76adc2b29e300294c2d3bede8c134bfdd68b7b76f37f22ab70978c9c4126ac9` |
| `StopDiarization` | 31:19 to 31:47 | `jsrg_node_df84a2736c5adbe2ad0688bfd5d1d7e29332e2bb1d140e98b5119e3fa38492d4` |
| `PushDiarizationText` | 32:23 to 32:55 | `jsrg_node_e64422c8e53076e730a743417c69ce4685f0a8499d96bf9d5ef68e4c72a721bc` |
| `StartLanguageDetection` | 33:26 to 33:61 | `jsrg_node_99a5e7d31f0a8d1a631c659f63b8ab34ca54bfa4217b464b8d6b3eabb6ac8e9e` |
| `StopLanguageDetection` | 34:25 to 34:59 | `jsrg_node_3edd06111d9b569a6b43b49422f68d1396ad3ce7dcea9cfb32715876a5478127` |
| `GetWssChannelConnectionState` | 35:32 to 35:73 | `jsrg_node_0b2595239887d7e6d652428ba6dcb6b0837506f732761f03160ea63a9f657b15` |
| `GetWssChannelReachability` | 36:29 to 36:67 | `jsrg_node_926c472a51686a01c77fd8bbc94ddce31d705d6b19b3418d375baca032c3e762` |

### `.vite/build/node_modules/kr-native-utils/index.js`

| Static property request | Source line and columns | Semantic node |
| --- | --- | --- |
| `Initialize` | 4:14 to 4:29 | `jsrg_node_1132e6a5ed1fc7dc58724f0b3d39936201f89529b9d4e58476c58c6379027a89` |
| `Destroy` | 5:11 to 5:23 | `jsrg_node_5db99197bbd28f14e78abb885f73b15a9218d1779a9d286b861e248c3c09f8d6` |
| `GetDeviceID` | 6:15 to 6:31 | `jsrg_node_d4b75ff719b95034bc3754a58852ea5cdbb39621445e1fa20f9c6565e6e28825` |
| `GetCpuArch` | 7:14 to 7:29 | `jsrg_node_38ab0f1682310884aa4702440d61858a03bae8c5feeed597680a846f7fa77efd` |
| `StartDeviceRecording` | 8:24 to 8:49 | `jsrg_node_09cbf364e6b88b3fa0eb5108e697e32af34a342cd48219358c42418294f68844` |
| `PauseDeviceRecording` | 9:24 to 9:49 | `jsrg_node_fd2efec805f00b04e194e269dab26e036c7e81ef634aaf5eff42ff017ed0ccd9` |
| `StopDeviceRecording` | 10:23 to 10:47 | `jsrg_node_90131fbf923a9d8d82877578fbc3fe41f9b1dd583c6ae55f1f6834367a5971f6` |
| `StoreSecItem` | 11:16 to 11:33 | `jsrg_node_01ec27fb534bc1756df5d2aa260aeed5674cb3b01033daaef19636c2dcd44062` |
| `GetSecItemValue` | 12:19 to 12:39 | `jsrg_node_fc4786df78cfc0526f87141be4475254cd6d64213de7ec430289067886568c52` |
| `GetSecItemRawValue` | 13:22 to 13:45 | `jsrg_node_12b548705fa76a4d3858c32c08e658ca8313cb83133ef3b0b48d282c46e236c5` |
| `DiscardSecItem` | 14:18 to 14:37 | `jsrg_node_d610dcc3a6b5f15a1920e0dc28c5fec3b1dd9ace338f34f558dc8afc482d933e` |
| `GetSecItemAccount` | 15:21 to 15:43 | `jsrg_node_67959a04b57fa407a5e7f6b65693adefadbe62949ccd8fd6cf1250f11e5f1102` |
| `DecryptOldValue` | 16:19 to 16:39 | `jsrg_node_0efb8881ec56d24666ddcd0f8f224be1c163c4f2c9d402fe8f54575b4f6d7d42` |
| `RegisterTroubleshootingNotifications` | 17:40 to 17:81 | `jsrg_node_cc966de2f490579216c8a14fbd34d1a7ef24c0626ea00286c7802fdf278bc4f8` |
| `UnregisterTroubleshootingNotifications` | 18:42 to 18:85 | `jsrg_node_3850bdcb1c51dff28d59762f7df4dc4d09b5b276b60612a0e440cd8e6ae60970` |
| `GetCertificate` | 19:18 to 19:37 | `jsrg_node_10465ada694c0a8524d9888fd4132f34d870cd0e2b8e01ed09fd4302a8ffa9ab` |
| `FetchKrispDriverVersion` | 20:27 to 20:55 | `jsrg_node_68550005d2596eead5f1b2c5a71c2505f131507263fd69cf5de70e586b98d673` |
| `QueryNotificationInfo` | 21:25 to 21:51 | `jsrg_node_75f890821bdd8675619fb660a5c403f0fd801ac10cf038f4c16469a43873bf6e` |
| `GetSystemEventInfo` | 22:22 to 22:45 | `jsrg_node_f74b42d1c5425057e92442ed2cc995b092c8679e52daab45e9e3962b06f74da6` |
| `GetApplicationInfo` | 23:22 to 23:45 | `jsrg_node_c757cf33290844503e1262ee1c016b5ed8dc765fbae611f9cbf9ed0b475c3e78` |
| `GetHardwareInfo` | 24:19 to 24:39 | `jsrg_node_9e806bbd456556902afd442dd23ddd187ddcb639265fc90704bacb28eb655ca8` |
| `CollectCrashReportData` | 25:26 to 25:53 | `jsrg_node_d221a4ed615a824a10cf9c1d2b1abe82f02c5649121a9f57563514a30657a216` |
| `GetServiceStatus` | 26:20 to 26:41 | `jsrg_node_61c9393b3cacbb82bcbaeaa749208fe9bf5e686914636523f1d9ea4708844c17` |
| `IsRebootRequired` | 27:20 to 27:41 | `jsrg_node_e835cb3ecdfa73cdb9a7dd9e7da4268454faef6760e1c2feb636b98efd11883f` |
| `StartAppControl` | 28:19 to 28:39 | `jsrg_node_1b90bf50ad269ec713bde2ade428b35de799ba0e265ec5d3a9dcde5d9e0c5c52` |
| `StopAppControl` | 29:18 to 29:37 | `jsrg_node_af4e4a047d4b71bac3770c348584ad2ec5a3fd5b92b975df3f1763732c8688c7` |
| `SetKrispIsPromotedValue` | 30:27 to 30:55 | `jsrg_node_39c2d3fdef89eedb0d3486af1b51a32d5efdb6dc083ae1fbd348ea8f74014820` |
| `GetPermissionStatus` | 31:23 to 31:47 | `jsrg_node_d1e1c7a1e6b76348af85f1e38248f5b923ac8597aec9f2aec7f168052a30a1db` |
| `RequestPermission` | 32:21 to 32:43 | `jsrg_node_33f5658a8980d54f89264e7680f32957b8458fe0597f3ccfa4010d5d036b0a3b` |
| `GetPerformanceMode` | 33:22 to 33:45 | `jsrg_node_85f592630058804b5b669702413aa45d28d5ca50876e0c0dc877a87a2f94b138` |
| `EnableHardwareUtilizationMonitoring` | 34:39 to 34:79 | `jsrg_node_7ef54d53ec5cf29eb6ee9649b038d667099248249095645a4c1f996687f639f3` |
| `StartProcessMonitoring` | 35:26 to 35:53 | `jsrg_node_de99b63b629d528f30d9b1240865b35ca6dd3ee52860f1e414ee340d52c9c651` |
| `StopProcessMonitoring` | 36:25 to 36:51 | `jsrg_node_2094e01e6578ae7108481896bddeb2dc45a221e4a041b4166613d7cec46ac6c7` |
| `DLLProbe` | 37:12 to 37:25 | `jsrg_node_8b82a8229feb7c38dcffedfd1b666749255b8cb8b5e858fd391c5e7bf836724e` |
| `GetSystemProperty` | 38:21 to 38:43 | `jsrg_node_40174c158294f12220a521f2d1212ba9c8cfb521aa0814f4b7d93bc3255006e0` |
| `CheckRegKeyExists` | 39:21 to 39:43 | `jsrg_node_4213fad615122b17c282e362eeb983f152c428b02d69ae6c640eb12b15a11177` |
| `GetRegKeyValueInt` | 40:21 to 40:43 | `jsrg_node_2d4a05cadba4ad07feeebcbb4ede76a7f4fefd9336bd92aa3701bfe281ad1a40` |
| `GetRegKeyValueStr` | 41:21 to 41:43 | `jsrg_node_687ab38eee087cf609c145a5edeedc02adaec7b127432da0eff294394cb8504f` |
| `SetRegKeyValueStr` | 42:21 to 42:43 | `jsrg_node_e6cff47d1c72007dc99727c78f7a66893c9fd3dcae1a1bb5a4c37303656f621b` |
| `DeleteRegKeyValue` | 43:21 to 43:43 | `jsrg_node_bd387d6022a6d3c3a1b81b00ad8534f52f9a16a9de4de56c10a336e3de8d5ec2` |
| `GetRegKeyValueBin` | 44:21 to 44:43 | `jsrg_node_6f9e4cf10a59b4737d136d5a18d17d05e6ca3d795145c1955e3c9d54bcfe2feb` |
| `SetRegKeyValueBin` | 45:21 to 45:43 | `jsrg_node_ce275bfe4665043e5505db7d960297ebc93b7f0a5ef4d2f17b2a64ee186337e7` |
| `GetCursorScreenPoint` | 46:24 to 46:49 | `jsrg_node_b225d9d6b4554b075d6953c89ec75eb04ff3f8a37361a3aa10000496b9bd1442` |
| `UnzipFiles` | 47:14 to 47:29 | `jsrg_node_08b44e6e15ab2f4b5bc13b5c23976a1f99bc5aa8a0086c9e113729fa544a27df` |

### `.vite/build/node_modules/kr-node-logger/index.js`

| Static property request | Source line and columns | Semantic node |
| --- | --- | --- |
| `Initialize` | 4:14 to 4:29 | `jsrg_node_fbf8d00c51948c98f6dc800d87a28d2084ae1ca75ae47523d62c876ad2626a35` |
| `Destroy` | 5:11 to 5:23 | `jsrg_node_8b097f7bf669699da6ef48a983278a8b2f1be5178cc2a103a381c749e11abb99` |
| `Log` | 6:7 to 6:15 | `jsrg_node_780b01c33466ee01fa80fa816b31c4daa54696f42e19dd242eb754ac26146282` |
| `SetLogLevel` | 7:15 to 7:31 | `jsrg_node_f7d86d20d51bf59d7d99f091f8f5f2e6b029daab693ec8d3f4e99b755965795b` |
| `SetPattern` | 8:14 to 8:29 | `jsrg_node_eabbe7a456dcbd261b95a32dacfb4cbae319b41d50429c7bd21561f26a7ea503` |
| `Flush` | 9:9 to 9:19 | `jsrg_node_12c36d2e5f12c04849e3b07cd730fde53e556507a465e0f4a712f7313f0967f5` |
| `InitializeNamed` | 10:19 to 10:39 | `jsrg_node_bdf2469c3bcc963c0b88cd468cb3e4a8dfab58d500ebe29218173692b1ac107b` |
| `DestroyNamed` | 11:16 to 11:33 | `jsrg_node_aac165070ac42206c677c3bdd227bca39741ce115bd7dc682dac6b3002917366` |
| `LogNamed` | 12:12 to 12:25 | `jsrg_node_39ee8784b2b6fac09bff8978825432726cb929692a9a2b8c7d451b5d4633ddf6` |
| `SetNamedLogLevel` | 13:20 to 13:41 | `jsrg_node_26f6dafbe0d5cfc69f83a083106d62ec468cdf2300ce8c1d89fcd8a45612bb94` |
| `SetNamedPattern` | 14:19 to 14:39 | `jsrg_node_3d1c432f9f7bd37bd5822c39258dbad697b15595a960e8fb5a519702c6da002c` |
| `FlushNamed` | 15:14 to 15:29 | `jsrg_node_b2378d341379a89f875661e49ce097b27ad553428d925e44ecdd967e0c0f4d0f` |

## Candidate rebuild requirements

The audio wrapper requests device configuration, mute, default device selection, enhancement state, device volume, volume mapping, HID control and volume locking. Device routing, callback shape and processing remain unknown.

The media wrapper requests graph creation and changes, model loading, processor settings, recording, ASR, diarization, translation and WSS connection state. These names justify follow-up questions. They do not classify these operations as local. ASR model loading suggests a model-related path, but it does not establish its model location or independent availability. WSS-related reads do not establish the service endpoint or payload.

Native utilities include permissions, process monitoring, hardware data, performance mode, device recording, service status, driver version, system events, app control and secure-item access. This report does not inspect secure items or account data. The wrapper also contains Windows registry requests. Cross-platform packaging may explain these names, but Mac execution remains unknown.

The logger wrapper requests initialization, log levels, patterns, logging and flush. Local diagnostic logging and remote analytics are different questions. No evidence here establishes their data destinations.

## Endpoint and cloud boundary

The only service-like route literal recovered is `/Krisp.AppService.InstallService/Execute` at `.vite/build/BootstrapApp-BiqTUzCg.js`, line 674, columns 137003 to 137050. It is a static `path` property. Its transport and execution are unknown.

The endpoint detector also labels `years`, `weeks`, `seconds`, `minutes`, `Retry-After`, `X-Sentry-Rate-Limits`, `sentry.sample_rand`, and `sentry.dsc` as network candidates. These are not verified service URLs. Header names and time-unit strings are insufficient to establish network activity.

Sentry-labelled modules and Sentry-related static literals support the presence of bundled Sentry code. They do not establish telemetry transmission, active configuration or the full exclusion boundary. This evidence does not identify a complete set of cloud or analytics endpoints.

## Remaining questions

`feature-checklist.json` retains every recovered wrapper request with its exact evidence and location. It also marks feature-level questions unresolved. The rebuild still needs behavior evidence for audio processing quality, virtual devices, settings, defaults, hotkeys, startup, offline recording, ASR and account-free operation.

## Producer limitations

- .vite/build/BootstrapApp-BiqTUzCg.js: Resource constraint during analyze_javascript_application: Owned JavaScript worker exhausted its heap while analyzing .vite/build/BootstrapApp-BiqTUzCg.js during semantic
- .vite/build/SentryManagerMain-BCbY-HkL.js: Resource constraint during analyze_javascript_application: Semantic graph for .vite/build/SentryManagerMain-BCbY-HkL.js exceeds the parent's remaining result budget; static and module facts were retained
- .vite/build/index-CnqXFUZx.js: Resource constraint during analyze_javascript_application: Owned JavaScript worker exhausted its heap while analyzing .vite/build/index-CnqXFUZx.js during semantic
- .vite/build/preload.js: Resource constraint during analyze_javascript_application: Owned JavaScript worker exhausted its heap while analyzing .vite/build/preload.js during semantic
- .vite/renderer/companion/assets/index-g6AFnWdL.js: Resource constraint during analyze_javascript_application: Owned JavaScript worker exhausted its heap while analyzing .vite/renderer/companion/assets/index-g6AFnWdL.js during semantic
- .vite/renderer/main_window/assets/index-CAmVYtnC.js: Resource constraint during analyze_javascript_application: Owned JavaScript worker exhausted its heap while analyzing .vite/renderer/main_window/assets/index-CAmVYtnC.js during semantic
- .vite/renderer/notification_indicator/assets/index-D3xnSGho.js: Resource constraint during analyze_javascript_application: Owned JavaScript worker exhausted its heap while analyzing .vite/renderer/notification_indicator/assets/index-D3xnSGho.js during semantic
- .vite/renderer/notification_reminder/assets/index-CPilth7p.js: Resource constraint during analyze_javascript_application: Owned JavaScript worker exhausted its heap while analyzing .vite/renderer/notification_reminder/assets/index-CPilth7p.js during semantic
- .vite/renderer/web_window/assets/index-B-pUdwQb.js: Resource constraint during analyze_javascript_application: Owned JavaScript worker exhausted its heap while analyzing .vite/renderer/web_window/assets/index-B-pUdwQb.js during semantic
- .vite/renderer/widget/assets/index-Dt3zCG4z.js: Resource constraint during analyze_javascript_application: Owned JavaScript worker exhausted its heap while analyzing .vite/renderer/widget/assets/index-Dt3zCG4z.js during semantic
- Artifact integrity metadata contradicts observed bytes at .vite/build/node_modules/kr-audio-dm/build/Release/kr-audio-dm.node; the observed bytes are untrusted.
- Artifact integrity metadata contradicts observed bytes at .vite/build/node_modules/kr-ext-hub/build/Release/kr-ext-hub.node; the observed bytes are untrusted.
- Artifact integrity metadata contradicts observed bytes at .vite/build/node_modules/kr-media-sp/build/Release/kr-media-sp.node; the observed bytes are untrusted.
- Artifact integrity metadata contradicts observed bytes at .vite/build/node_modules/kr-native-utils/build/Release/kr-native-utils.node; the observed bytes are untrusted.
- Artifact integrity metadata contradicts observed bytes at .vite/build/node_modules/kr-node-logger/build/Release/kr-node-logger.node; the observed bytes are untrusted.
- CommonJS and ESM binding relationships were recovered from inert syntax and resolved only within the inventoried artifact container.
- Electron relationships are derived from inert syntax; runtime registration, reachability, defaults, and enforcement remain unproven.
- Graph coverage is incomplete; unavailable facts remain explicit and must not be read as absence.
- JavaScript and HTML were parsed as inert text; bundle bootstrap code was never executed.
- Native member names are requested by JavaScript syntax and are not verified binary exports in this workflow.
- Static imports, entrypoints, workers, endpoints, and storage relationships do not prove runtime execution.
- Static paths and relationships may remain unresolved when expressions are dynamic or obfuscated.
- Webpack/Rspack factories were recovered from AST literals; REA did not invoke push handlers or bundle bootstrap code.
