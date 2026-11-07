import DevPocketCore
import SwiftUI

extension DevUtility {
    static let epochConverter = DevUtility(
        id: "epoch",
        name: "Epoch Converter",
        symbol: "clock.arrow.2.circlepath",
        summary: "Convert Unix timestamps to dates and back",
        keywords: ["unix", "timestamp", "time", "date", "iso", "milliseconds", "utc"],
        handles: [.timestamp],
        model: { EpochModel() },
        content: { EpochConverterView(model: $0) },
        controls: { EpochControls(model: $0) }
    )
}

final class EpochModel: ToolModel {
    enum Zone: String, CaseIterable, Identifiable {
        case local = "Local"
        case utc = "UTC"
        var id: Self { self }

        var timeZone: TimeZone {
            switch self {
            case .local: .current
            case .utc: TimeZone(identifier: "UTC")!
            }
        }
    }

    @Published var zone = Zone.local

    var parsed: Result<EpochParse, Error>? {
        input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : Result { try EpochTool.parse(input, timeZone: zone.timeZone) }
    }

    override var status: ToolStatus {
        switch parsed {
        case .none:
            return .idle("Showing the current time. Paste an epoch or a date to convert it.")
        case .failure(let error):
            return ToolStatus(kind: .error, text: error.localizedDescription)
        case .success(let parse):
            let text = parse.unit.map { "Read as Unix \($0.rawValue)" } ?? "Read as a date"
            return ToolStatus(kind: .ok, text: text, detail: relativeDate(parse.date))
        }
    }

    /// Epoch in → ISO date out; date in → epoch seconds out; nothing in →
    /// the current epoch, so ⌘⇧C is a quick "copy now".
    override var primaryOutput: String? {
        guard let parsed else { return EpochTool.epochString(Date(), unit: .seconds) }
        guard let parse = try? parsed.get() else { return nil }
        return parse.unit == nil
            ? EpochTool.epochString(parse.date, unit: .seconds)
            : EpochTool.iso8601(parse.date, timeZone: zone.timeZone)
    }

    override var copyLabel: String {
        (try? parsed?.get())?.unit == nil ? "Copy Epoch" : "Copy ISO Date"
    }
}

struct EpochControls: View {
    @ObservedObject var model: EpochModel

    var body: some View {
        HStack(spacing: 10) {
            Picker("Time zone", selection: $model.zone) {
                ForEach(EpochModel.Zone.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .help("Time zone for showing dates, and for reading dates typed without one")

            Button("Now") {
                model.input = EpochTool.epochString(Date(), unit: .seconds)
            }
            .help("Fill in the current epoch")
        }
    }
}

struct EpochConverterView: View {
    @ObservedObject var model: EpochModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Pane("Epoch or date") {
                CodeEditor(text: $model.input, placeholder: "1700000000 · 1700000000000 · 2023-11-14T22:13:20Z · now")
                    .frame(height: 56)
            } accessory: {
                InputActions(text: $model.input)
            }

            switch model.parsed {
            case .none:
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    // Whole seconds: the clock ticks once a second anyway.
                    let now = Date(timeIntervalSince1970: context.date.timeIntervalSince1970.rounded(.down))
                    ConversionTable(title: "Now", date: now, zone: model.zone.timeZone)
                }
            case .success(let parse):
                ConversionTable(
                    title: parse.unit.map { "From Unix \($0.rawValue)" } ?? "From date",
                    date: parse.date,
                    zone: model.zone.timeZone
                )
            case .failure:
                EmptyHint(symbol: "clock.badge.questionmark", text: "Try 1700000000, 1700000000000, 2023-11-14T22:13:20Z or “now”")
            }

            Spacer(minLength: 0)
        }
        .padding(14)
    }
}

private struct ConversionTable: View {
    let title: String
    let date: Date
    let zone: TimeZone

    private var rows: [(label: String, value: String)] {
        let utc = TimeZone(identifier: "UTC")!
        var human = Date.FormatStyle(date: .complete, time: .complete)
        human.timeZone = zone

        var rows = [
            ("Unix seconds", EpochTool.epochString(date, unit: .seconds)),
            ("Unix milliseconds", EpochTool.epochString(date, unit: .milliseconds)),
            ("ISO 8601 (UTC)", EpochTool.iso8601(date, timeZone: utc)),
        ]
        if zone.identifier != utc.identifier {
            rows.append(("ISO 8601 (\(zone.identifier))", EpochTool.iso8601(date, timeZone: zone)))
        }
        rows += [
            ("RFC 2822", EpochTool.rfc2822(date, timeZone: zone)),
            ("Readable", date.formatted(human)),
            ("Relative", relativeDate(date)),
        ]
        return rows
    }

    var body: some View {
        Pane(title) {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { Divider().padding(.leading, 12) }
                    ConversionRow(label: row.label, value: row.value)
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }
}

private struct ConversionRow: View {
    let label: String
    let value: String

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 170, alignment: .leading)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            IconButton("doc.on.doc", help: "Copy \(label)") { Clipboard.copy(value) }
                .opacity(isHovered ? 1 : 0.35)
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isHovered ? Color.primary.opacity(0.04) : .clear)
        .onHover { isHovered = $0 }
    }
}
