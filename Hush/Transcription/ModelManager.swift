import Foundation
import os

private let logger = Logger(subsystem: "com.hush.app", category: "ModelManager")

enum ModelManager {
    static func modelPath() -> String? {
        if let path = Bundle.main.path(forResource: "ggml-base", ofType: "bin") {
            logger.info("Model found in bundle: \(path)")
            return path
        }

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelDir = appSupport.appendingPathComponent("Hush/models")
        let modelPath = modelDir.appendingPathComponent("ggml-base.bin").path

        if FileManager.default.fileExists(atPath: modelPath) {
            logger.info("Model found in Application Support: \(modelPath)")
            return modelPath
        }

        logger.error("Model not found. Please place ggml-base.bin in the app bundle or ~/Library/Application Support/Hush/models/")
        return nil
    }
}
