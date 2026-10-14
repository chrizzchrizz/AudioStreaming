//
//  Created by Dimitrios Chatzieleftheriou on 24/10/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

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
