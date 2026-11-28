import SwiftUI

/// The Setup tab: how to put the word where it's meant to be read, on the Home
/// Screen, the Lock Screen, and the watch face. The widgets and complications are
/// the point of the app, and nothing in iOS tells people they exist.
///
/// Widget names here must match each widget's `configurationDisplayName`.
struct SetupView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("""
                        The Dew Point is made to be glanced at, not opened. Put the word on your Lock Screen, Home \
                        Screen, or watch face, and it stays current on its own.
                        """)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }

                StepsSection(
                    title: "Lock Screen",
                    steps: [
                        """
                            Unlock with Face ID or Touch ID but stay on the Lock Screen, then touch and hold it until \
                            **Customize** appears. Tap it, then tap **Lock Screen**.
                            """,
                        "Tap **Add Widgets**, or the widgets already there, and choose **The Dew Point**.",
                        "To show the word beside the date, tap the date above the time and choose **The Dew Point**.",
                    ],
                    footer: """
                        The widget area fits four circles, two rectangles, or one rectangle and two circles. To \
                        make room, tap the minus button on a widget you don't need.
                        """
                ) {
                    WidgetRow(name: "Comfort Word", detail: "The word, as a rectangle or beside the date.")
                    WidgetRow(name: "Coming Up", detail: "The next word changes, like “3 PM Steamy”.")
                    WidgetRow(name: "Dew Point", detail: "The dew point, in a circle.")
                    WidgetRow(name: "Air Quality", detail: "The air quality index, in a circle.")
                }

                StepsSection(
                    title: "Home Screen",
                    steps: [
                        "Touch and hold an empty spot on the Home Screen until the apps jiggle.",
                        "Tap **Edit** in the top corner, then tap **Add Widget**.",
                        "Search for **The Dew Point**, tap it, swipe to the size you want, and tap **Add Widget**.",
                    ],
                    footer: "The medium size also shows the word changes coming up today."
                )

                // iPads can't pair with a watch.
                if UIDevice.current.userInterfaceIdiom == .phone {
                    watchSection
                }

                Section {
                    Text("""
                        Widgets and complications refresh about every half hour, using your location from the last \
                        time you opened the app. After you travel, open the app to update them.
                        """)
                        .listRowBackground(Palette.surface)
                    Text("Air quality comes from EPA AirNow and covers the United States.")
                        .listRowBackground(Palette.surface)
                    Text("Words you set in the Words tab show up in the widgets and on your watch too.")
                        .listRowBackground(Palette.surface)
                } header: {
                    Text("Good to know")
                }
                .foregroundStyle(.secondary)
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Setup")
        }
    }

    private var watchSection: some View {
        StepsSection(
            title: "Apple Watch",
            steps: [
                """
                    The watch app usually installs on its own. If it's missing, open the **Watch** app on this \
                    iPhone, scroll to **Available Apps** at the bottom of **My Watch**, and tap **Install** next \
                    to The Dew Point.
                    """,
                "Open The Dew Point on your watch and allow location access.",
                """
                    In the **Watch** app, tap a face under **My Faces**, tap a slot under **Complications**, and \
                    choose **The Dew Point**.
                    """,
                """
                    Or on the watch, touch and hold the face, tap **Edit**, swipe to the complications, tap a \
                    slot, and choose **The Dew Point**.
                    """,
            ],
            footer: """
                Comfort Word needs a wide slot, like the large one on the Modular faces, or a line of text. Dew \
                Point fits round and corner slots, and Air Quality fits any slot. Requires watchOS 26.
                """
        ) {
            WidgetRow(name: "Comfort Word", detail: "The word, in a wide slot or a line of text.")
            WidgetRow(name: "Dew Point", detail: "The dew point, in a round or corner slot.")
            WidgetRow(name: "Air Quality", detail: "The air quality index, in any slot.")
        }
    }
}

/// A titled list of numbered steps, optionally followed by the widgets that place
/// offers.
private struct StepsSection<Widgets: View>: View {
    let title: String
    let steps: [LocalizedStringKey]
    var footer: LocalizedStringKey?
    @ViewBuilder var widgets: Widgets

    var body: some View {
        Section {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.body.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Color.accentColor)
                    Text(step)
                }
                .listRowBackground(Palette.surface)
            }
            widgets
                .listRowBackground(Palette.surface)
        } header: {
            Text(title)
        } footer: {
            if let footer {
                Text(footer)
            }
        }
    }
}

extension StepsSection where Widgets == EmptyView {
    init(title: String, steps: [LocalizedStringKey], footer: LocalizedStringKey) {
        self.init(title: title, steps: steps, footer: footer) { EmptyView() }
    }
}

/// One widget or complication by the name it has in the gallery.
private struct WidgetRow: View {
    let name: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name)
                .font(.body.weight(.semibold))
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#if DEBUG
#Preview {
    SetupView()
        .preferredColorScheme(.dark)
}
#endif
