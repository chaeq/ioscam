# Experimental PC -> iPhone camera project

Stage 1: a Windows still-image sender and standalone iOS TCP/JPEG viewer. **No camera substitution is implemented or proven.** Video/webcam input and REAL CAMERA mode are deferred until this minimal transport test succeeds on the phone.

## Run the Windows sender

In PowerShell:

```powershell
cd C:\Users\White\Documents\ChatGPT\ioscam\VirtualCameraProject\windows-sender
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe sender.py
```

Choose an image, set dimensions/FPS, then Start. Defaults are 1080x1920 at 30 FPS. Start at 360x640 / 10 FPS if troubleshooting. `0.0.0.0` listens on all IPv4 interfaces; enter the PC's LAN IPv4 address in the phone, not `0.0.0.0`. Use `ipconfig` to find the Wi-Fi/Ethernet IPv4 address. Both devices must be on the same reachable LAN. If Windows prompts, permit Python on your private network. A firewall rule, if needed, should allow inbound TCP 5055 on the private LAN only.

Expected before connecting: `[PC] Listening on 0.0.0.0:5055`. Expected after connecting: client address, sending dimensions and periodic sent-frame/FPS statistics. Stop ends the stream; Start allows another session. Settings changes take effect on the next Start.

## Build the iOS viewer without a Mac

The repository includes `.github/workflows/build-ios-viewer.yml` at the repository root, outside this project folder. Nothing has been uploaded or run remotely.

1. Put this repository, including that workflow, into a GitHub repository you control. The workflow must exist on its default branch. Enable Actions if necessary.
2. Open Actions -> **Build unsigned iOS viewer** -> **Run workflow**.
3. On success, download the **PCFrameViewer-unsigned** artifact and unzip it to obtain `PCFrameViewer-unsigned.ipa`.
4. Import that IPA through your working sideload/signing setup (for example SideStore). It is unsigned; it cannot be installed directly. No signing certificate or Apple account secret is required by the build workflow.
5. Open **PC Frame Viewer**, enter the PC's IPv4 address and port 5055, tap Connect, and grant Local Network access when prompted.

This workflow is provided but **not executed/validated here**. GitHub account runner availability applies. Share the build log if compilation fails; do not proceed as if an IPA were produced. [GitHub's manual workflow instructions](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow) describe the Run workflow control.

Expected on the phone: selected image, advancing frame number, dimensions and received FPS. The label explicitly identifies this as a transport test. On disconnect it retains the last image and shows retry status. Keep the viewer foregrounded during testing.

## If a Mac becomes available

Install Xcode and XcodeGen, then:

```sh
cd VirtualCameraProject/ios-test-app
xcodegen generate
open PCFrameViewer.xcodepro
```

Select your signing team and a unique bundle ID in the app target, choose the connected iPhone and Run. XcodeGen generates the Info.plist and project from `project.yml`; do not hand-edit generated files. See the [XcodeGen specification](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md).

## Evidence and next gate

Windows loopback integration tests and UI construction smoke test passed on 2026-10-02. The iOS source has not been compiled; no iPhone or LiveContainer test has run. Report the result in [TESTING.md](docs/TESTING.md) before implementing core buffers or hooks.

- [Architecture and proposed interception point](docs/ARCHITECTURE.md)
- [iOS 27 / build 24A437 notes](docs/IOS27_NOTES.md)
- [LiveContainer constraints and future packaging](docs/LIVECONTAINER_SETUP.md)
- [Wire protocol](docs/PROTOCOL.md)
- [Test procedure and actual results](docs/TESTING.md)

Folders: `windows-sender` (Tk UI, image encoding and server), `ios-receiver` (network/decoder), `ios-test-app` (SwiftUI viewer and build spec), `virtual-camera-core` and `camera-hook` (documented placeholders for later gates).
