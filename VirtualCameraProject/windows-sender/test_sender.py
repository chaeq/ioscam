import io
import socket
import struct
import tempfile
import threading
import time
import unittest
from pathlib import Path
from PIL import Image
from protocol import HELLO, FRAME, MAX_PAYLOAD, handshake, frame
from sender import encode_image, serve


def exact(sock, count):
    data = bytearray()
    while len(data) < count:
        chunk = sock.recv(min(137, count - len(data)))
        if not chunk:
            raise EOFError("truncated stream")
        data.extend(chunk)
    return bytes(data)


class SenderTests(unittest.TestCase):
    def test_wire_bytes_and_limits(self):
        self.assertEqual(handshake(1080, 1920, 30).hex(), "5643414d000104380780000100007530")
        self.assertEqual(frame(1, 1000, b"abc"), struct.pack("!QQI", 1, 1000, 3) + b"abc")
        for args in [(0, 1, 30), (1921, 1, 30), (1, 1, 0), (1, 1, 61)]:
            with self.assertRaises(ValueError):
                handshake(*args)
        for payload in (b"", b"x" * (MAX_PAYLOAD + 1)):
            with self.assertRaises(ValueError):
                frame(0, 0, payload)

    def test_image_tcp_pacing_reconnect_and_stop(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "test.png"
            Image.new("RGB", (80, 40), "red").save(path)
            jpeg = encode_image(path, 108, 192)
        image = Image.open(io.BytesIO(jpeg))
        self.assertEqual(image.size, (108, 192))
        self.assertLess(sum(image.getpixel((0, 0))), 20)  # letterbox
        ready = threading.Event()
        stop = threading.Event()
        messages = []
        def log(message):
            messages.append(message)
            if "Listening" in message:
                ready.set()
        worker = threading.Thread(target=serve, args=(jpeg, 108, 192, 10, "127.0.0.1", 0, stop, log))
        worker.start()
        try:
            self.assertTrue(ready.wait(3))
            port = int(messages[0].rsplit(":", 1)[1])
            for attempt in range(2):
                with socket.create_connection(("127.0.0.1", port), timeout=3) as client:
                    self.assertEqual(HELLO.unpack(exact(client, 16)), (b"VCAM", 1, 108, 192, 1, 10000))
                    timestamps = []
                    for number in range(4):
                        sequence, timestamp, size = FRAME.unpack(exact(client, 20))
                        self.assertEqual(sequence, number)
                        self.assertEqual(exact(client, size), jpeg)
                        timestamps.append(timestamp)
                    self.assertTrue(all(b > a for a, b in zip(timestamps, timestamps[1:])))
                    self.assertGreater(timestamps[-1] - timestamps[0], 200_000)
                    self.assertLess(timestamps[-1] - timestamps[0], 1_500_000)
        finally:
            stop.set()
            worker.join(3)
        self.assertFalse(worker.is_alive())


if __name__ == "__main__":
    unittest.main(verbosity=2)
