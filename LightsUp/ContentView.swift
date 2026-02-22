//
//  ContentView.swift
//  LightsUp
//

import SwiftUI

// Reusable button style for all menu rows: hover highlight, no default chrome.
struct MenuRowStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
            )
            .onHover { isHovered = $0 }
    }
}

struct ContentView: View {
    private let popup = PopupWindowController()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("LightsUp")
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            // Bottom action bar
            HStack(spacing: 0) {
                Button("Test Popup") {
                    popup.show()
                }
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .buttonStyle(MenuRowStyle())

                Divider().frame(height: 20)

                SettingsLink {
                    Text("Settings...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .buttonStyle(MenuRowStyle())
            }
        }
        .frame(width: 280)
    }
}
