import SwiftUI

/// The words Settings shows for each status (DESIGN.md: a status always has a word, never color
/// alone), kept apart from the values so their tests need no strings.
extension NotificationsStatus {
    var text: Text {
        switch self {
        case .on: Text("On", comment: "Settings: status of the Notifications row when notifications and Time Sensitive are allowed.")
        case .timeSensitiveOff: Text("On · Time Sensitive off", comment: "Settings: status of the Notifications row when notifications are allowed but Time Sensitive is turned off.")
        case .off: Text("Off", comment: "Settings: status of the Notifications row when notifications are turned off.")
        }
    }
}

extension AlarmsStatus {
    var text: Text {
        switch self {
        case .on: Text("On", comment: "Settings: status of the Alarms row when alarms are allowed.")
        case .off: Text("Off", comment: "Settings: status of the Alarms row when alarms are turned off.")
        case .notSet: Text("Not Set", comment: "Settings: status of the Alarms row before the person has been asked about alarms.")
        }
    }
}

extension FooterSentence {
    var text: Text {
        switch self {
        case .normalIsOrdinary:
            Text("Normal nudges arrive as ordinary notifications, which a Focus can hold.", comment: "Settings: footer under the Nudges rows.")
        case .highIsTimeSensitive:
            Text("For a reminder with Break Through Focus on, High nudges are Time Sensitive, so they get through a Focus.", comment: "Settings: footer under the Nudges rows, when Time Sensitive is on.")
        case .highIsOrdinary:
            Text("For a reminder with Break Through Focus on, High nudges come as ordinary notifications, because Time Sensitive is off.", comment: "Settings: footer under the Nudges rows, when Time Sensitive is off.")
        case .urgentRingsAsAlarms:
            Text("Urgent nudges ring as alarms, even in silent mode and in every Focus.", comment: "Settings: footer under the Nudges rows, when alarms are allowed.")
        case .urgentIsTimeSensitive:
            Text("Alarms are off, so Urgent nudges come as Time Sensitive notifications instead, which silent mode can mute.", comment: "Settings: footer under the Nudges rows, when alarms are off but Time Sensitive is on.")
        case .urgentIsOrdinary:
            Text("Urgent nudges come as ordinary notifications, which silent mode can mute and a Focus can hold.", comment: "Settings: footer under the Nudges rows, when neither alarms nor Time Sensitive can deliver Urgent nudges.")
        case .relentlessIsUrgent:
            Text("Every Relentless nudge is Urgent.", comment: "Settings: footer under the Nudges rows, after the sentence on how Urgent nudges arrive.")
        case .allowInFocus:
            Text("To get every nudge during a Focus, allow \(Bundle.appDisplayName) in that Focus. Nudges vibrate when your iPhone's settings allow it.", comment: "Settings: footer under the Nudges rows. The placeholder is the app's name.")
        case .changeInSettings:
            Text("Change these in iOS Settings.", comment: "Settings: last line of the footer under the Nudges rows.")
        }
    }
}
