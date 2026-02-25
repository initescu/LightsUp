//
//  AppStyle.swift
//  LightsUp
//
//  Centralised style tokens. Use in SwiftUI modifiers:
//    .foregroundStyle(Color.appAccent)   ← explicit type required for Color tokens
//    .font(.appBody)                     ← implicit member lookup works for Font tokens
//

import SwiftUI

// MARK: - Colour tokens
// Use explicit `Color.appXxx` syntax — implicit member lookup (.appXxx) does not
// resolve reliably for custom Color extensions in all foregroundStyle() contexts.

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
// All fonts use system monospaced — the app's sole typeface.

extension Font {
    static var appBody: Font        { .system(.body,     design: .monospaced) }
    static var appBodyBold: Font    { .system(.body,     design: .monospaced).weight(.semibold) }
    static var appCaption: Font     { .system(.caption,  design: .monospaced) }
    static var appCaptionBold: Font { .system(.caption,  design: .monospaced).weight(.semibold) }
    static var appCallout: Font     { .system(.callout,  design: .monospaced) }
    static var appHeadline: Font    { .system(.headline, design: .monospaced) }
    static var appTitle3: Font      { .system(.title3,   design: .monospaced) }
    static var appTitle2: Font      { .system(.title2,   design: .monospaced) }
    static var appTitleBold: Font   { .system(.title2,   design: .monospaced, weight: .bold) }
    static var appTitle: Font       { .system(.title,    design: .monospaced) }
    static var appPopupTitle: Font  { .system(size: 40,  weight: .bold, design: .monospaced) }
}
