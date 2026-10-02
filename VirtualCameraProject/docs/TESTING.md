# Stage 1 test gate

## Results actually obtained — 2026-10-02

Windows / Python 3.13 / Pillow 10.4.0:

- `python -m unittest -v test_sender.py`: **2 tests passed**. Golden handshake bytes and payload limits; generated image resize/letterbox; real TCP loopback read in small chunks; payload equality; monotonic timestamps and 10 FPS pacing tolerance; disconnect/reconnect with sequence reset; clean stop. Test image output is 108x192, not a performance benchmark.
- Tk window/widget construction and default FPS smoke check: **passed**. No interactive file-picker or visual layout review claimed.
- Swift compiler/Xcode: **unavailable locally**; the macOS CI device build **passed** in [run 37062661852](https://github.com/chaeq/ioscam/actions/runs/37062661852).
- IPA downloaded and its ZIP structure and Info.plist validated. Loaded into Sideloadly and installation initiated for the connected iOS 27 phone. User subsequently confirmed the app opens on the phone.
- Physical-device image display: **user confirmed the selected car-interior image appears**. TCP connection observed from phone `172.20.10.1` to PC `172.20.10.4:5055`; sender reports approximately 30 FPS at 1080x1920. This used the Apple Mobile Device Ethernet USB tethering network. Wi-Fi was disconnected; its deprecated `172.20.10.7` address caused the initial timeout.
- Received/displayed FPS, end-to-end latency, prolonged stability, reconnect behavior and Wi-Fi transport: **not yet measured/verified on device**. Sender FPS is not display FPS.
- Camera substitution / hook / LiveContainer: **not implemented or tested**. Basic transport/display gate passed; the remaining acceptance checks above must not be inferred from this result.

Repeat automated tests:

```powershell
cd C:\Users\White\Documents\ChatGPT\ioscam\VirtualCameraProject\windows-sender
.\.venv\Scripts\python.exe -m unittest -v test_sender.py
```

## Physical device acceptance

1. Build/sign/install using README. Record CI result, sideloader version, phone model and exact OS version/build (user supplied build: 24A437).
2. Use an image with recognizable text and an asymmetric colored corner. Start 360x640 / 10 FPS. Connect the viewer. Confirm the correct image, upright text, advancing frame counter and matching dimensions.
3. Run 60 seconds. Record received FPS and visible responsiveness. No growing application frame queue is intended; this does not prove the kernel/network has no backlog.
4. Stop sender. Expect frozen image and retry status within about five seconds. Restart it. Expect reconnection and sequence reset; compare visible content after choosing a different image.
5. Tap Disconnect and confirm retries stop. Connect again. Background the viewer: networking stops; reopen and tap Connect.
6. Test 1080x1920 / 30 FPS for 60 seconds; record received FPS, heat and memory symptoms. Then 1920x1080 to check landscape. Do not label either mode successful until observed.
7. If permission was denied, enable the app's Local Network permission in Settings. If connection still fails, verify IPv4/port, firewall and Wi-Fi client isolation. Record the actual error rather than assuming a camera problem.

Pass means the actual phone displays the chosen image, counters advance, dimensions/orientation are correct, and disconnect/reconnect works. This is only transport success. The next stage adds CVPixelBuffer/CMSampleBuffer and the two camera modes; hook proof is a later independent gate.

## Result template

```text
Date:
Phone model / full iOS version / build:
CI run URL and build result:
Signing/install method and result:
Windows sender log:
iPhone status and visible image:
Resolution / target FPS / received FPS / test duration:
Stop/restart result:
Orientation result:
Errors:
```

## Later hook proof (not available yet)

Control app renders ordinary AVCaptureVideoDataOutput callbacks. Capture a baseline without the hook, then enable the linked hook without changing camera rendering code. Log original and replacement format/PTS and verify distinct PC content reaches the same delegate. Test physical and frozen fallbacks, delegate replacement/nil, output teardown, front/back and rotation. A PC CAMERA viewer alone is not proof of interception. Only then package and repeat inside LiveContainer. Third-party testing remains conditional on all these results; no authentication, certificate, anti-ban or integrity bypass work.
