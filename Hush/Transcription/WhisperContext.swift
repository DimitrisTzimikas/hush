import Foundation
import os

private let logger = Logger(subsystem: "com.hush.app", category: "WhisperContext")

final class WhisperContext {
    private let context: OpaquePointer

    init?(modelPath: String) {
        // Set Metal shader path to app bundle Resources
        if let resourcePath = Bundle.main.resourcePath {
            setenv("GGML_METAL_PATH_RESOURCES", resourcePath, 1)
        }
        var params = whisper_context_default_params()
        // Disable GPU to avoid Metal shader loading issues — CPU is fast enough on Apple Silicon
        params.use_gpu = false
        guard let ctx = whisper_init_from_file_with_params(modelPath, params) else {
            logger.error("Failed to load whisper model from: \(modelPath)")
            return nil
        }
        self.context = ctx
        logger.info("Whisper model loaded from: \(modelPath)")
    }

    deinit {
        whisper_free(context)
    }

    func detectLanguage(samples: [Float]) -> String {
        var audio = samples
        let targetLength = 16000 * 30
        if audio.count < targetLength {
            audio.append(contentsOf: [Float](repeating: 0, count: targetLength - audio.count))
        } else if audio.count > targetLength {
            audio = Array(audio.prefix(targetLength))
        }

        var probs = [Float](repeating: 0, count: Int(whisper_lang_max_id() + 1))

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.offset_ms = 0
        params.n_threads = 4

        audio.withUnsafeBufferPointer { ptr in
            whisper_pcm_to_mel(context, ptr.baseAddress!, Int32(audio.count), Int32(params.n_threads))
        }

        whisper_lang_auto_detect(context, 0, Int32(params.n_threads), &probs)

        let enIdx = Int(whisper_lang_id("en"))
        let elIdx = Int(whisper_lang_id("el"))

        let enProb = probs[enIdx]
        let elProb = probs[elIdx]

        let detected = enProb >= elProb ? "en" : "el"
        logger.info("Language detection: en=\(String(format: "%.2f", enProb)) el=\(String(format: "%.2f", elProb)) -> \(detected)")
        return detected
    }

    func transcribe(samples: [Float], language: String) -> String {
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.n_threads = 4
        params.no_timestamps = true
        params.single_segment = false

        let langCStr = language.withCString { strdup($0) }
        params.language = UnsafePointer(langCStr)

        let result = samples.withUnsafeBufferPointer { ptr -> Int32 in
            whisper_full(context, params, ptr.baseAddress!, Int32(samples.count))
        }

        free(langCStr)

        guard result == 0 else {
            logger.error("Whisper transcription failed with code: \(result)")
            return ""
        }

        let segmentCount = whisper_full_n_segments(context)
        var text = ""
        for i in 0..<segmentCount {
            if let cStr = whisper_full_get_segment_text(context, i) {
                text += String(cString: cStr)
            }
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
