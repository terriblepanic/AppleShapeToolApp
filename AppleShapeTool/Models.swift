//
//  Models.swift
//  AppleShapeTool
//

import SwiftUI
import AppKit
import Combine

// MARK: - Corner Style

enum CornerStyle: String, CaseIterable, Identifiable, Codable, Equatable {
    case continuous        = "Squircle (Continuous)"
    case circular          = "Classic (Circular)"
    case capsuleContinuous = "Capsule · Continuous"
    case capsuleCircular   = "Capsule · Circular"

    var id: String { rawValue }

    var isCapsule: Bool {
        self == .capsuleContinuous || self == .capsuleCircular
    }
}

// MARK: - Border Style

enum BorderStyle: String, CaseIterable, Identifiable, Codable, Equatable {
    case none           = "Нет"
    case separator      = "Separator"
    case gradient       = "Gradient"
    case glassHighlight = "Glass"

    var id: String { rawValue }
    var hasWidth: Bool { self != .none }

    var hint: String {
        switch self {
        case .none:           return "Без обводки"
        case .separator:      return "Тонкая системная обводка"
        case .gradient:       return "Светлый градиент сверху вниз"
        case .glassHighlight: return "Блик — как на iOS-стекле"
        }
    }
}

// MARK: - Codable Color

struct ShapeColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    static let fillDefault = ShapeColor(red: 0.11, green: 0.11, blue: 0.12)
    static let borderDefault = ShapeColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.18)

    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(_ color: Color) {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? .black
        red = Double(nsColor.redComponent)
        green = Double(nsColor.greenComponent)
        blue = Double(nsColor.blueComponent)
        alpha = Double(nsColor.alphaComponent)
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    var hexString: String {
        let r = Int((red * 255).rounded())
        let g = Int((green * 255).rounded())
        let b = Int((blue * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Shape Spec

struct ShapeSpec: Identifiable, Codable, Equatable {
    var id = UUID()
    var label: String = ""
    var width: CGFloat = 200
    var height: CGFloat = 200
    var style: CornerStyle = .continuous
    var radiusRatio: CGFloat = 0.22
    var fillColor: ShapeColor = .fillDefault
    var borderStyle: BorderStyle = .none
    var borderColor: ShapeColor = .borderDefault
    var borderWidth: CGFloat = 1.0

    var cornerRadius: CGFloat { min(width, height) * radiusRatio }

    var safeFilename: String {
        let base = label.isEmpty
            ? "\(style.rawValue)_\(Int(width))x\(Int(height))"
            : label
        let safe = base
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines).joined(separator: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        return safe.isEmpty ? "shape_\(Int(width))x\(Int(height))" : safe
    }

    var cgPath: CGPath {
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        switch style {
        case .continuous:
            return Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous).cgPath
        case .circular:
            return Path(roundedRect: rect, cornerRadius: cornerRadius, style: .circular).cgPath
        case .capsuleContinuous:
            return Capsule(style: .continuous).path(in: rect).cgPath
        case .capsuleCircular:
            return Capsule(style: .circular).path(in: rect).cgPath
        }
    }
}

// MARK: - Shape Group

struct ShapeGroup: Identifiable, Codable {
    var id = UUID()
    var name: String = "Group"
    var shapes: [ShapeSpec] = []
}

// MARK: - Presets

struct ShapePreset: Identifiable {
    let id = UUID()
    let label: String
    let spec: ShapeSpec
}

let applePresets: [ShapePreset] = [
    .init(label: "App Icon · iOS",   spec: .init(label: "ios_app_icon",   width: 256, height: 256, style: .continuous,        radiusRatio: 0.2237)),
    .init(label: "App Icon · macOS", spec: .init(label: "macos_app_icon", width: 256, height: 256, style: .continuous,        radiusRatio: 0.2232)),
    .init(label: "Widget Small",     spec: .init(label: "widget_small",   width: 180, height: 180, style: .continuous,        radiusRatio: 0.2310)),
    .init(label: "Widget Large",     spec: .init(label: "widget_large",   width: 360, height: 180, style: .continuous,        radiusRatio: 0.1155)),
    .init(label: "iOS Button",       spec: .init(label: "ios_button",     width: 320, height:  56, style: .continuous,        radiusRatio: 0.2237)),
    .init(label: "Alert / Sheet",    spec: .init(label: "alert_sheet",    width: 290, height: 180, style: .continuous,        radiusRatio: 0.0880)),
    .init(label: "Card",             spec: .init(label: "card",           width: 360, height: 200, style: .continuous,        radiusRatio: 0.1100)),
    .init(label: "Dock background",  spec: .init(label: "dock_bg",        width: 520, height:  82, style: .continuous,        radiusRatio: 0.3400)),
    .init(label: "Notification",     spec: .init(label: "notification",   width: 350, height:  80, style: .continuous,        radiusRatio: 0.1600)),
    .init(label: "Search Bar",       spec: .init(label: "search_bar",     width: 300, height:  44, style: .capsuleContinuous, radiusRatio: 0.5)),
    .init(label: "Pill Tag",         spec: .init(label: "pill_tag",       width: 100, height:  32, style: .capsuleContinuous, radiusRatio: 0.5)),
    .init(label: "Classic Pill",     spec: .init(label: "classic_pill",   width: 200, height:  48, style: .capsuleCircular,   radiusRatio: 0.5)),
]

// MARK: - Store

final class ShapeStore: ObservableObject {
    @Published var groups: [ShapeGroup] = [ShapeGroup(name: "My Shapes")]
    @Published var selectedShapeID: UUID?

    init() {}

    func addGroup() {
        let g = ShapeGroup(name: "Group \(groups.count + 1)")
        groups.append(g)
        selectedShapeID = nil
    }

    func deleteGroup(id: UUID) {
        if let g = groups.first(where: { $0.id == id }),
           let sid = selectedShapeID,
           g.shapes.contains(where: { $0.id == sid }) {
            selectedShapeID = nil
        }
        groups.removeAll { $0.id == id }
    }

    @discardableResult
    func addShape(to groupID: UUID? = nil, from preset: ShapePreset? = nil) -> UUID? {
        let targetID = groupID ?? groups.first?.id
        guard let gid = targetID,
              let idx = groups.firstIndex(where: { $0.id == gid }) else { return nil }
        var spec = preset?.spec ?? ShapeSpec()
        spec.id = UUID()
        groups[idx].shapes.append(spec)
        selectedShapeID = spec.id
        return spec.id
    }

    func deleteShape(id: UUID) {
        for i in groups.indices {
            groups[i].shapes.removeAll { $0.id == id }
        }
        if selectedShapeID == id { selectedShapeID = nil }
    }

    func updateShape(_ spec: ShapeSpec) {
        for i in groups.indices {
            if let j = groups[i].shapes.firstIndex(where: { $0.id == spec.id }) {
                groups[i].shapes[j] = spec
                return
            }
        }
    }

    var currentShape: ShapeSpec? {
        guard let sid = selectedShapeID else { return nil }
        return groups.flatMap(\.shapes).first { $0.id == sid }
    }

    func groupID(for shapeID: UUID) -> UUID? {
        groups.first { $0.shapes.contains { $0.id == shapeID } }?.id
    }

    func exportAll() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.message = "Выбери папку для экспорта"
        panel.prompt = "Экспортировать сюда"
        guard panel.runModal() == .OK, let dest = panel.url else { return }
        SVGExporter.exportGroups(groups, to: dest)
    }
}

// MARK: - Preview Background Engine

enum PreviewBackgroundMode: String, CaseIterable, Identifiable, Codable {
    case light        = "Светлый"
    case dark         = "Тёмный"
    case checkerboard = "Шахматка"
    case custom       = "Цветной"

    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .checkerboard: return "square.grid.2x2"
        case .custom: return "paintpalette.fill"
        }
    }
}

