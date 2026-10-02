# Stage 2 controlled hook

CameraHook.m swizzles the AVFoundation data-output delegate setter and installs a retained proxy with a weak original delegate. It preserves the requested callback queue and forwards drop callbacks. Hook OFF forwards physical samples; Hook ON requests a replacement from the separate core. Real camera and Hook test share the exact same CameraModel renderer.

This is linked into our own app, not a LiveContainer dylib. Getter transparency, arbitrary formats, other swizzles and third-party compatibility are not implemented. Requires physical camera permission and callbacks. Only portrait 720x1280 BGRA is supported; format mismatch falls back to physical input and increments the visible rejection counter. Device proof remains pending.
