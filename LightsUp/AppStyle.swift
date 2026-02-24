//
//  AppStyle.swift
//  LightsUp
//
//  Centralised style tokens. Use in SwiftUI modifiers:
//    .foregroundStyle(.appAccent)
//    .font(.appBody)
//

import SwiftUI

// MARK: - Colour tokens
// Computed vars with explicit return types allow implicit member lookup
// to resolve correctly in .foregroundStyle() / .background() contexts.

extension Color {
    static var appAccent: Color        { .orange }
    static var appOngoingRow: Color    { .orange.opacity(0.12) }
    static var appHoverRow: Color      { .primary.opacity(0.08) }
    static var appPressedIcon: Color   { .primary.opacity(0.16) }
    static var appPopupScrim: Color    { .black.opacity(0.85) }
    static var appPopupText: Color     { .white.opacity(0.7) }
    static var appPopupStroke: Color   { .white.opacity(0.3) }
    static var appTooltipStroke: Color { .orange.opacity(0.5) }
}

// MARK: - Font tokens

extension Font {
    static var appBody: Font        { .system(.body,    design: .monospaced) }
    static var appCaption: Font     { .system(.caption, design: .monospaced) }
    static var appCaptionBold: Font { .system(.caption, design: .monospaced).weight(.semibold) }
    static var appTitle2: Font      { .system(.title2,  design: .monospaced) }
    static var appPopupTitle: Font  { .system(size: 40, weight: .bold, design: .monospaced) }
}