extension Color {
    /// Генерирует более светлые/тёмные оттенки для авто-градиентов в стиле macOS
    func adjusted(brightness: CGFloat, saturation: CGFloat = 0) -> Color {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? .black
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        nsColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(NSColor(
            hue: max(0, min(1, h)),
            saturation: max(0, min(1, s + saturation)),
            brightness: max(0, min(1, b + brightness)),
            alpha: a
        ))
    }

    /// Извлекает RGB-компоненты цвета
    var rgbComponents: (r: Double, g: Double, b: Double, a: Double) {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? .black
        return (Double(nsColor.redComponent), Double(nsColor.greenComponent), Double(nsColor.blueComponent), Double(nsColor.alphaComponent))
    }

    /// Извлекает HSB-компоненты цвета
    var hsbComponents: (h: Double, s: Double, b: Double, a: Double) {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? .black
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        nsColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (Double(h), Double(s), Double(b), Double(a))
    }

    /// Безопасный парсинг цвета из строки HEX
    static func fromHex(_ hex: String) -> Color? {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if str.hasPrefix("#") { str.removeFirst() }
        if str.count == 6 {
            var rgbValue: UInt64 = 0
            Scanner(string: str).scanHexInt64(&rgbValue)
            let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
            let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
            let b = Double(rgbValue & 0x0000FF) / 255.0
            return Color(red: r, green: g, blue: b)
        }
        return nil
    }

    /// Превращает текущий цвет в строку HEX формата #RRGGBB
    var toHex: String {
        let comps = self.rgbComponents
        let r = Int((comps.r * 255).rounded())
        let g = Int((comps.g * 255).rounded())
        let b = Int((comps.b * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
