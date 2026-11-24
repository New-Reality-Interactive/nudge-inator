import NudgeEngine
import SwiftUI

/// One day back or forward on My Day (#375): Previous Day, Next Day and the swipe.
enum MyDayMove {
    case previous
    case next

    /// The day it goes to, or `nil` past the range's end.
    func target(from shown: MyDayShownDay) -> CalendarDay? {
        switch self {
        case .previous: shown.previous
        case .next: shown.next
        }
    }
}

extension MyDayShownDay {
    /// The day label as it shows: Yesterday or Tomorrow before the date, or the date alone.
    var labelText: Text {
        Text(label)
    }
}

/// Previous Day or Next Day (#375): a chevron, dimmed at its end of the range. In the bar
/// (landscape) the bar draws its glass and size; beside the date it is a glass circle of its own.
struct MyDayDayButton: View {
    let move: MyDayMove
    let shown: MyDayShownDay
    let action: (MyDayMove) -> Void

    var body: some View {
        Button {
            action(move)
        } label: {
            Label {
                switch move {
                case .previous:
                    Text("Previous Day", comment: "My Day: the button (a back arrow) before the day label that shows the day before. Dimmed on the first day My Day can show.")
                case .next:
                    Text("Next Day", comment: "My Day: the button (a forward arrow) after the day label that shows the day after. Dimmed 7 days ahead, the last day My Day can show.")
                }
            } icon: {
                Image(systemName: move == .previous ? "chevron.backward" : "chevron.forward")
            }
        }
        .disabled(move.target(from: shown) == nil)
    }
}

/// Previous Day and Next Day together, for the bar in landscape, where they share one glass
/// capsule as the tutorials' Back and Next do.
struct MyDayDayButtons: View {
    let shown: MyDayShownDay
    let move: (MyDayMove) -> Void

    var body: some View {
        MyDayDayButton(move: .previous, shown: shown, action: move)
        MyDayDayButton(move: .next, shown: shown, action: move)
    }
}

/// The day label under the title between Previous Day and Next Day, each on the side it moves
/// toward (the developer's call on the phone, 2026-11-23, over the approved pair at the label's
/// end). The label wraps; the buttons keep their place. It sits above the pages and stays still
/// while they move, as in the mockup.
struct MyDayDayRow: View {
    let shown: MyDayShownDay
    let move: (MyDayMove) -> Void

    var body: some View {
        HStack(spacing: Design.Spacing.s2) {
            circle(.previous)
            shown.labelText
                .font(.subheadline)
                // The secondary grey on every day, as Now's date line and 1.5.0's My Day have it (the
                // developer's call, 2026-11-23): one color, so no day looks dimmed beside another.
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .notAHeading()
            circle(.next)
        }
        .textCase(nil)
    }

    private func circle(_ direction: MyDayMove) -> some View {
        MyDayDayButton(move: direction, shown: shown, action: move)
            // Icon only on screen; VoiceOver still reads the title.
            .labelStyle(.iconOnly)
            .buttonStyle(GlassCircleButtonStyle())
            // Bar-sized at every text size, as the bar's buttons are, so the date keeps its room;
            // at the larger sizes a long press shows the name and chevron large instead (Apple's
            // `accessibilityShowsLargeContentViewer` docs: for items that must stay small).
            .dynamicTypeSize(...DynamicTypeSize.large)
            .accessibilityShowsLargeContentViewer {
                MyDayDayButton(move: direction, shown: shown, action: move)
                    .labelStyle(.titleAndIcon)
            }
    }
}

/// A chevron in a glass circle at least DESIGN.md's 44 pt, the least size of every button: the
/// glass button style drew the circle at about 34 pt. Dimmed, in the tertiary label color, when the
/// button is.
private struct GlassCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GlassCircle(label: configuration.label, isPressed: configuration.isPressed)
    }
}

private struct GlassCircle<Content: View>: View {
    let label: Content
    let isPressed: Bool

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        label
            .font(.body.weight(.semibold))
            .foregroundStyle(isEnabled ? Color(uiColor: .label) : Color(uiColor: .tertiaryLabel))
            .frame(minWidth: Design.Spacing.rowMin, minHeight: Design.Spacing.rowMin)
            .contentShape(Circle())
            .glassEffect(isEnabled ? .regular.interactive() : .regular, in: Circle())
            .opacity(isPressed ? 0.6 : 1)
    }
}

#if DEBUG
#Preview("Day row") {
    let engine = Engine.myDayPreview()
    MyDayDayRow(shown: MyDayShownDay(engine: engine, asked: engine.day(engine.today, movedBy: 1))) { _ in }
        .padding()
}
#endif
