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

    /// The side the new day slides in from: a later day from the trailing side.
    var edge: Edge {
        switch self {
        case .previous: .leading
        case .next: .trailing
        }
    }
}

extension MyDayShownDay {
    /// The day label as it shows: Yesterday or Tomorrow before the date, or the formatter's date as
    /// it is.
    var labelText: Text {
        labelSentence.map { Text($0) } ?? Text(verbatim: longDate)
    }
}

/// Previous Day and Next Day (#375), glass chevrons as the tutorials' Back and Next are. Each is
/// dimmed at its end of the range. In the bar (landscape) the bar draws their glass; beside the
/// day label the caller gives them the glass button style.
struct MyDayDayButtons: View {
    let shown: MyDayShownDay
    let move: (MyDayMove) -> Void

    var body: some View {
        Button {
            move(.previous)
        } label: {
            Label {
                Text("Previous Day", comment: "My Day: the button (a back arrow) beside the day label that shows the day before. Dimmed on the first day My Day can show.")
            } icon: {
                Image(systemName: "chevron.backward")
            }
        }
        .disabled(shown.previous == nil)
        Button {
            move(.next)
        } label: {
            Label {
                Text("Next Day", comment: "My Day: the button (a forward arrow) beside the day label that shows the day after. Dimmed 7 days ahead, the last day My Day can show.")
            } icon: {
                Image(systemName: "chevron.forward")
            }
        }
        .disabled(shown.next == nil)
    }
}

/// The day label under the title with Previous Day and Next Day at its trailing end (the
/// developer's call, 2026-11-23). The label wraps; the buttons keep their place. On another day
/// the label is in the label color, not the secondary one, so it reads as a choice. It sits in
/// the list's header, so it slides with the day it names (the developer's answer to question 3).
struct MyDayDayRow: View {
    let shown: MyDayShownDay
    let move: (MyDayMove) -> Void

    var body: some View {
        HStack(spacing: Design.Spacing.s2) {
            shown.labelText
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: shown.isToday ? .secondaryLabel : .label))
                .frame(maxWidth: .infinity, alignment: .leading)
                .notAHeading()
            GlassEffectContainer {
                HStack(spacing: Design.Spacing.s2) {
                    MyDayDayButtons(shown: shown, move: move)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            }
        }
        .textCase(nil)
    }
}

/// My Day's sideways swipe (#375): left to the next day, right to the previous, mirrored for right
/// to left. The page follows the drag, and past either end gives a little and springs back. A drag
/// that starts on a Nudging row is that row's Done swipe, so the two never both move (the mockup's
/// rule, a phone check), and a mostly vertical one is the list's scroll.
struct MyDayDaySwipe: ViewModifier {
    let shown: MyDayShownDay
    /// Where each Nudging row is now, in `space`.
    let nudgingRows: MyDayRowFrames
    let space: String
    let move: (MyDayMove) -> Void

    @Environment(\.layoutDirection) private var layoutDirection
    /// What the drag in progress is, and how far the page follows it. Gesture state, so a drag the
    /// system cancels resets it, which `onEnded` wouldn't.
    @GestureState private var drag = Drag.undecided

    private enum Drag: Equatable {
        case undecided
        case day(offset: CGFloat)
        case other

        var offset: CGFloat {
            if case .day(let offset) = self { offset } else { 0 }
        }
    }

    /// How far a drag goes before it moves a day, as the mockup's `DAY_SWIPE_COMMIT`.
    private static let commitDistance: CGFloat = 80

    func body(content: Content) -> some View {
        content
            .offset(x: drag.offset)
            .animation(.spring, value: drag == .undecided)
            // Beside the list's own scrolling and the rows' swipe actions, not over them: apps built
            // with the iOS 26 SDK give a simultaneous gesture the same priority as the view's own
            // (iOS and visionOS 26 release notes, 155581361).
            .simultaneousGesture(swipe)
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .named(space))
            .updating($drag) { value, drag, _ in
                if drag == .undecided {
                    let sideways = abs(value.translation.width) > abs(value.translation.height)
                    drag = sideways && !nudgingRows.contains(value.startLocation) ? .day(offset: 0) : .other
                }
                guard case .day = drag else { return }
                let width = value.translation.width
                drag = .day(offset: canMove(width) ? width : width / 4)
            }
            .onEnded { value in
                let width = value.translation.width
                guard abs(width) > Self.commitDistance, abs(width) > abs(value.translation.height),
                      !nudgingRows.contains(value.startLocation), canMove(width) else { return }
                move(direction(of: width))
            }
    }

    private func direction(of width: CGFloat) -> MyDayMove {
        let towardNext = layoutDirection == .rightToLeft ? width > 0 : width < 0
        return towardNext ? .next : .previous
    }

    private func canMove(_ width: CGFloat) -> Bool {
        direction(of: width).target(from: shown) != nil
    }
}

/// Where the Nudging rows are, for the swipe's one question: did a drag start on one? A reference
/// the view doesn't observe, since the frames change on every frame of a scroll and nothing on
/// screen depends on them (`onGeometryChange`'s docs warn against state updates that often).
final class MyDayRowFrames {
    private var frames: [String: CGRect] = [:]

    func set(_ frame: CGRect?, for id: String) {
        frames[id] = frame
    }

    /// Drops the rows that are gone.
    func keep(_ ids: Set<String>) {
        frames = frames.filter { ids.contains($0.key) }
    }

    func contains(_ point: CGPoint) -> Bool {
        frames.values.contains { $0.contains(point) }
    }
}

#if DEBUG
#Preview("Day row") {
    let engine = Engine.myDayPreview()
    List {
        Section {
            Text(verbatim: "Rows")
        } header: {
            MyDayDayRow(shown: MyDayShownDay(engine: engine, asked: engine.day(engine.today, movedBy: 1))) { _ in }
        }
    }
}
#endif
