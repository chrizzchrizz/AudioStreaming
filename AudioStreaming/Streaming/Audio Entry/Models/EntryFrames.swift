//
//  Created by Dimitrios Chatzieleftheriou on 24/10/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import AudioToolbox
import Foundation

final class EntryFramesState {
    var queued: Int = 0
    var played: Int = 0
    var lastFrameQueued: Int = -1

    /// Gapless info from the packet table, in source frames: encoder delay (priming), audio frames
    /// (valid) and padding (remainder). Decoders output priming and remainder like audio; both are
    /// dropped. `validFrames` is nil when the stream has no packet table info.
    var primingFrames: Int = 0
    var validFrames: Int?
    var remainderFrames: Int = 0
    /// Output frames decoded since the start of the stream, including dropped ones.
    /// nil after a seek, where the decoded position is not exact.
    var decoded: Int? = 0
}

/// Pure gapless trimming math, in output frames.
enum GaplessTrim {
    /// The part of a decoded chunk to keep.
    /// - parameter decodedStart: Output frames decoded before this chunk
    /// - parameter framesCount: Frames in this chunk
    /// - parameter ratio: Output sample rate / source sample rate
    /// - Returns: The frames to skip at the start of the chunk and the frames to keep after them
    static func keptRange(decodedStart: Int, framesCount: Int, primingFrames: Int, validFrames: Int, ratio: Double) -> (leading: Int, kept: Int) {
        let keepFrom = Int((Double(primingFrames) * ratio).rounded())
        let keepTo = Int((Double(primingFrames + validFrames) * ratio).rounded())
        let first = max(decodedStart, keepFrom)
        let last = min(decodedStart + framesCount, keepTo)
        guard last > first else { return (0, 0) }
        return (first - decodedStart, last - first)
    }

    /// Encoder delay of LAME, also used by ffmpeg's libmp3lame. The decoder delay (529) is already
    /// compensated by the AudioToolbox MP3 decoder.
    static let lameMp3PrimingFrames = 576

    /// The priming frames to assume for a stream without packet table info.
    /// A live MP3 stream (no length, e.g. transcoded by the server on the fly) has no Xing/Info header,
    /// so the decoder outputs the encoder delay as silence. MP3 files with a known length keep their
    /// untrimmed behavior since their encoder is unknown.
    static func assumedPrimingFrames(formatID: AudioFormatID, sourceLength: Int, hasPacketTableInfo: Bool) -> Int {
        guard !hasPacketTableInfo, sourceLength <= 0, formatID == kAudioFormatMPEGLayer3 else { return 0 }
        return lameMp3PrimingFrames
    }

    /// The most end padding an MP3 encoder adds (one frame plus the encoder delay), in source frames.
    static let maxAssumedMp3PaddingFrames = 1152 + 576

    /// Below this peak level (about -60 dBFS) a frame counts as the silent padding of the encoder.
    static let paddingSilenceThreshold: Float = 0.001

    /// The silent frames at the end of a stream without padding info, to be dropped as padding.
    /// - parameter peakFromEnd: The peak level of the frame `n` frames before the end (0 is the last frame)
    /// - parameter limit: The most frames to drop
    static func trailingSilentFrames(limit: Int, peakFromEnd: (Int) -> Float) -> Int {
        var count = 0
        while count < limit, peakFromEnd(count) < paddingSilenceThreshold {
            count += 1
        }
        return count
    }

    /// The output frames of end padding to drop, limited to what is still unplayed and buffered.
    static func trailingFramesToDrop(remainderFrames: Int, ratio: Double, notPlayedFrames: Int, usedFrames: Int) -> Int {
        let outputRemainder = Int((Double(remainderFrames) * ratio).rounded())
        return max(0, min(outputRemainder, notPlayedFrames, usedFrames))
    }
}
