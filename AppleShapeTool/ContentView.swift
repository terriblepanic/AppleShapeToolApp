//
//  ContentView.swift
//  AppleShapeTool
//

import SwiftUI
import AppKit

// MARK: - CompactSlider
// Кастомный ползунок: заполненный трек + чистый thumb, без системного scroll-indicator артефакта

struct CompactSlider<V: BinaryFloatingPoint>: View {
    @Binding var value: V
    var range: ClosedRange<V>
    var step: V = 0

    @State private var isDragging = false

    private var fraction: Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        return max(0, min(1, Double(value - range.lowerBound) / Double(range.upperBound - range.lowerBound)))
    }

    var body: some View {
        GeometryReader { geo in
            let W        = geo.size.width
            let thumbD: CGFloat = 14
            let trackH: CGFloat = 4
            let usable   = max(1.0, W - thumbD)
            let thumbOff = CGFloat(fraction) * usable

            ZStack(alignment: .leading) {
                // Фоновый трек
                Capsule()
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: trackH)

                // Заполненная часть (от левого края до центра thumb)
                Capsule()
                    .fill(Color.accentColor.opacity(isDragging ? 1.0 : 0.82))
                    .frame(width: max(trackH, thumbOff + thumbD / 2), height: trackH)

                // Thumb
                Circle()
                    .fill(.white)
                    .overlay {
                        Circle()
                            .stroke(.black.opacity(0.06), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                    .frame(width: 20, height: 20)
                    .offset(x: thumbOff)
            }
            .frame(height: thumbD)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        isDragging = true
                        let x   = max(0.0, min(Double(drag.location.x - thumbD / 2), Double(usable)))
                        let raw = Double(range.lowerBound) + (x / Double(usable)) * Double(range.upperBound - range.lowerBound)
                        let clamped = max(Double(range.lowerBound), min(Double(range.upperBound), raw))
                        if step > 0 {
                            let stepped = (clamped / Double(step)).rounded() * Double(step)
                            value = V(max(Double(range.lowerBound), min(Double(range.upperBound), stepped)))
                        } else {
                            value = V(clamped)
                        }
                    }
                    .onEnded { _ in isDragging = false }
            )
        }
        .frame(height: 14)
    }
}

// MARK: - Root

struct ContentView: View {
    @EnvironmentObject var store: ShapeStore

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            if let shape = store.currentShape {
                ShapeEditorView(shapeID: shape.id)
                    .id(shape.id)
            } else {
                WelcomeView()
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Menu {
                    ForEach(applePresets) { preset in
                        Button(preset.label) {
                            let gid = store.currentShape.flatMap { store.groupID(for: $0.id) }
                            store.addShape(to: gid, from: preset)
                        }
                    }
                } label: {
                    Label("Добавить пресет", systemImage: "plus")
                }

                Button {
                    store.exportAll()
                } label: {
                    Label("Export All…", systemImage: "square.and.arrow.up")
                }
                .disabled(store.groups.allSatisfy { $0.shapes.isEmpty })
            }
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var store: ShapeStore

