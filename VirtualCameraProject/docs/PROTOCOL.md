# VCAM/1 wire protocol

One Windows TCP server, one active iPhone client; default port 5055. Direct IPv4 entry. No authentication, encryption or Internet exposure: use a trusted LAN. All integers unsigned, big-endian. TCP reads must collect exactly the declared bytes, not assume packet boundaries.

Handshake (16 bytes):

| Offset | Bytes | Value |
|---|---|---|
| 0 | 4 | ASCII VCAM |
| 4 | 2 | version = 1 |
| 6 | 2 | width, 1..1920 |
| 8 | 2 | height, 1..1920 |
| 10 | 2 | encoding = 1, JPEG; decoded RGB image, not a CVPixelBuffer format |
| 12 | 4 | target FPS * 1000, 1000..60000 |

Each frame: 20-byte header then JPEG payload.

| Offset | Bytes | Value |
|---|---|---|
| 0 | 8 | sequence, starts at zero per connection |
| 8 | 8 | microseconds from connection streaming start, monotonic PC clock |
| 16 | 4 | payload length, 1..8 MiB |
| 20 | length | JPEG with dimensions matching handshake |

Sequence must increase and timestamps must not decrease. Sender normalizes EXIF orientation and letterboxes to the requested dimensions; pixels are upright, unmirrored, with no receiver-side rotation metadata. Landscape uses width > height. Reconnect to change format. Image color is an initial RGB/JPEG path, not a calibrated color pipeline.

Receiver rejects invalid headers, payload dimensions and undecodable images. It waits five seconds without a complete valid frame before reconnecting, then retries after two seconds. Disconnect keeps the last image visible with stale status. Backgrounding stops networking; tap Connect after returning. UI polls the latest decoded frame at 30 Hz, so faster incoming frames can be overwritten. There is no presentation queue or ACK in v1. Sender reports successful writes, receiver reports received FPS, neither claims displayed FPS. TCP buffering can add latency; no latency figure is inferred by subtracting unsynchronized PC/iPhone clocks.

Still image is encoded once at quality 80 and repeated with fresh sequence/timestamps. Sender paces using a monotonic clock without catch-up bursts and times out slow socket writes after two seconds. Video decoding, variable-rate media timing, webcam input, adaptive dropping and clock synchronization are deferred.
