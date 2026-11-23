#if DEBUG
import Foundation

extension SeedSet {
    /// #370's Quiet Hours page check: the approved mockup's three schedules, 10:00 PM–7:00 AM Sun to
    /// Thu and 11:00 PM–8:00 AM Fri and Sat, both on, and 6:30 PM–9:00 PM Tue and Thu, off. Written
    /// as `SeedSettingText` reads them. No reminders; `clean` puts back the schedules the phone had.
    static let quietHoursPage = SeedSet(
        name: "quiet-hours-page",
        settings: [.quietHours: "22:00-07:00 SU,MO,TU,WE,TH on; 23:00-08:00 FR,SA on; 18:30-21:00 TU,TH off"],
        reminders: []
    )

    /// #468's phone check: the page's schedules, with How Quiet Hours Work unseen, so opening the
    /// Quiet Hours page opens it. `clean` puts back the schedules and the tutorial's flag the phone had.
    static let quietHoursTutorial = SeedSet(
        name: "quiet-hours-tutorial",
        settings: [.quietHours: quietHoursPage.settings[.quietHours] ?? "", .quietHoursTutorial: SeedSeenText.unseen],
        reminders: []
    )

    /// The same check's empty state: no schedules. `clean` puts back the schedules the phone had.
    static let quietHoursNone = SeedSet(
        name: "quiet-hours-none",
        settings: [.quietHours: ""],
        reminders: []
    )

    /// #499's holding banner check: one schedule on every day from 12:00 AM to 11:59 PM, so it runs
    /// whenever the check is loaded, and a few reminders so Now, My Day and Reminders have content.
    /// Quiet Now, the schedule's switch and a schedule made by hand for the minute it starts are the
    /// check's own steps; `clean` puts back the schedules the phone had and turns Quiet Now off.
    static let quietHoursBanner = SeedSet(
        name: "quiet-hours-banner",
        settings: [.quietHours: "00:00-23:59 SU,MO,TU,WE,TH,FR,SA on"],
        reminders: [
            SeedReminder(id: SeedReminder.fixedID(67), title: "Stretch break", dueIn: -10 * 60, createdAgo: 2 * 86400),
            SeedReminder(id: SeedReminder.fixedID(68), title: "Book the car service", dueIn: 2 * 86400, createdAgo: 86400),
        ]
    )

    /// The same check's empty states: the schedule, and no reminders.
    static let quietHoursBannerEmpty = SeedSet(
        name: "quiet-hours-banner-empty",
        settings: [.quietHours: "00:00-23:59 SU,MO,TU,WE,TH,FR,SA on"],
        reminders: []
    )
}
#endif
