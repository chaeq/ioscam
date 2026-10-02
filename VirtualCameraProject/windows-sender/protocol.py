"""VCAM/1: network byte order, fixed headers, JPEG payloads."""
import struct

HELLO = struct.Struct("!4sHHHHI")
FRAME = struct.Struct("!QQI")
MAX_PAYLOAD = 8 * 1024 * 1024


def handshake(width, height, fps):
    if not (1 <= width <= 1920 and 1 <= height <= 1920 and 1 <= fps <= 60):
        raise ValueError("Dimensions must be 1..1920, FPS 1..60")
    return HELLO.pack(b"VCAM", 1, width, height, 1, fps * 1000)


def frame(number, timestamp_us, jpeg):
    if not 0 < len(jpeg) <= MAX_PAYLOAD:
        raise ValueError("Invalid JPEG size")
    return FRAME.pack(number, timestamp_us, len(jpeg)) + jpeg
