import SwiftUI

struct GenresPickerButton: View {
    @Binding var selected: Set<String>
    @Binding var exclude: Bool
    @State private var popoverOpen = false

    private var label: String {
        if selected.isEmpty { return "Жанры" }
        if selected.count == 1 { return selected.first!.capitalized }
        return "Жанры (\(selected.count))"
    }

    var body: some View {
        Button {
            popoverOpen.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: exclude ? "minus.circle" : "tag")
                Text(label).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(selected.isEmpty ? Color.secondary.opacity(0.1) : Color.accentColor.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $popoverOpen, arrowEdge: .bottom) {
            popoverContent
        }
    }

    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("Исключить выбранные", isOn: $exclude)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                Spacer()
                Button("Сбросить") { selected.removeAll() }
                    .disabled(selected.isEmpty)
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(AnixartGenres.all, id: \.self) { genre in
                        Toggle(isOn: Binding(
                            get: { selected.contains(genre) },
                            set: { isOn in
                                if isOn { selected.insert(genre) } else { selected.remove(genre) }
                            }
                        )) {
                            Text(genre.capitalized)
                                .font(.callout)
                        }
                        .toggleStyle(.checkbox)
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(width: 240, height: 320)
        }
        .padding(12)
    }
}
