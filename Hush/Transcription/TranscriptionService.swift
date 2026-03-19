import Foundation
import os

private let logger = Logger(subsystem: "com.hush.app", category: "TranscriptionService")

actor TranscriptionService {
    private var whisperContext: WhisperContext?

    func loadModel() {
        guard let path = ModelManager.modelPath() else {
            logger.error("Cannot load model — path not found")
            return
        }
        whisperContext = WhisperContext(modelPath: path)
        if whisperContext != nil {
            logger.info("Whisper model loaded successfully")
        }
    }

    func transcribe(audio: [Float], language: String?) -> String {
        guard let ctx = whisperContext else {
            logger.error("Whisper context not initialized")
            return ""
        }

        guard !audio.isEmpty else { return "" }

        let lang: String
        if let forced = language {
            lang = forced
        } else {
            lang = ctx.detectLanguage(samples: audio)
        }

        logger.info("Transcribing with language: \(lang)")
        let text = ctx.transcribe(samples: audio, language: lang)
        logger.info("Transcription result: '\(text)'")
        return text
    }
}
