import Foundation
import NudgeEngine

/// A page of the How Alarm Sounds Work sheet (#467, the mockups `2026-11-20-tutorial-sheets` and
/// `2026-11-20-alarm-sounds-tutorial-leads`), in the order the sheet shows them. It never opens by itself: alarm sounds have no screen of their own
/// to reach first, so only its Settings row opens it.
enum AlarmSoundsTutorialPage: TutorialPage {
    case pickYourDefaultSound
    case changeYourReminders
    case whenItPlays

    static let title = LocalizedStringResource("How Alarm Sounds Work", comment: "How Alarm Sounds Work: the sheet's title, and the Settings row under Tutorials that opens it.")

    var heading: LocalizedStringResource {
        switch self {
        case .pickYourDefaultSound:
            LocalizedStringResource("Pick Your Default Sound", comment: "How Alarm Sounds Work: the first page's heading, about Settings' Default Alarm Sound.")
        case .changeYourReminders:
            LocalizedStringResource("Change Your Reminders", comment: "How Alarm Sounds Work: the second page's heading, about changing the sound of reminders already made.")
        case .whenItPlays:
            LocalizedStringResource("When It Plays", comment: "How Alarm Sounds Work: the last page's heading, about which nudges ring with the sound.")
        }
    }

    /// The mockup's art, with the real SF Symbols. Settings' row and the sound are named with the
    /// screens' own strings, so the two can't be worded apart.
    var art: [TutorialArtPiece] {
        switch self {
        case .pickYourDefaultSound:
            [.pill(symbol: "speaker.wave.2", text: DefaultAlarmSoundPage.title)]
        case .changeYourReminders:
            [.pill(symbol: "bell", text: LocalizedStringResource("Wake Up", comment: "How Alarm Sounds Work, Change Your Reminders: the picture's example reminder title, beside a bell, before the sound it rings with. Keep it short: the picture keeps it to one line.")),
             .arrow,
             .pill(symbol: "speaker.wave.2", text: AlarmSound.chime.title)]
        case .whenItPlays:
            // The alarm alone: a notification never plays the sound (#467's phone check).
            [.pill(symbol: "alarm", text: LocalizedStringResource("Alarm", comment: "Nudge card: the next nudge rings as an alarm. Also How Alarm Sounds Work's picture of a nudge that rings as an alarm."))]
        }
    }

    /// A reminder and its sound keep to one line each, so their text stops growing (the mockup).
    var artStopsGrowingAtLargestStandardSize: Bool { self == .changeYourReminders }

    var content: TutorialContent {
        switch self {
        case .pickYourDefaultSound:
            .points(lead: LocalizedStringResource("In Settings, under Default Alarm Sound, choose the sound your alarms ring with.", comment: "How Alarm Sounds Work, Pick Your Default Sound: the line under the heading. Default Alarm Sound is the Settings row."), [
                TutorialPoint(symbol: "play",
                              title: LocalizedStringResource("Tap a tone to hear it", comment: "How Alarm Sounds Work, Pick Your Default Sound: the row about the preview a tone plays when tapped."),
                              text: LocalizedStringResource("Choose from six tones, from the gentle Chime to the insistent Siren. Default Alarm is iOS's own sound, which apps can't play, so you'll hear it when an alarm rings.", comment: "How Alarm Sounds Work, Pick Your Default Sound: under \"Tap a tone to hear it\". Chime, Siren and Default Alarm are alarm sound names.")),
                TutorialPoint(symbol: "plus",
                              title: LocalizedStringResource("New reminders start with it", comment: "How Alarm Sounds Work, Pick Your Default Sound: the row about which reminders take the Default Alarm Sound."),
                              text: LocalizedStringResource("So do reminders someone sends you. The reminders you already have keep their sounds.", comment: "How Alarm Sounds Work, Pick Your Default Sound: under \"New reminders start with it\".")),
            ])
        case .changeYourReminders:
            .points(lead: LocalizedStringResource("Change the sound of reminders you already have, all at once or one at a time.", comment: "How Alarm Sounds Work, Change Your Reminders: the line under the heading."), [
                TutorialPoint(symbol: "square.stack",
                              title: DefaultAlarmSoundPage.useForAllTitle,
                              text: LocalizedStringResource("Settings › Default Alarm Sound. Gives every reminder you have the default, including ones people sent you.", comment: "How Alarm Sounds Work, Change Your Reminders: under Use for All Reminders. Settings › Default Alarm Sound is where it is.")),
                TutorialPoint(symbol: "pencil",
                              title: LocalizedStringResource("Sound on the form", comment: "How Alarm Sounds Work, Change Your Reminders: the row about the reminder form's Sound row."),
                              text: LocalizedStringResource("Edit a reminder and change its Sound, under Break Through Focus, even while it's nudging.", comment: "How Alarm Sounds Work, Change Your Reminders: under \"Sound on the form\". Sound is the form's row and Break Through Focus its switch.")),
                TutorialPoint(symbol: "list.bullet.rectangle",
                              title: LocalizedStringResource("Named on its details", comment: "How Alarm Sounds Work, Change Your Reminders: the row about the reminder details naming its sound."),
                              text: LocalizedStringResource("A reminder's details name its sound, under Break Through Focus.", comment: "How Alarm Sounds Work, Change Your Reminders: under \"Named on its details\". Break Through Focus is the details' row.")),
            ], footnote: LocalizedStringResource("A reminder someone sends you rings with the sound chosen on your iPhone.", comment: "How Alarm Sounds Work, Change Your Reminders: the note under the rows."))
        case .whenItPlays:
            .points(lead: LocalizedStringResource("Your sound plays only when a nudge rings as an alarm.", comment: "How Alarm Sounds Work, When It Plays: the line under the heading."), [
                TutorialPoint(symbol: "alarm",
                              title: LocalizedStringResource("Only alarms play it", comment: "How Alarm Sounds Work, When It Plays: the row about which nudges ring as alarms."),
                              text: LocalizedStringResource("A Firm reminder's Urgent nudges with Break Through Focus on, and every Relentless nudge, ring as alarms.", comment: "How Alarm Sounds Work, When It Plays: under \"Only alarms play it\". Firm and Relentless are strengths, Urgent a nudge's urgency.")),
                TutorialPoint(symbol: "bell.slash",
                              title: LocalizedStringResource("Some reminders never ring", comment: "How Alarm Sounds Work, When It Plays: the row about reminders that send no alarms."),
                              text: LocalizedStringResource("A Gentle reminder, or a Firm one with Break Through Focus off, never rings, so it has no Sound row.", comment: "How Alarm Sounds Work, When It Plays: under \"Some reminders never ring\". Gentle and Firm are strengths; Sound is the form's row.")),
                TutorialPoint(symbol: "bell",
                              title: LocalizedStringResource("Other nudges sound standard", comment: "How Alarm Sounds Work, When It Plays: the row about nudges that use the standard notification sound."),
                              text: LocalizedStringResource("Notifications use the standard sound, and so does every nudge while Alarms are off in iOS Settings.", comment: "How Alarm Sounds Work, When It Plays: under \"Other nudges sound standard\". Alarms is the app's permission in iOS Settings.")),
            ])
        }
    }
}
