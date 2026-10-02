"""Minimal still-image sender. Run with Python; Tk UI stays on main thread."""
import io
import argparse
import queue
import socket
import threading
import time
import tkinter as tk
from tkinter import filedialog, messagebox
from PIL import Image, ImageOps
from protocol import handshake, frame


def encode_image(path, width, height):
    with Image.open(path) as source:
        image = ImageOps.exif_transpose(source).convert("RGB")
        image = ImageOps.pad(image, (width, height), color="black")
        output = io.BytesIO()
        image.save(output, "JPEG", quality=80)
        return output.getvalue()


def serve(jpeg, width, height, fps, host, port, stop, log):
    hello = handshake(width, height, fps)
    with socket.socket() as server:
        server.bind((host, port))
        server.listen(1)
        server.settimeout(0.25)
        log(f"[PC] Listening on {host}:{server.getsockname()[1]}")
        while not stop.is_set():
            try:
                client, address = server.accept()
            except socket.timeout:
                continue
            with client:
                client.settimeout(2)
                client.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
                try:
                    client.sendall(hello)
                    log(f"[PC] Client connected: {address[0]} (display not yet verified)")
                    log(f"[PC] Sending {width}x{height} @ {fps}fps")
                    start = time.monotonic()
                    next_frame = start
                    number = 0
                    report_start = start
                    report_count = 0
                    while not stop.is_set():
                        now = time.monotonic()
                        if stop.wait(max(0, next_frame - now)):
                            break
                        now = time.monotonic()
                        client.sendall(frame(number, int((now - start) * 1_000_000), jpeg))
                        number += 1
                        report_count += 1
                        if now - report_start >= 1:
                            log(f"[PC] {width}x{height}; sent {number}; {report_count/(now-report_start):.1f} fps")
                            report_start, report_count = now, 0
                        # No catch-up burst after a slow write.
                        next_frame = max(next_frame + 1 / fps, time.monotonic())
                except OSError as error:
                    log(f"[PC] Client disconnected: {error}")
        log("[PC] Stopped")


class SenderUI:
    def __init__(self, root):
        self.root = root
        self.events = queue.SimpleQueue()
        self.stop = threading.Event()
        self.worker = None
        self.path = tk.StringVar()
        root.title("VCAM · Stage 1 image sender")
        tk.Button(root, text="Choose image", command=self.choose).grid(row=0, column=0)
        tk.Entry(root, textvariable=self.path, width=55).grid(row=0, column=1)
        self.fields = {}
        for row, (name, default) in enumerate([
            ("Bind IPv4", "0.0.0.0"), ("Port", "5055"),
            ("Width", "1080"), ("Height", "1920"), ("FPS", "30")
        ], 1):
            tk.Label(root, text=name).grid(row=row, column=0)
            field = tk.Entry(root)
            field.insert(0, default)
            field.grid(row=row, column=1, sticky="w")
            self.fields[name] = field
        tk.Button(root, text="Start", command=self.start).grid(row=6, column=0)
        tk.Button(root, text="Stop", command=self.stop.set).grid(row=6, column=1, sticky="w")
        self.status = tk.StringVar(value="Stopped · trusted LAN only · no encryption/authentication")
        tk.Label(root, textvariable=self.status).grid(row=7, columnspan=2)
        root.protocol("WM_DELETE_WINDOW", self.close)
        root.after(100, self.poll)

    def choose(self):
        path = filedialog.askopenfilename(filetypes=[("Images", "*.png *.jpg *.jpeg *.bmp"), ("All files", "*.*")])
        if path:
            self.path.set(path)

    def start(self):
        if self.worker and self.worker.is_alive():
            return
        try:
            width, height, fps, port = [int(self.fields[k].get()) for k in ("Width", "Height", "FPS", "Port")]
            handshake(width, height, fps)
            if not 1 <= port <= 65535:
                raise ValueError("Port must be 1..65535")
            jpeg = encode_image(self.path.get(), width, height)
            frame(0, 0, jpeg)
        except Exception as error:
            messagebox.showerror("Cannot start", str(error))
            return
        host = self.fields["Bind IPv4"].get().strip()
        self.stop.clear()
        def run():
            try:
                serve(jpeg, width, height, fps, host, port, self.stop, self.events.put)
            except Exception as error:
                self.events.put(f"[PC] Error: {error}")
        self.worker = threading.Thread(target=run, daemon=True)
        self.worker.start()

    def poll(self):
        while not self.events.empty():
            line = self.events.get()
            print(line, flush=True)
            self.status.set(line)
        self.root.after(100, self.poll)

    def close(self):
        self.stop.set()
        if self.worker and self.worker.is_alive():
            self.root.after(100, self.close)
        else:
            self.root.destroy()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", help="Preselect an image")
    parser.add_argument("--headless", action="store_true", help="Stream without opening the UI")
    args = parser.parse_args()
    if args.headless:
        if not args.image:
            parser.error("--headless requires --image")
        stop = threading.Event()
        try:
            serve(encode_image(args.image, 1080, 1920), 1080, 1920, 30,
                  "0.0.0.0", 5055, stop, lambda line: print(line, flush=True))
        except KeyboardInterrupt:
            stop.set()
    else:
        root = tk.Tk()
        ui = SenderUI(root)
        if args.image:
            ui.path.set(args.image)
        root.mainloop()
