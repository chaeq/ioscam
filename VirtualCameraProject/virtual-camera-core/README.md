# Stage 2 minimal provider

VirtualCamera.m implements a locked latest-frame slot, off-capture-queue CGImage-to-BGRA conversion, and sample-buffer creation using the incoming camera callback's PTS and duration. A two-second freshness limit or explicit disconnect selects physical fallback, unless freeze is enabled. Frozen buffers receive advancing camera timestamps. No network reads or JPEG decoding occur on the capture queue.

Initial controlled format: 720x1280 portrait BGRA. Allocates a buffer per received image; pooling and generic format negotiation are deferred. A sample attachment identifies substituted frames for the test counter. This minimal module has not yet been verified on the device.
