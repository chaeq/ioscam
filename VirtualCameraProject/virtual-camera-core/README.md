# Reserved for the next gate

No implementation yet. After the physical-device transport test passes, add FrameBuffer, PixelBufferConverter, SampleBufferFactory and VirtualCameraProvider. Intended APIs: getLatestPixelBuffer(), getNextSampleBuffer(), isPCStreamAvailable(). Keep network/decoder work away from capture queues. See ../docs/ARCHITECTURE.md.
