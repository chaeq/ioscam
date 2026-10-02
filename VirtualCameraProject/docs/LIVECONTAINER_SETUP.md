# LiveContainer — later test gate

No tweak binary is built in stage 1. First install the standalone viewer and verify LAN transport. An ordinary signed viewer needs no special entitlements, JIT or container. It uses Foundation, Network, UIKit, ImageIO and SwiftUI. Local network access requires the Info.plist usage description and user permission; this direct TCP prototype uses no Bonjour discovery or multicast entitlement.

For a later controlled guest test, use the [official installation instructions](https://livecontainer.github.io/docs/installation). The [3.8.0 release](https://github.com/LiveContainer/LiveContainer/releases/tag/3.8.0) specifies SideStore 0.6.2+ or AltStore 2.2.1+ for standalone LiveContainer. SideStore is one supported route, not a requirement of our protocol. Do not assume enabling JIT fixes signing or iOS-version issues.

The documented tweak path is: Tweaks tab -> create an app-specific folder -> import dylib/framework -> assign that folder in the controlled guest's settings. Leave TweakLoader enabled. LiveContainer signs imported tweaks before launch; the Sign action permits a retry. See [official tweak guide](https://livecontainer.github.io/docs/guides/tweaks). Its docs call the bundled compatibility framework Ellekit; the inspected source loads `CydiaSubstrate.framework/CydiaSubstrate`.

Later build plan: arm64 iOS dynamic library with a constructor installing the ObjC setter hook; link Foundation, AVFoundation, CoreMedia, CoreVideo, Network, ImageIO and UIKit as needed. No private camera entitlement or extra dylib entitlement is proposed. Host camera/local-network permission is still necessary; guest entitlements cannot grant host privileges. Avoid assuming jailbreak filesystem paths exist; package dependencies together.

Exact dylib build commands, dependency install names and install verification are intentionally deferred until the standalone and linked-hook tests pass. A source-level plan is not a working tweak package. The next evidence must be a loader log, proxy-registration log, callback log and visible substituted frame in our own guest. Stop and report launch/integrity failures; do not bypass them.
