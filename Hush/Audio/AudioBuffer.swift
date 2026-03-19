import Foundation

final class AudioBuffer: @unchecked Sendable {
    private var chunks: [[Float]] = []
    private let lock = NSLock()

    func append(_ samples: [Float]) {
        lock.lock()
        chunks.append(samples)
        lock.unlock()
    }

    func drain() -> [Float] {
        lock.lock()
        let result = chunks.flatMap { $0 }
        chunks.removeAll()
        lock.unlock()
        return result
    }

    func reset() {
        lock.lock()
        chunks.removeAll()
        lock.unlock()
    }
}
