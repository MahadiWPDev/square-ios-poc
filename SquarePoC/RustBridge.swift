import Foundation
import SquareCorePOC

/// Swift side of the Phase 3 interoperability test.
///
/// The Rust square-core-poc library is linked into the app as an
/// XCFramework and imported here as the clang module SquareCorePOC.
/// Every call crosses the stable C ABI declared in
/// rust-poc/include/square_core_poc.h. No Android JNI entry point is
/// involved anywhere in the iOS target.
enum RustBridge {
    /// Version string of the linked Rust library, for example
    /// "square-core-poc 0.1.0". Proves at runtime that the app is
    /// really calling into the Rust static library.
    static func version() -> String {
        guard let cString = square_core_poc_version() else { return "unavailable" }
        return String(cString: cString)
    }

    /// Integrated loudness in LUFS of an interleaved 16 bit PCM
    /// buffer, measured by the Rust ebur128 implementation.
    /// Returns nil for empty input or an invalid measurement.
    static func loudness(samples: [Int16], channels: Int, sampleRate: Int) -> Double? {
        guard !samples.isEmpty, channels > 0, sampleRate > 0 else { return nil }
        let frameCount = samples.count / channels
        guard frameCount > 0 else { return nil }
        let value = samples.withUnsafeBufferPointer { buffer in
            square_core_poc_loudness_i16(buffer.baseAddress,
                                         UInt(frameCount),
                                         UInt32(channels),
                                         UInt32(sampleRate))
        }
        return value.isNaN ? nil : value
    }
}