    var body: some View {
        List(selection: $store.selectedShapeID) {
            ForEach(store.groups) { group in
                Section {
                    ForEach(group.shapes) { shape in
                        ShapeRow(shape: shape)
                            .tag(shape.id)
                            .contextMenu {
                                Button("Удалить", role: .destructive) {
                                    store.deleteShape(id: shape.id)
                                }
                            }
                    }
                } header: {
                    GroupHeader(groupID: group.id)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button {
                    let gid = store.currentShape.flatMap { store.groupID(for: $0.id) }
                    store.addShape(to: gid)
                } label: {
                    Label("Новая форма", systemImage: "plus.circle")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    store.addGroup()
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Новая группа")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

struct GroupHeader: View {
    @EnvironmentObject var store: ShapeStore
    let groupID: UUID
    @State private var editing = false

    private var groupIndex: Int? {
        store.groups.firstIndex { $0.id == groupID }
    }

    var body: some View {
        if let gi = groupIndex {
            HStack(spacing: 4) {
                if editing {
                    TextField("Название", text: Binding(
                        get: { store.groups[gi].name },
                        set: { store.groups[gi].name = $0 }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .onSubmit { editing = false }
                } else {
                    Text(store.groups[gi].name)
                        .onTapGesture(count: 2) { editing = true }
                }
                Spacer()
                if store.groups.count > 1 {
                    Button {
                        store.deleteGroup(id: groupID)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ShapeRow: View {
    let shape: ShapeSpec
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(shape.label.isEmpty ? "\(Int(shape.width)) × \(Int(shape.height))" : shape.label)
                .font(.system(size: 13))
                .lineLimit(1)
            Text(shape.style.rawValue)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Welcome / Preset Gallery

struct WelcomeView: View {
    @EnvironmentObject var store: ShapeStore
    let columns = [GridItem(.adaptive(minimum: 150))]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apple Shape Tool")
                        .font(.title2.weight(.semibold))
                    Text("Добавь пресет или создай форму с нуля. Превью — нативный SwiftUI рендер, пиксель в пиксель с Apple.")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13))
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(applePresets) { preset in
                        PresetCard(preset: preset) {
                            store.addShape(from: preset)
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}

struct PresetCard: View {
    let preset: ShapePreset
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ShapeThumb(spec: preset.spec, maxW: 130, maxH: 80)
                    .frame(width: 130, height: 80)
                Text(preset.label)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.separator, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shape Editor

struct ShapeEditorView: View {
    let shapeID: UUID
    @EnvironmentObject var store: ShapeStore
    
    @State private var showFillColorPicker = false
    @State private var showBorderColorPicker = false

    @State private var spec = ShapeSpec()
    @State private var pngScale: CGFloat = 2.0
    @State private var keepsAspectRatio = false
    @State private var lockedAspectRatio: CGFloat = 1.0

    // Новые свойства состояния для продвинутого Preview
    @State private var bgMode: PreviewBackgroundMode = .light
    @State private var customBgColor: Color = Color(red: 0.29, green: 0.56, blue: 0.89) // Apple Blue
    @State private var showCustomBgColorPicker = false
    @State private var previewZoom: CGFloat = 1.0
    @State private var lastScaleReference: CGFloat = 1.0

    var body: some View {
        HSplitView {
            configPanel
                .frame(minWidth: 240, maxWidth: 300)
            previewPanel
                .frame(minWidth: 260)
        }
        .onAppear { load() }
        .onChange(of: shapeID) { load() }
        .onChange(of: spec) { _, new in
            store.updateShape(new)
        }
    }

    private func load() {
        if let s = store.currentShape {
            spec = s
            lockedAspectRatio = aspectRatio(for: s)
        }
    }

    // MARK: - Bindings (Включая старые)
    private var widthBinding: Binding<Double> { Binding(get: { Double(spec.width) }, set: { setWidth(CGFloat($0)) }) }
    private var heightBinding: Binding<Double> { Binding(get: { Double(spec.height) }, set: { setHeight(CGFloat($0)) }) }
    private var fillColorBinding: Binding<Color> { Binding(get: { spec.fillColor.color }, set: { spec.fillColor = ShapeColor($0) }) }
    private var borderColorBinding: Binding<Color> { Binding(get: { spec.borderColor.color }, set: { spec.borderColor = ShapeColor($0) }) }
    private var borderWidthDouble: Binding<Double> { Binding(get: { Double(spec.borderWidth) }, set: { spec.borderWidth = CGFloat($0) }) }

    private var sizeRange: ClosedRange<Double> { 1...2048 }
    private var sizeText: String { "\(Int(spec.width)) × \(Int(spec.height)) pt" }

    private func aspectRatio(for s: ShapeSpec) -> CGFloat { max(1, s.width) / max(1, s.height) }

    private func setWidth(_ value: CGFloat) {
        let w = clampedSize(value)
        spec.width = w
        if keepsAspectRatio { spec.height = clampedSize(w / max(lockedAspectRatio, 0.001)) }
        else { lockedAspectRatio = aspectRatio(for: spec) }
    }

    private func setHeight(_ value: CGFloat) {
        let h = clampedSize(value)
        spec.height = h
        if keepsAspectRatio { spec.width = clampedSize(h * max(lockedAspectRatio, 0.001)) }
        else { lockedAspectRatio = aspectRatio(for: spec) }
    }

    private func clampedSize(_ value: CGFloat) -> CGFloat { min(max(1, value), CGFloat(sizeRange.upperBound)) }

    // MARK: - Config Panel (Оставлена без изменений)
    var configPanel: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                // Метка
                pSection("Метка / имя файла") {
                    VStack(spacing: 0) {
                        pRow { TextField("modal_form", text: $spec.label).textFieldStyle(.plain) }
                        Divider().padding(.leading, 12)
                        pRow { Text("\(spec.safeFilename).svg").font(.system(size: 11, design: .monospaced)).foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle) }
                    }
                }
                // Размер
                pSection("Размер") {
                    VStack(spacing: 0) {
                        pRow {
                            HStack(spacing: 8) {
                                Label(sizeText, systemImage: "arrow.up.left.and.arrow.down.right").font(.system(size: 12, weight: .semibold).monospacedDigit()).foregroundStyle(.secondary)
                                Spacer()
                                Toggle(isOn: Binding(get: { keepsAspectRatio }, set: { v in keepsAspectRatio = v; lockedAspectRatio = aspectRatio(for: spec) })) { Image(systemName: keepsAspectRatio ? "lock.fill" : "lock.open") }.toggleStyle(.button).buttonStyle(.bordered).controlSize(.small)
                            }
                        }
                        Divider().padding(.leading, 12)
                        sizeRow(title: "Ширина", value: widthBinding)
                        Divider().padding(.leading, 12)
                        sizeRow(title: "Высота", value: heightBinding)
                    }
                }
                // Цвет
                pSection("Цвет") {
                    pRow {
                        HStack {
                            Text("Форма").font(.system(size: 13))
                            Spacer()
                            Button {
                                showFillColorPicker = true
                            } label: {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(fillColorBinding.wrappedValue)
                                    .frame(width: 44, height: 22)
                                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(.separator, lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: $showFillColorPicker, arrowEdge: .trailing) {
                                AppleCompactColorPicker(selection: fillColorBinding, supportsOpacity: true)
                            }
                        }
                    }
                }                // Стиль скругления
                pSection("Стиль скругления") { pRow { Picker("", selection: $spec.style) { ForEach(CornerStyle.allCases) { style in Text(style.rawValue).tag(style) } }.pickerStyle(.radioGroup).labelsHidden() } }
                // Радиус угла
                if !spec.style.isCapsule {
                    pSection("Радиус угла") {
                        VStack(spacing: 0) {
                            pRow {
                                HStack {
                                    Text("Значение").font(.system(size: 13)).foregroundStyle(.secondary)
                                    Spacer()
                                    HStack(spacing: 5) {
                                        Text("\(Int(spec.radiusRatio * 100))%").font(.system(size: 13, weight: .semibold).monospacedDigit())
                                        Text("· \(Int(spec.cornerRadius)) pt").font(.system(size: 12)).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Divider().padding(.leading, 12)
                            pRow { CompactSlider(value: $spec.radiusRatio, range: 0.04...0.50, step: 0.001) }
                            Divider().padding(.leading, 12)
                            pRow {
                                VStack(spacing: 6) {
                                    HStack(spacing: 6) { quickR("Alert", "8.8%", 0.088); quickR("Icon", "22.4%", 0.2237) }
                                    HStack(spacing: 6) { quickR("Dock", "34%", 0.34); quickR("Pill", "50%", 0.50) }
                                }
                            }
                        }
                    }
                }
                // Обводка
                pSection("Обводка") {
                    VStack(spacing: 0) {
                        pRow {
                            HStack {
                                Text("Стиль").font(.system(size: 13))
                                Spacer()
                                Picker("", selection: $spec.borderStyle) { ForEach(BorderStyle.allCases) { style in Text(style.rawValue).tag(style) } }.labelsHidden().frame(maxWidth: 134)
                            }
                        }
                        if spec.borderStyle.hasWidth {
                            Divider().padding(.leading, 12)
                            pRow {
                                HStack {
                                    Text("Цвет обводки").font(.system(size: 13))
                                    Spacer()
                                    Button {
                                        showBorderColorPicker = true
                                    } label: {
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .fill(borderColorBinding.wrappedValue)
                                            .frame(width: 44, height: 22)
                                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(.separator, lineWidth: 0.5))
                                    }
                                    .buttonStyle(.plain)
                                    .popover(isPresented: $showBorderColorPicker, arrowEdge: .trailing) {
                                        AppleCompactColorPicker(selection: borderColorBinding, supportsOpacity: true)
                                    }
                                }
                            }
                            Divider().padding(.leading, 12)
                            pRow { HStack { Text("Толщина").font(.system(size: 13)); Spacer(); Text("\(spec.borderWidth, specifier: "%.1f") pt").font(.system(size: 12).monospacedDigit()).foregroundStyle(.secondary) } }
                            Divider().padding(.leading, 12)
                            pRow { CompactSlider(value: borderWidthDouble, range: 0.5...8.0, step: 0.5) }
                            Divider().padding(.leading, 12)
                            pRow { Text(spec.borderStyle.hint).font(.system(size: 11)).foregroundStyle(.tertiary) }
                        }
                    }
                }
                // Экспорт
                pSection("Экспорт") {
                    VStack(spacing: 0) {
                        pRow { Button("Сохранить SVG…") { SVGExporter.saveSingle(spec) }.buttonStyle(.plain).foregroundStyle(Color.accentColor) }
                        Divider().padding(.leading, 12)
                        pRow {
                            HStack {
                                Text("Масштаб PNG").font(.system(size: 13))
                                Spacer()
                                Picker("", selection: $pngScale) { Text("@1×").tag(CGFloat(1)); Text("@2×").tag(CGFloat(2)); Text("@3×").tag(CGFloat(3)) }.pickerStyle(.menu).labelsHidden().frame(width: 70)
                            }
                        }
                        Divider().padding(.leading, 12)
                        pRow { Button("Сохранить PNG…") { SVGExporter.savePNG(spec, scale: pngScale) }.buttonStyle(.plain).foregroundStyle(Color.accentColor) }
                    }
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Panel Layout Helpers

    /// Секция с заголовком и карточкой-фоном (имитирует macOS grouped form)
    @ViewBuilder
    private func pSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !title.isEmpty {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            content()
                .frame(maxWidth: .infinity)
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.separator, lineWidth: 0.5))
        }
        .frame(maxWidth: .infinity)
    }

    /// Строка с отступами; содержимое занимает полную ширину
    @ViewBuilder
    private func pRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Строка с размером: label + TextField справа + CompactSlider ниже на полную ширину
    @ViewBuilder
    private func sizeRow(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                HStack(spacing: 4) {
                    TextField("", value: value, format: .number.precision(.fractionLength(0)))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 62)
                        .multilineTextAlignment(.trailing)
                    Text("pt")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                }
            }
            CompactSlider(value: value, range: sizeRange, step: 1.0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
    }

    /// Кнопка быстрого пресета радиуса — заметный размер, две строки текста
    @ViewBuilder
    private func quickR(_ name: String, _ pct: String, _ ratio: Double) -> some View {
        let selected = abs(spec.radiusRatio - ratio) < 0.001

        Button {
            spec.radiusRatio = ratio
        } label: {
            VStack(spacing: 6) {

                RoundedRectangle(
                    cornerRadius: 18 * ratio,
                    style: .continuous
                )
                .fill(.secondary.opacity(0.25))
                .frame(width: 28, height: 18)

                VStack(spacing: 2) {
                    Text(name)
                        .font(.system(size: 12, weight: .semibold))

                    Text(pct)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(
                    cornerRadius: 7,
                    style: .continuous
                )
                .fill(
                    selected
                        ? Color.accentColor.opacity(0.18)
                        : Color.secondary.opacity(0.08)
                )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - New Advanced Preview Panel

        var previewPanel: some View {
            GeometryReader { geo in
                let pad: CGFloat = 80
                let maxW = max(1, geo.size.width - pad)
                let maxH = max(1, geo.size.height - pad)
                
                // Базовый вписывающий коэффициент геометрии
                let baseScale = min(maxW / max(spec.width, 1), maxH / max(spec.height, 1), 1.5)
                let dw = spec.width * baseScale
                let dh = spec.height * baseScale

                ZStack(alignment: .top) {
                    // Слой 1: Динамическая система фонов
                    previewBackgroundLayer
                        .zIndex(0)

                    // Слой 2: Декоративная сетка точек (отображается везде, кроме цветного режима и шахматки)
                    if bgMode == .light || bgMode == .dark {
                        DotGrid()
                            .zIndex(1)
                    }

                    // Слой 3: Основное содержимое холста (Форма + Инфо-панель)
                    VStack(spacing: 0) {
                        Spacer()
                        
                        // Контейнер самой фигуры с изолированным зумом и жестами
                        ShapeThumb(spec: spec, maxW: dw, maxH: dh)
                            .frame(width: dw, height: dh)
                            .scaleEffect(previewZoom)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScaleReference
                                        lastScaleReference = value
                                        let newZoom = previewZoom * delta
                                        previewZoom = min(8.0, max(0.25, newZoom))
                                    }
                                    .onEnded { _ in
                                        lastScaleReference = 1.0
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                                    previewZoom = 1.0
                                }
                            }
                            .help("Двойной клик для сброса масштаба")
                        
                        Spacer()

                        // Инфо-чипсы внизу панели
                        HStack(spacing: 8) {
                            InfoChip("\(Int(spec.width)) × \(Int(spec.height)) pt")
                            if !spec.style.isCapsule {
                                InfoChip("r \(Int(spec.cornerRadius)) pt · \(Int(spec.radiusRatio * 100))%")
                            }
                            InfoChip(spec.style.rawValue)
                            if spec.borderStyle != .none {
                                InfoChip(String(format: "%@ %.1f pt", spec.borderStyle.rawValue, Double(spec.borderWidth)))
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    .zIndex(2)

                    // Слой 4: Навесной плавающий блок управления (в стиле системных оверлеев Apple)
                    previewControlBar
                        .zIndex(3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
        }

        // MARK: - Подкомпоненты Preview

        @ViewBuilder
        private var previewBackgroundLayer: some View {
            Group {
                switch bgMode {
                case .light:
                    LinearGradient(
                        colors: [Color.white, Color(nsColor: .windowBackgroundColor).opacity(0.4)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                case .dark:
                    LinearGradient(
                        colors: [Color(red: 0.14, green: 0.15, blue: 0.17), Color(red: 0.08, green: 0.09, blue: 0.10)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                case .checkerboard:
                    CheckerboardView()
                case .custom:
                    LinearGradient(
                        colors: [
                            customBgColor.adjusted(brightness: 0.16, saturation: -0.06),
                            customBgColor.adjusted(brightness: -0.14, saturation: 0.04)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
            }
        }

    private var previewControlBar: some View {
            HStack {
                // Переключатель режимов фона
                HStack(spacing: 2) {
                    ForEach(PreviewBackgroundMode.allCases) { mode in
                        if mode == .custom {
                            // Изолированная кнопка цветного режима для точного позиционирования Popover
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    bgMode = .custom
                                }
                                showCustomBgColorPicker = true
                            } label: {
                                Circle()
                                    .fill(customBgColor)
                                    .overlay {
                                        Circle()
                                            .stroke(bgMode == .custom ? Color.primary.opacity(0.6) : .white.opacity(0.45), lineWidth: 0.5)
                                    }
                                    .padding(5)
                                    .frame(width: 26, height: 22)
                                    .background {
                                        previewModeButtonBackground(isSelected: bgMode == .custom)
                                    }
                            }
                            .buttonStyle(.plain)
                            .help(mode.rawValue)
                            // Стрелка теперь выходит гарантированно из этой круглой кнопки!
                            .popover(isPresented: $showCustomBgColorPicker, arrowEdge: .bottom) {
                                AppleCompactColorPicker(selection: $customBgColor)
                            }
                        } else {
                            // Стандартные системные кнопки (Светлый, Тёмный, Шахматка)
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    bgMode = mode
                                }
                            } label: {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(bgMode == mode ? Color.primary : .secondary)
                                    .frame(width: 26, height: 22)
                                    .background {
                                        previewModeButtonBackground(isSelected: bgMode == mode)
                                    }
                            }
                            .buttonStyle(.plain)
                            .help(mode.rawValue)
                        }
                    }
                }
                .padding(3)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(.separator, lineWidth: 0.5)
                )

                Spacer()

                // Инструменты масштабирования (Оставлены без изменений)
                HStack(spacing: 4) {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            previewZoom = max(0.25, previewZoom - 0.1)
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .disabled(previewZoom <= 0.25)

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            previewZoom = 1.0
                        }
                    } label: {
                        Text("\(Int(previewZoom * 100))%")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .frame(minWidth: 42)
                    }
                    .buttonStyle(.plain)
                    .help("Сбросить масштаб до 100%")

                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            previewZoom = min(8.0, previewZoom + 0.1)
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .disabled(previewZoom >= 8.0)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(.separator, lineWidth: 0.5)
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    
    @ViewBuilder
        private func previewModeButtonBackground(isSelected: Bool) -> some View {
            if isSelected {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(.background.secondary)
                    .shadow(color: .black.opacity(0.08), radius: 1, y: 0.5)
            }
        }
    }
    
// MARK: - Shape Thumbnail

/// Нативный SwiftUI рендер + border overlay.
struct ShapeThumb: View {
    let spec: ShapeSpec
    var maxW: CGFloat
    var maxH: CGFloat

    private var scale: CGFloat {
        min(maxW / max(spec.width, 1), maxH / max(spec.height, 1))
    }
    private var sw: CGFloat { spec.width * scale }
    private var sh: CGFloat { spec.height * scale }
    private var scaledRadius: CGFloat { spec.cornerRadius * scale }
    private var scaledBorderWidth: CGFloat { max(0.5, spec.borderWidth * scale) }

    var body: some View {
        ZStack {
            fillShape.frame(width: sw, height: sh)
            if spec.borderStyle.hasWidth {
                borderOverlay.frame(width: sw, height: sh)
            }
        }
        .frame(width: maxW, height: maxH)
    }

    @ViewBuilder private var fillShape: some View {
        switch spec.style {
        case .continuous:
            RoundedRectangle(cornerRadius: scaledRadius, style: .continuous).fill(spec.fillColor.color)
        case .circular:
            RoundedRectangle(cornerRadius: scaledRadius, style: .circular).fill(spec.fillColor.color)
        case .capsuleContinuous:
            Capsule(style: .continuous).fill(spec.fillColor.color)
        case .capsuleCircular:
            Capsule(style: .circular).fill(spec.fillColor.color)
        }
    }

    private var borderPaint: AnyShapeStyle {
        switch spec.borderStyle {
        case .none:
            return AnyShapeStyle(Color.clear)
        case .separator:
            return AnyShapeStyle(spec.borderColor.color)
        case .gradient:
            return AnyShapeStyle(LinearGradient(
                stops: [
                    .init(color: spec.borderColor.color.opacity(0.72), location: 0.0),
                    .init(color: spec.borderColor.color.opacity(0.22), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            ))
        case .glassHighlight:
            return AnyShapeStyle(LinearGradient(
                stops: [
                    .init(color: spec.borderColor.color.opacity(0.72), location: 0.0),
                    .init(color: spec.borderColor.color.opacity(0.00), location: 0.55)
                ],
                startPoint: .top, endPoint: .bottom
            ))
        }
    }

    @ViewBuilder private var borderOverlay: some View {
        switch spec.style {
        case .continuous:
            RoundedRectangle(cornerRadius: scaledRadius, style: .continuous)
                .strokeBorder(borderPaint, lineWidth: scaledBorderWidth)
        case .circular:
            RoundedRectangle(cornerRadius: scaledRadius, style: .circular)
                .strokeBorder(borderPaint, lineWidth: scaledBorderWidth)
        case .capsuleContinuous:
            Capsule(style: .continuous)
                .strokeBorder(borderPaint, lineWidth: scaledBorderWidth)
        case .capsuleCircular:
            Capsule(style: .circular)
                .strokeBorder(borderPaint, lineWidth: scaledBorderWidth)
        }
    }
}

// MARK: - Shape Export View (для ImageRenderer)

struct ShapeExportView: View {
    let spec: ShapeSpec
    var body: some View {
        ShapeThumb(spec: spec, maxW: spec.width, maxH: spec.height)
            .frame(width: spec.width, height: spec.height)
            .background(Color.clear)
    }
}

// MARK: - Helpers

struct InfoChip: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.background.secondary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.separator, lineWidth: 0.5))
    }
}

struct DotGrid: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 24
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                var y: CGFloat = 0
                while y <= size.height {
                    path.addEllipse(in: CGRect(x: x - 0.7, y: y - 0.7, width: 1.4, height: 1.4))
                    y += step
                }
                x += step
            }
            ctx.fill(path, with: .color(.secondary.opacity(0.15)))
        }
        .allowsHitTesting(false)
    }
}

struct CheckerboardView: View {
    var body: some View {
        Canvas { ctx, size in
            let boxSize: CGFloat = 12
            for x in stride(from: 0, to: size.width, by: boxSize) {
                for y in stride(from: 0, to: size.height, by: boxSize) {
                    let isEven = Int((x / boxSize) + (y / boxSize)) % 2 == 0
                    let rect = CGRect(x: x, y: y, width: boxSize, height: boxSize)
                    ctx.fill(Path(rect), with: .color(isEven ? Color.primary.opacity(0.03) : Color.primary.opacity(0.09)))
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Apple Compact Color Picker (With Alpha Support)
struct AppleCompactColorPicker: View {
    @Binding var selection: Color
    var supportsOpacity: Bool = false
    @State private var hexInput: String = ""

    private let swatches: [Color] = [
        .white, Color(white: 0.8), Color(white: 0.4), .black,
        .red, .orange, .yellow, .green,
        .mint, .blue, .purple, .pink
    ]

    var body: some View {
        VStack(spacing: 10) {
            // 1. Палитра готовых базовых цветов
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(swatches, id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(color == selection ? Color.primary : Color.primary.opacity(0.15),
                                        lineWidth: color == selection ? 2 : 0.5)
                        )
                        .onTapGesture {
                            // Сохраняем текущую прозрачность при выборе готового цвета
                            let currentAlpha = selection.rgbComponents.a
                            let rgb = color.rgbComponents
                            selection = Color(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: currentAlpha)
                            hexInput = selection.toHex
                        }
                }
            }
            
            Divider().padding(.vertical, 2)
            
            // 2. Настройка HSB + Alpha
            VStack(spacing: 8) {
                let hsb = selection.hsbComponents
                let rgb = selection.rgbComponents
                
                // Тон (Hue)
                hsbSliderRow(label: "H", value: Binding(
                    get: { hsb.h },
                    set: { updateHSB(h: $0, s: hsb.s, b: hsb.b, a: hsb.a) }
                ), gradient: LinearGradient(
                    colors: (0...6).map { Color(hue: Double($0)/6.0, saturation: 1, brightness: 1) },
                    startPoint: .leading, endPoint: .trailing
                ))
                
                // Насыщенность (Saturation)
                hsbSliderRow(label: "S", value: Binding(
                    get: { hsb.s },
                    set: { updateHSB(h: hsb.h, s: $0, b: hsb.b, a: hsb.a) }
                ), gradient: LinearGradient(
                    colors: [Color(hue: hsb.h, saturation: 0, brightness: hsb.b), Color(hue: hsb.h, saturation: 1, brightness: hsb.b)],
                    startPoint: .leading, endPoint: .trailing
                ))
                
                // Яркость (Brightness)
                hsbSliderRow(label: "B", value: Binding(
                    get: { hsb.b },
                    set: { updateHSB(h: hsb.h, s: hsb.s, b: $0, a: hsb.a) }
                ), gradient: LinearGradient(
                    colors: [.black, Color(hue: hsb.h, saturation: hsb.s, brightness: 1)],
                    startPoint: .leading, endPoint: .trailing
                ))
                
                // Альфа-канал (Прозрачность) — Показывается только там, где нужно
                if supportsOpacity {
                    hsbSliderRow(label: "A", value: Binding(
                        get: { rgb.a },
                        set: { selection = Color(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: $0) }
                    ), gradient: LinearGradient(
                        colors: [Color(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: 0),
                                 Color(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: 1)],
                        startPoint: .leading, endPoint: .trailing
                    ))
                }
            }
            
            Divider().padding(.vertical, 2)
            
            // 3. Точный HEX-ввод
            HStack(spacing: 6) {
                Text("HEX").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                TextField("#000000", text: $hexInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .labelsHidden()
                    .onSubmit {
                        if let parsedColor = Color.fromHex(hexInput) {
                            let currentAlpha = selection.rgbComponents.a
                            let rgb = parsedColor.rgbComponents
                            selection = Color(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: currentAlpha)
                        } else {
                            hexInput = selection.toHex
                        }
                    }
                
                // Квадратик предпросмотра (поддерживает отображение прозрачности)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(selection)
                    .frame(width: 18, height: 18)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.separator, lineWidth: 0.5))
            }
        }
        .padding(10)
        .frame(width: 150)
        .onAppear {
            hexInput = selection.toHex
        }
        .onChange(of: selection) { _, newColor in
            hexInput = newColor.toHex
        }
    }

    private func updateHSB(h: Double, s: Double, b: Double, a: Double) {
        selection = Color(hue: h, saturation: s, brightness: b, opacity: a)
    }

    @ViewBuilder
    private func hsbSliderRow(label: String, value: Binding<Double>, gradient: LinearGradient) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 10, alignment: .leading)
            
            ColorComponentSlider(value: value, gradient: gradient)
        }
    }
}

// MARK: - Custom Color Component Slider
struct ColorComponentSlider: View {
    @Binding var value: Double
    let gradient: LinearGradient
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let thumbDiameter: CGFloat = 12
            // Доступный для движения диапазон, чтобы кружок не вылетал за границы
            let usableWidth = max(1.0, width - thumbDiameter)
            let thumbOffset = CGFloat(value) * usableWidth
            
            ZStack(alignment: .leading) {
                // 1. Чистый фоновый градиент без перекрывающих линий
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(gradient)
                    .frame(height: 6)
                
                // 2. Кружок ползунка, который виден ВСЕГДА
                Circle()
                    .fill(.white)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
                    .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 0.5))
                    .offset(x: thumbOffset)
            }
            .frame(maxHeight: .infinity)
            // Обработка клика и перетаскивания напрямую по компоненту
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let location = gesture.location.x - (thumbDiameter / 2)
                        let fraction = Double(location / usableWidth)
                        value = min(1.0, max(0.0, fraction))
                    }
            )
        }
        .frame(height: 12) // Ограничиваем высоту строки
    }
}
