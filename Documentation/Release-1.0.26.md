# WrapPin 1.0.26 (Build 94) — personal SideStore build

[简体中文](Release-1.0.26.zh-CN.md) · [繁體中文快速開始](../README.zh-Hant.md)

This is a build of the `kkycble/WrapPin` fork, not an official suversal/WrapPin or Roam Control release.

## Added

- Full Traditional Chinese (`zh-Hant`): 897 UI/legacy/error keys, three permission descriptions and four Siri/App Shortcuts phrases. Hong Kong and Taiwan Traditional Chinese preferences resolve to this localization; iOS per-app language selection is supported. Shared Xcode schemes no longer force Simplified Chinese.
- A distinct cycling mode using MapKit cycling directions, with route alternatives, a bicycle marker, map following, pause/resume, exact arrival and Stop & Restore. Cycling speed defaults to 18 km/h and supports 1–60 km/h in 1 km/h steps; estimates use the chosen constant speed.
- Cycling-specific interrupted-session records, summaries and resume controls. Resume replans cycling directions from the last saved point with the saved coordinate mode and speed. Existing walking/driving records remain readable; nothing resumes automatically.
- Tunnel-app selection during onboarding, with Shadowrocket's Include Route 10.7.0.1/32 requirement shown immediately. Existing stored tunnel preferences remain unchanged; a working Shadowrocket device tunnel does not need LocalDevVPN.

The cycling implementation is independent of Roam Control's current non-public source. The existing native pairing engine and external-tunnel transport are unchanged.

## SideStore package

Use **`WrapPin-Standard-1.0.26-build94-unsigned.ipa`**. Standard contains no VPN extension and is signed by SideStore when installed. Do not use Tunnel for a free-account SideStore install.

The fork's [Build SideStore IPA workflow](https://github.com/kkycble/WrapPin/actions/workflows/ios-ipa.yml) uses Xcode 27.1, runs the offline checks, compiles both editions in Debug and Release, then archives Standard with `CODE_SIGNING_ALLOWED=NO` and packages it with `ditto`. Its `WrapPin-Standard-SideStore` artifact contains the IPA, checksum and receipt. No Apple credentials or signing material are used in CI. Download/unzip the artifact, save the IPA to Files, then use SideStore → My Apps → + to select the local file.

This personal build leaves analytics and Geoapify identifiers blank: it sends no usage statistics and hides the additional key-dependent overseas-search switch. Apple Maps search and coordinate entry remain available. In configured builds the optional cycling-start count is a fixed event name with no route, location or speed payload; the privacy documentation and manifest remain aligned.

## Verification and remaining device gates

`scripts/run-checks.sh` runs 21 check invocations, including localization syntax/format/placeholder parity, actual Foundation language matching, legacy/cycling recovery, route movement and speed bounds, fake-device pause/reconnect/stop, background-session and pairing/reset regression, and the IPA validator's non-installable ZIP fixtures. The validator checks the actual compiled Chinese resources, device architecture/platform, minimum OS, app/build identity, Shadowrocket URL scheme, legal resources and no embedded extension. The workflow also checks Standard has no NetworkExtension linkage.

[Build 44565587160 succeeded](https://github.com/kkycble/WrapPin/actions/runs/44565587160) on 19 November 2026: all 21 checks, both Debug device builds, Tunnel Release build, Standard Release archive, IPA verification and upload passed with Xcode 27.1 (27A9275). Source: `8674ec2df8eaaa455d9096d079ec9fb77119e095`. Later documentation-only changes do not change the packaged app. The unchanged native engine's Rust tests and simulator UI checks were not rerun.

**[Download Standard IPA bundle (ZIP)](https://github.com/kkycble/WrapPin/actions/runs/44565587160/artifacts/14550359597)**; sign in to GitHub if prompted; retained until 19 December 2026. The IPA is 7,162,726 bytes, SHA-256 `0bb1db7b70c6c57a640d347fcc9bfa86e8eea96bf591f270c46337a6f3900b6f`. See the [exact CI receipt](../Releases/TraditionalCycling-build94/receipt.json). The sandbox could retrieve the check receipt but not download the binary from the artifact-storage host; validation of the actual IPA ran successfully in CI, not independently in this Linux workspace.

Physical-device verification is still required for:

- SideStore signing, clean/upgrade installation, developer trust and preservation of existing local state.
- RPPairing import on iOS 18–26, on-device pairing on iOS 27, and Shadowrocket reachability on the installed copy.
- Actual Apple Maps cycling coverage, location changes, interrupted cycling recovery and confirmed real-location restoration.
- Locked-screen and long background continuity, including after network changes.

## Known limits

- Apple Maps cycling coverage varies by region. No walking/driving route is silently substituted; draw a custom route or import GPX and select a suitable speed instead.
- Apple cycling routes are not simply reversed because one-way streets may invalidate the return path. Custom routes retain their local return option.
- Shadowrocket's existing mobile-data limitation is unchanged. Use Wi-Fi if its device channel is unavailable on 4G/5G, enable Include Route 10.7.0.1/32 and return to WrapPin manually after connecting.
- The app follows iOS language preferences; map labels and provider results need not all be Chinese.
- Keep WrapPin open while restoring, then verify the real position in Apple Maps. This changes developer-simulated coordinates, not IP address, account region or third-party server data.
