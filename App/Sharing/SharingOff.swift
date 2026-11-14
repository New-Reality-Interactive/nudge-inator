/// What turning Settings' Sharing switch off takes (#388).
enum SharingOff: Equatable {
    /// The reminders or the sharing store haven't been read, or the sharing store won't open: it may
    /// hold connections the other people would never hear were ended, so the switch can't turn off
    /// yet (#387).
    case notYet
    /// Nothing is connected, invited, sent or received, so nothing is deleted and it turns off with
    /// no confirmation.
    case atOnce
    /// The Turn Off Sharing sheet asks first, as every destructive action does, saying what goes.
    case confirm(SharingOffSummary)
}

/// What the Turn Off Sharing sheet says goes (the Turn Off Sharing mockup): the people disconnected
/// and the invites canceled, counted apart, and the reminders received, which its Remove or Keep
/// choice is about.
struct SharingOffSummary: Equatable {
    var connected: Int
    var invited: Int
    var received: Int
}
