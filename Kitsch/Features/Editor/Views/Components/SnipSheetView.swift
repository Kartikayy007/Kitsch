//
//  SnipSheetView.swift
//  Kitsch
//

import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct SnipStickerSheetItem: Identifiable {
    let id: EditorSticker.ID
}

struct SnipSheetResult {
    let data: Data
    let name: String
    let editingSourceData: Data
    let editState: StickerEditState
}

struct SnipSheetView: View {
    let sticker: EditorSticker
    let onCancel: () -> Void
    let onSave: (SnipSheetResult) -> Void

    @State private var mode: StickerEditorMode = .adjust
    @State private var editState = StickerEditState.default
    @State private var selectedControl: StickerAdjustmentControl = .brilliance
    @State private var undoStack: [StickerEditState] = []
    @State private var redoStack: [StickerEditState] = []
    @GestureState private var liveCropScale: CGFloat = 1
    @GestureState private var liveCropOffset: CGSize = .zero

    private let editorSize = CGSize(width: 336, height: 430)
    private let historyLimit = 7

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topBar
                centerTitle
                editorSurface
                Spacer(minLength: 0)
                bottomControls
            }
            .background(Color(uiColor: .systemBackground))
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    modeButton(.styles, systemImage: "square.grid.2x2")
                }
                ToolbarItem(placement: .bottomBar) {
                    modeButton(.adjust, systemImage: "dial.medium")
                }
                ToolbarItem(placement: .bottomBar) {
                    modeButton(.crop, systemImage: "crop")
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            editState = sticker.editState
            undoStack = [sticker.editState]
            redoStack = []
        }
    }

    private var topBar: some View {
        HStack {
            Button("Cancel") {
                onCancel()
            }
            .font(.headline.weight(.medium))

            Spacer()

            HStack(spacing: 8) {
                roundIcon("arrow.uturn.backward", enabled: undoStack.count > 1) {
                    undo()
                }
                roundIcon("arrow.uturn.forward", enabled: !redoStack.isEmpty) {
                    redo()
                }
            }

            Spacer()

            Button("Done") {
                saveEdits()
            }
            .font(.headline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.yellow))
            .foregroundStyle(.black)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var centerTitle: some View {
        Text(mode.title.uppercased())
            .font(.headline.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.bottom, 8)
    }

    private var editorSurface: some View {
        ZStack {
            Rectangle()
                .fill(Color.black)

            if let previewImage {
                if mode == .crop {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(editState.cropScale * liveCropScale)
                        .offset(
                            x: editState.cropOffset.width + liveCropOffset.width,
                            y: editState.cropOffset.height + liveCropOffset.height
                        )
                        .gesture(cropGesture)
                } else {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                }
            }

            if mode == .crop {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.74), lineWidth: 1)
                    .padding(22)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: editorSize.width, height: editorSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var bottomControls: some View {
        VStack(spacing: 14) {
            if mode == .adjust {
                adjustControls
                adjustSlider
            } else if mode == .styles {
                styleStrip
            } else {
                helperRow("Pinch and drag")
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var adjustControls: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(StickerAdjustmentControl.allCases, id: \.self) { control in
                    Button {
                        selectedControl = control
                    } label: {
                        Text(control.title.uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selectedControl == control ? .primary : .secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedControl == control ? Color.primary.opacity(0.12) : Color.gray.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var adjustSlider: some View {
        AdjustmentStepperControl(
            value: selectedControlBinding,
            range: selectedControl.range,
            step: selectedControl.step,
            formatter: { selectedControl.valueText(for: $0) },
            onEditingEnded: { pushHistoryIfNeeded() }
        )
    }

    private var styleStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(StickerStylePreset.allCases, id: \.self) { style in
                    Button {
                        editState.style = style
                        pushHistoryIfNeeded()
                    } label: {
                        VStack(spacing: 8) {
                            if let thumbnail = previewThumbnail(for: style) {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 58, height: 58)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }

                            Text(style.title)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.primary)
                        }
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(style == editState.style ? Color.primary.opacity(0.12) : Color.gray.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func helperRow(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
    }

    private func modeButton(_ item: StickerEditorMode, systemImage: String) -> some View {
        Button {
            mode = item
        } label: {
            Label(item.shortTitle, systemImage: systemImage)
        }
        .foregroundStyle(mode == item ? Color.primary : Color.secondary)
    }

    private func roundIcon(_ systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(enabled ? Color.primary : Color.secondary.opacity(0.45))
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.gray.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var cropGesture: some Gesture {
        SimultaneousGesture(
            DragGesture()
                .updating($liveCropOffset) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    editState.cropOffset.width += value.translation.width
                    editState.cropOffset.height += value.translation.height
                    pushHistoryIfNeeded()
                },
            MagnifyGesture()
                .updating($liveCropScale) { value, state, _ in
                    state = value.magnification
                }
                .onEnded { value in
                    editState.cropScale = min(max(editState.cropScale * value.magnification, 0.8), 5)
                    pushHistoryIfNeeded()
                }
        )
    }

    private var previewImage: UIImage? {
        renderPreviewImage()
    }

    private var sourceData: Data? {
        sticker.editingSourceData ?? {
            switch sticker.content {
            case let .image(data): return data
            }
        }()
    }

    private var selectedControlBinding: Binding<Double> {
        Binding(
            get: { selectedControl.currentValue(from: editState.adjustmentValues) },
            set: { newValue in
                selectedControl.update(&editState.adjustmentValues, value: newValue)
            }
        )
    }

    private func saveEdits() {
        guard let sourceData,
              let sourceImage = UIImage(data: sourceData),
              let rendered = renderOutput(from: sourceImage),
              let pngData = rendered.pngData() else {
            onCancel()
            return
        }

        onSave(
            SnipSheetResult(
                data: pngData,
                name: sticker.name,
                editingSourceData: sourceData,
                editState: editState
            )
        )
    }

    private func renderPreviewImage() -> UIImage? {
        guard let sourceData,
              let sourceImage = UIImage(data: sourceData) else { return nil }

        let adjusted = applyAdjustmentsAndStyle(to: sourceImage) ?? sourceImage
        return adjusted
    }

    private func renderOutput(from image: UIImage) -> UIImage? {
        let adjusted = applyAdjustmentsAndStyle(to: image) ?? image
        if editState.cropScale == 1, editState.cropOffset == .zero {
            return adjusted
        }

        let outputSize = CGSize(width: 1024, height: 1024)
        let renderer = UIGraphicsImageRenderer(size: outputSize)
        return renderer.image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: outputSize))

            let baseRect = aspectFitRect(for: adjusted.size, in: outputSize)
            let center = CGPoint(
                x: outputSize.width / 2 + editState.cropOffset.width * (outputSize.width / editorSize.width),
                y: outputSize.height / 2 + editState.cropOffset.height * (outputSize.height / editorSize.height)
            )
            let drawSize = CGSize(width: baseRect.width * editState.cropScale, height: baseRect.height * editState.cropScale)
            let drawRect = CGRect(
                x: center.x - drawSize.width / 2,
                y: center.y - drawSize.height / 2,
                width: drawSize.width,
                height: drawSize.height
            )
            adjusted.draw(in: drawRect)
        }
    }

    private func applyAdjustmentsAndStyle(to image: UIImage) -> UIImage? {
        guard let input = CIImage(image: image) else { return image }
        let context = CIContext(options: nil)

        let color = CIFilter.colorControls()
        color.inputImage = input
        color.brightness = Float(editState.adjustmentValues.brilliance * 0.35)
        color.contrast = Float(1 + editState.adjustmentValues.contrast)
        color.saturation = Float(1 + editState.adjustmentValues.saturation)

        let exposure = CIFilter.exposureAdjust()
        exposure.inputImage = color.outputImage
        exposure.ev = Float(editState.adjustmentValues.exposure)

        let warm = CIFilter.temperatureAndTint()
        warm.inputImage = exposure.outputImage
        warm.neutral = CIVector(x: 6500, y: 0)
        warm.targetNeutral = CIVector(x: 6500 + editState.adjustmentValues.warmth * 1800, y: 0)

        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = warm.outputImage
        sharpen.sharpness = Float(max(editState.adjustmentValues.definition, 0))

        let styled = applyStyle(editState.style, to: sharpen.outputImage ?? warm.outputImage ?? exposure.outputImage ?? color.outputImage)

        guard let output = styled,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private func applyStyle(_ style: StickerStylePreset, to image: CIImage?) -> CIImage? {
        guard let image else { return nil }

        switch style {
        case .original:
            return image
        case .chrome:
            let filter = CIFilter.photoEffectChrome()
            filter.inputImage = image
            return filter.outputImage
        case .fade:
            let filter = CIFilter.photoEffectFade()
            filter.inputImage = image
            return filter.outputImage
        case .instant:
            let filter = CIFilter.photoEffectInstant()
            filter.inputImage = image
            return filter.outputImage
        case .noir:
            let filter = CIFilter.photoEffectNoir()
            filter.inputImage = image
            return filter.outputImage
        case .process:
            let filter = CIFilter.photoEffectProcess()
            filter.inputImage = image
            return filter.outputImage
        case .tonal:
            let filter = CIFilter.photoEffectTonal()
            filter.inputImage = image
            return filter.outputImage
        case .transfer:
            let filter = CIFilter.photoEffectTransfer()
            filter.inputImage = image
            return filter.outputImage
        }
    }

    private func previewThumbnail(for style: StickerStylePreset) -> UIImage? {
        guard let sourceData,
              let base = UIImage(data: sourceData),
              let ciImage = CIImage(image: base) else { return nil }
        let context = CIContext(options: nil)
        let output = applyStyle(style, to: ciImage)
        guard let output,
              let cgImage = context.createCGImage(output, from: output.extent) else { return base }
        return UIImage(cgImage: cgImage)
    }

    private func aspectFitRect(for imageSize: CGSize, in boundingSize: CGSize) -> CGRect {
        let scale = min(boundingSize.width / max(imageSize.width, 1), boundingSize.height / max(imageSize.height, 1))
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (boundingSize.width - size.width) / 2,
            y: (boundingSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private func pushHistoryIfNeeded() {
        guard undoStack.last != editState else { return }
        undoStack.append(editState)
        if undoStack.count > historyLimit {
            undoStack.removeFirst(undoStack.count - historyLimit)
        }
        redoStack.removeAll()
    }

    private func undo() {
        guard undoStack.count > 1 else { return }
        let current = undoStack.removeLast()
        redoStack.append(current)
        if redoStack.count > historyLimit {
            redoStack.removeFirst(redoStack.count - historyLimit)
        }
        if let previous = undoStack.last {
            editState = previous
        }
    }

    private func redo() {
        guard let next = redoStack.popLast() else { return }
        editState = next
        undoStack.append(next)
        if undoStack.count > historyLimit {
            undoStack.removeFirst(undoStack.count - historyLimit)
        }
    }
}

private enum StickerEditorMode: CaseIterable {
    case styles
    case adjust
    case crop

    var title: String {
        switch self {
        case .styles: "Styles"
        case .adjust: "Adjust"
        case .crop: "Crop"
        }
    }

    var shortTitle: String { title }
}

private enum StickerAdjustmentControl: CaseIterable {
    case brilliance
    case exposure
    case contrast
    case saturation
    case warmth
    case definition

    var title: String {
        switch self {
        case .brilliance: "Brilliance"
        case .exposure: "Exposure"
        case .contrast: "Contrast"
        case .saturation: "Saturation"
        case .warmth: "Warmth"
        case .definition: "Definition"
        }
    }

    var range: ClosedRange<Double> {
        switch self {
        case .brilliance: -1 ... 1
        case .exposure: -1.5 ... 1.5
        case .contrast: -0.5 ... 0.8
        case .saturation: -0.8 ... 0.8
        case .warmth: -1 ... 1
        case .definition: 0 ... 1.2
        }
    }

    var step: Double {
        switch self {
        case .brilliance, .contrast, .saturation, .warmth:
            0.05
        case .exposure:
            0.1
        case .definition:
            0.04
        }
    }

    func currentValue(from adjustments: StickerAdjustmentValues) -> Double {
        switch self {
        case .brilliance: adjustments.brilliance
        case .exposure: adjustments.exposure
        case .contrast: adjustments.contrast
        case .saturation: adjustments.saturation
        case .warmth: adjustments.warmth
        case .definition: adjustments.definition
        }
    }

    func update(_ adjustments: inout StickerAdjustmentValues, value: Double) {
        switch self {
        case .brilliance: adjustments.brilliance = value
        case .exposure: adjustments.exposure = value
        case .contrast: adjustments.contrast = value
        case .saturation: adjustments.saturation = value
        case .warmth: adjustments.warmth = value
        case .definition: adjustments.definition = value
        }
    }

    func valueText(for value: Double) -> String {
        String(Int((value * 100).rounded()))
    }
}

private struct AdjustmentStepperControl: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let formatter: (Double) -> String
    let onEditingEnded: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            actionButton("minus") {
                value = max(range.lowerBound, value - step)
                onEditingEnded()
            }

            VStack(spacing: 8) {
                Text(formatter(value))
                    .font(.title3.weight(.semibold))

                Text("Tap minus or plus")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            actionButton("plus") {
                value = min(range.upperBound, value + step)
                onEditingEnded()
            }
        }
        .padding(.horizontal, 6)
    }

    private func actionButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(Color.gray.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .disabled((systemImage == "minus" && value <= range.lowerBound) || (systemImage == "plus" && value >= range.upperBound))
    }
}

#Preview {
    SnipSheetView(
        sticker: EditorSticker(name: "Sample", content: .image(Data())),
        onCancel: {},
        onSave: { _ in }
    )
}
