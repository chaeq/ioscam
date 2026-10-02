# iOS 27 evidence and device record

User reports iOS build **24A437**, with no Mac available. Record the full Settings > General > About version, device model and installed LiveContainer version when testing. No independent mapping or successful test of 24A437 has been established here.

On 2026-10-02 the [official latest release](https://github.com/LiveContainer/LiveContainer/releases/tag/3.8.0) was 3.8.0 (published 2026-07-17). Its notes explicitly add iOS 27 developer-beta support. That statement is narrower than compatibility with every iOS 27 build, phone, tweak or guest app. Current main HEAD inspected: `4dbe0f9a626de801184a42c0be8d2cb105058e3d`.

| Question | Current answer |
|---|---|
| Standalone JPEG viewer on 24A437? | Plausible public-API design; not compiled or device-tested here. |
| LiveContainer launching on this phone? | Unknown until installed and launched. |
| Delegate hook on this phone? | Not implemented; no result. |
| JIT required by viewer or proposed ObjC hook? | No inherent JIT requirement. Host signing/launch compatibility remains separate. |
| SideStore required? | Not by the standalone viewer; it needs a working signing/install route. LiveContainer supports installation routes specified by its release. |
| Nightly required? | No evidence that it is required for this prototype. Start with official stable and record the actual result. |
| Snapchat compatibility? | Unknown; not inspected or modified. |

The machine used for development has Python and .NET, but no Xcode or Swift toolchain. A manual macOS CI workflow is provided; it has not been run. An unsigned IPA must be signed by the user's sideloader before installation. CI compilation alone will not prove on-device networking or camera behavior.
