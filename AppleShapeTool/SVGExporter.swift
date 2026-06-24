//
//  SVGExporter.swift
//  AppleShapeTool
//

import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum SVGExporter {

    // MARK: - Настройки продакшена
    static var useCurrentColor: Bool = false // Заменять ли цвет на currentColor для веба
    static var makeResponsive: Bool = true  // Убирать ли жесткие width/height для адаптивности

    // MARK: - SVG String (Финальная веб-оптимизация)
    static func svgString(for spec: ShapeSpec) -> String {
        let d = pathData(from: spec.cgPath)
        let w = fmt(spec.width)
        let h = fmt(spec.height)
        let comment = spec.label.isEmpty ? spec.style.rawValue : spec.label
        let rInfo   = spec.style.isCapsule ? "" : " · r=\(Int(spec.cornerRadius))pt (\(Int(spec.radiusRatio * 100))%)"

        // Генерируем абсолютно уникальный ID на базе UUID сущности
        let uniqueID = spec.id.uuidString.lowercased().replacingOccurrences(of: "-", with: "_")
        let clipID = "clip_\(uniqueID)"

        let (gradDefs, strokeAttr, opacityAttr) = svgBorderMarkup(for: spec, uniqueID: uniqueID)
        
        // Формируем блок деdefinitions (градиенты + маска обрезки для внутреннего stroke)
        var defsElements: [String] = []
        if !gradDefs.isEmpty {
            defsElements.append(gradDefs)
        }
        if !strokeAttr.isEmpty {
            let clipPathMarkup = """
                <clipPath id="\(clipID)">
                  <path d="\(d)" />
                </clipPath>
            """
            defsElements.append(clipPathMarkup)
        }
        
        let defsBlock = defsElements.isEmpty ? "" : "\n  <defs>\n    " + defsElements.joined(separator: "\n    ") + "\n  </defs>"
        let borderPath = svgBorderPath(for: spec, d: d, strokeAttr: strokeAttr, opacityAttr: opacityAttr, clipID: clipID)

        let sizeAttributes = makeResponsive ? "" : "width=\"\(w)\" height=\"\(h)\" "
        let finalFillColor = useCurrentColor ? "currentColor" : spec.fillColor.hexString
        let safeName = spec.safeFilename

        return """
        <svg xmlns="http://www.w3.org/2000/svg"
             viewBox="0 0 \(w) \(h)"
             \(sizeAttributes)style="overflow: visible;"
             shape-rendering="geometricPrecision">\(defsBlock)
          <g id="\(safeName)" class="apple-shape-container" style="transform-origin: center;">
            <path id="\(safeName)_fill" 
                  class="shape-fill" 
                  d="\(d)" 
                  fill="\(finalFillColor)" 
                  fill-opacity="\(opacity(spec.fillColor))"
                  style="transform-origin: center; pointer-events: auto;"/>\(borderPath)
          </g>
        </svg>
        """
    }

    // MARK: - Border markup (С защитой от конфликтов ID)
    private static func svgBorderMarkup(for spec: ShapeSpec, uniqueID: String) -> (defs: String, strokeAttr: String, opacityAttr: String) {
        let gradID = "grad_\(uniqueID)"
        
        switch spec.borderStyle {
        case .none:
            return ("", "", "")
        case .separator:
            return ("", spec.borderColor.hexString, " stroke-opacity=\"\(opacity(spec.borderColor))\"")
        case .gradient:
            let grad = """
                <linearGradient id="\(gradID)" x1="0" y1="0" x2="0" y2="1" gradientUnits="objectBoundingBox">
                  <stop offset="0%"   stop-color="\(spec.borderColor.hexString)" stop-opacity="\(opacity(spec.borderColor, multiplier: 0.72))"/>
                  <stop offset="100%" stop-color="\(spec.borderColor.hexString)" stop-opacity="\(opacity(spec.borderColor, multiplier: 0.22))"/>
                </linearGradient>
            """
            return (grad, "url(#\(gradID))", "")
        case .glassHighlight:
            let grad = """
                <linearGradient id="\(gradID)" x1="0" y1="0" x2="0" y2="0.55" gradientUnits="objectBoundingBox">
                  <stop offset="0%"   stop-color="\(spec.borderColor.hexString)" stop-opacity="\(opacity(spec.borderColor, multiplier: 0.72))"/>
                  <stop offset="100%" stop-color="\(spec.borderColor.hexString)" stop-opacity="0"/>
                </linearGradient>
            """
            return (grad, "url(#\(gradID))", "")
        }
    }

    // MARK: - Валидный путь обводки с поддержкой vector-effect
    private static func svgBorderPath(for spec: ShapeSpec, d: String, strokeAttr: String, opacityAttr: String, clipID: String) -> String {
        guard !strokeAttr.isEmpty else { return "" }
        
        // Удваиваем толщину, так как внешняя половина линии будет обрезана по маске clip-path.
        // В итоге внутри фигуры останется ровно исходная толщина borderWidth.
        let strokeWidthStr = fmt(spec.borderWidth * 2)
        
        return """
        
            <path id="\(spec.safeFilename)_stroke" 
                  class="shape-stroke" 
                  d="\(d)" 
                  fill="none"
                  stroke="\(strokeAttr)" 
                  stroke-width="\(strokeWidthStr)"\(opacityAttr)
                  clip-path="url(#\(clipID))"
                  vector-effect="non-scaling-stroke"
                  style="transform-origin: center; pointer-events: none;"/>
        """
    }

    // MARK: - Export all groups
    static func exportGroups(_ groups: [ShapeGroup], to root: URL) {
        let fm = FileManager.default
        for group in groups {
            guard !group.shapes.isEmpty else { continue }
            let folder = root.appendingPathComponent(group.name.isEmpty ? "Group" : group.name)
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
            for spec in group.shapes {
                let url = folder.appendingPathComponent("\(spec.safeFilename).svg")
                try? svgString(for: spec).write(to: url, atomically: true, encoding: .utf8)
            }
        }
        NSWorkspace.shared.open(root)
    }

    // MARK: - Save single SVG
    static func saveSingle(_ spec: ShapeSpec) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(spec.safeFilename).svg"
        panel.allowedContentTypes = [.svg]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? svgString(for: spec).write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Save PNG с Умным Антиалиасингом
    @MainActor
    static func savePNG(_ spec: ShapeSpec, scale: CGFloat = 2.0) {
        let superScale = scale * 2.0
        let view = ShapeExportView(spec: spec)
        let renderer = ImageRenderer(content: view)
        renderer.scale = superScale

        guard let baseImage = renderer.nsImage else { return }
        let targetSize = NSSize(width: spec.width * scale, height: spec.height * scale)
        let finalImage = NSImage(size: targetSize)
        
        finalImage.lockFocus()
        if let context = NSGraphicsContext.current?.cgContext {
            context.interpolationQuality = .high
            context.setShouldAntialias(true)
            context.setAllowsAntialiasing(true)
        }
        
        baseImage.draw(in: NSRect(origin: .zero, size: targetSize),
                       from: NSRect(origin: .zero, size: baseImage.size),
                       operation: .copy,
                       fraction: 1.0)
        finalImage.unlockFocus()

        let scaleLabel = scale == floor(scale) ? "@\(Int(scale))x" : "@\(scale)x"
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(spec.safeFilename)\(scaleLabel).png"
        panel.allowedContentTypes = [.png]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let tiff   = finalImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data   = bitmap.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: url)
    }

    // MARK: - CGPath → SVG path data
    private static func pathData(from path: CGPath) -> String {
        var parts: [String] = []
        path.applyWithBlock { ptr in
            let el = ptr.pointee
            let p  = el.points
            switch el.type {
            case .moveToPoint: parts.append("M\(fmt(p[0].x)),\(fmt(p[0].y))")
            case .addLineToPoint: parts.append("L\(fmt(p[0].x)),\(fmt(p[0].y))")
            case .addQuadCurveToPoint: parts.append("Q\(fmt(p[0].x)),\(fmt(p[0].y)) \(fmt(p[1].x)),\(fmt(p[1].y))")
            case .addCurveToPoint: parts.append("C\(fmt(p[0].x)),\(fmt(p[0].y)) \(fmt(p[1].x)),\(fmt(p[1].y)) \(fmt(p[2].x)),\(fmt(p[2].y))")
            case .closeSubpath: parts.append("Z")
            @unknown default: break
            }
        }
        return parts.joined(separator: " ")
    }

    static func fmt(_ v: CGFloat) -> String { String(format: "%.4f", Double(v)) }
    private static func opacity(_ color: ShapeColor, multiplier: Double = 1.0) -> String {
        String(format: "%.3f", min(max(color.alpha * multiplier, 0), 1))
    }
}
