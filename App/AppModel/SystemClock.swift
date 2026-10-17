import Foundation
import NudgeEngine

/// The real time.
struct SystemClock: EngineClock {
    var now: Date { .now }
}
