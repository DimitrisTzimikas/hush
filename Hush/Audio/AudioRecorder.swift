import AVFoundation
import os

private let logger = Logger(subsystem: "com.hush.app", category: "AudioRecorder")

final class AudioRecorder {
    private let engine = AVAudioEngine()
    private let buffer = AudioBuffer()
    private let sampleRate: Double = 16000
    private var isRecording = false

    func start() {
        guard !isRecording else { return }
        buffer.reset()

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            logger.error("Failed to create target audio format")
            return
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            logger.error("Failed to create audio converter")
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] pcmBuffer, _ in
            guard let self else { return }

            let frameCount = AVAudioFrameCount(
                Double(pcmBuffer.frameLength) * self.sampleRate / inputFormat.sampleRate
            )
            guard frameCount > 0,
                  let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount)
            else { return }

            var error: NSError?
            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return pcmBuffer
            }

            if let err = error {
                logger.error("Conversion error: \(err)")
                return
            }

            if let channelData = convertedBuffer.floatChannelData {
                let samples = Array(UnsafeBufferPointer(
                    start: channelData[0],
                    count: Int(convertedBuffer.frameLength)
                ))
                self.buffer.append(samples)
            }
        }

        do {
            try engine.start()
            isRecording = true
            logger.info("Recording started")
        } catch {
            logger.error("Failed to start audio engine: \(error)")
        }
    }

    func stop() -> [Float] {
        guard isRecording else { return [] }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        let audio = buffer.drain()
        logger.info("Recording stopped: \(audio.count) samples")
        return audio
    }
}
