# Architecture and feasibility — 2026-10-02

Status update: transport display and the stage 2 linked setter hook succeeded on the phone according to the user's test: live physical output, substituted PC image and increasing replacement counter. The controlled provider uses portrait BGRA. The design below records the original proposal; see STAGE2_TEST.md for current scope and verified fallback checks. This is not a system-wide iOS virtual camera.

## Evidence

Inspected upstream main commit `4dbe0f9a626de801184a42c0be8d2cb105058e3d` and latest stable 3.8.0. LiveContainer runs guest code in its host environment; guest entitlements do not become host entitlements. Its executable patching inserts a loader dependency. See [upstream architecture](https://github.com/LiveContainer/LiveContainer).

[TweakLoader source at the inspected commit](https://github.com/LiveContainer/LiveContainer/blob/4dbe0f9a626de801184a42c0be8d2cb105058e3d/TweakLoader/TweakLoader.m) loads CydiaSubstrate, then global tweaks, then recursively loads the selected app folder using `dlopen`. It accepts dylibs and frameworks and skips disabled entries. This establishes a loading route, not that a particular hook succeeds.

## AVFoundation path

`AVCaptureDevice` represents the camera and its capabilities. `AVCaptureDeviceInput` attaches it to `AVCaptureSession`. The session connects inputs to outputs. `AVCaptureVideoDataOutput` delivers frames to `AVCaptureVideoDataOutputSampleBufferDelegate` on the configured queue. The callback receives a `CMSampleBuffer`; its image buffer is usually a `CVPixelBuffer` containing pixel planes. Device enumeration is therefore the wrong first interception point: it does not manufacture a functioning capture pipeline. See [Apple capture architecture](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/04_MediaCapture.html) and [delegate callback](https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutputsamplebufferdelegate/captureoutput(_:didoutput:from:)).

## Proposed hook — NOT IMPLEMENTED

Intercept `-[AVCaptureVideoDataOutput setSampleBufferDelegate:queue:]` and register a proxy delegate with the original queue. Retain the proxy per output using an associated object; weakly reference the original delegate to respect its lifetime. Preserve nil assignment, replacement, optional selectors and drop callbacks. Install before the app assigns delegates; log registration. Getter semantics and coexistence with other swizzles need explicit tests.

On `captureOutput:didOutputSampleBuffer:fromConnection:`, ask VirtualCameraProvider for a PC pixel buffer. If fresh, convert to the output's negotiated dimensions/pixel format and create a sample buffer using the real callback's presentation timestamp and duration. Forward the substituted buffer with the original output and connection. Never do network reads or JPEG decoding on the capture callback queue. If stale, forward physical input or freeze the last PC image according to configuration; frozen images still receive advancing timestamps.

An Objective-C runtime replacement of this setter plus a delegate proxy is sufficient *in principle* for this specific Objective-C dispatch boundary. Runtime method replacement does not inherently require JIT or instruction patching. It still requires our signed code to be loaded in the guest process. TweakLoader supplies that route. Its bundled CydiaSubstrate-compatible mechanism is available if method coexistence requires it; arbitrary native-function hooks are not a prerequisite for this experiment. None of these statements is a tested iOS 27 hook result.

`CMSampleBufferCreateReadyWithImageBuffer` requires a format description matching the image buffer. Create/cache descriptions per pixel format and size; use a pixel-buffer pool, correct BGRA/NV12 plane layouts, color attachments and ownership. See [Apple sample-buffer requirements](https://developer.apple.com/documentation/coremedia/cmsamplebuffercreatereadywithimagebuffer(allocator:imagebuffer:formatdescription:sampletiming:samplebufferout:)).

## Hard limitations

- Delegate replacement does not replace AVCaptureVideoPreviewLayer's own preview path. Our later control app must render its ordinary data-output callbacks to prove this hook.
- Photo/movie outputs, depth, metadata, multi-camera synchronization, ARKit and private pipelines are separate paths. No coverage is claimed.
- Using real callbacks as the clock still requires camera permission and an active physical session. No callbacks means no substitution; independent scheduling is a separate experiment.
- App-side checks may notice differences in timestamps, format, camera metadata, orientation or environment. Detection is a limitation to report; security/integrity bypasses are outside scope.
- A separate iOS receiver app cannot be assumed to keep running in the background or share its buffers with a guest. The eventual receiver/provider must run inside the same guest process as the hook.
- The present JPEG/TCP viewer does not establish 30 FPS at 1080x1920 or <150 ms. TCP can accumulate stale frames despite a one-frame application slot.

## Stage boundaries

Now: Windows image -> TCP/JPEG -> PCFrameReceiver -> latest UIImage -> SwiftUI viewer. Manual address entry; no Bonjour, camera access or core buffers yet.

After device transport success: PixelBufferConverter -> bounded FrameBuffer -> SampleBufferFactory -> VirtualCameraProvider. Then add REAL CAMERA/PC CAMERA controls, then an unchanged data-output camera viewer with CameraHook enabled. Only after those tests: an app-specific LiveContainer dylib. No third-party app modifications at this stage.
