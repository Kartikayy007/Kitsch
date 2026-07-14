//
//  EditorCanvasView.swift
//  Kitsch
//
//  Created by kartikay on 10/07/26.
//

import SwiftUI
import UIKit

struct EditorCanvasView: View {
    @Binding var scale: CGFloat
    @Binding var background: EditorBackground
    @Binding var stickers: [EditorSticker]
    @Binding var selectedStickerID: EditorSticker.ID?
    let isBackgroundTransformEnabled: Bool
    let onStickerTransformCommitted: () -> Void
    let onBackgroundTransformCommitted: () -> Void
    let onRequestSnip: (EditorSticker.ID) -> Void
    let onDeleteSticker: (EditorSticker.ID) -> Void
    let onDuplicateSticker: (EditorSticker.ID) -> Void

    private let canvasSize = CGSize(width: 393, height: 852)
    private let fitInset: CGFloat = 0.72
    private let minUserScale: CGFloat = 0.5
    private let maxUserScale: CGFloat = 3.0

    @State private var gestureScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { proxy in
            let baseScale = min(
                proxy.size.width / canvasSize.width,
                proxy.size.height / canvasSize.height
            ) * fitInset
            let liveScale = baseScale * min(max(scale * gestureScale, minUserScale), maxUserScale)

            ZStack {
                Color.clear

                EditorCanvasHostView(
                    background: $background,
                    stickers: $stickers,
                    selectedStickerID: $selectedStickerID,
                    canvasScale: liveScale,
                    isBackgroundTransformEnabled: isBackgroundTransformEnabled,
                    onStickerTransformCommitted: onStickerTransformCommitted,
                    onBackgroundTransformCommitted: onBackgroundTransformCommitted,
                    onRequestSnip: onRequestSnip,
                    onDeleteSticker: onDeleteSticker,
                    onDuplicateSticker: onDuplicateSticker
                )
                .frame(width: canvasSize.width, height: canvasSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
                .scaleEffect(liveScale)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(canvasMagnifyGesture, isEnabled: selectedStickerID == nil && !isBackgroundTransformEnabled)
        }
    }

    private var canvasMagnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                gestureScale = value.magnification
            }
            .onEnded { value in
                scale = min(max(scale * value.magnification, minUserScale), maxUserScale)
                gestureScale = 1.0
            }
    }
}

#Preview {
    EditorCanvasView(
        scale: .constant(1),
        background: .constant(.defaultColor),
        stickers: .constant([]),
        selectedStickerID: .constant(nil),
        isBackgroundTransformEnabled: false,
        onStickerTransformCommitted: {},
        onBackgroundTransformCommitted: {},
        onRequestSnip: { _ in },
        onDeleteSticker: { _ in },
        onDuplicateSticker: { _ in }
    )
    .background(Color.black)
    .preferredColorScheme(.dark)
}

private struct EditorCanvasHostView: UIViewRepresentable {
    @Binding var background: EditorBackground
    @Binding var stickers: [EditorSticker]
    @Binding var selectedStickerID: EditorSticker.ID?
    let canvasScale: CGFloat
    let isBackgroundTransformEnabled: Bool
    let onStickerTransformCommitted: () -> Void
    let onBackgroundTransformCommitted: () -> Void
    let onRequestSnip: (EditorSticker.ID) -> Void
    let onDeleteSticker: (EditorSticker.ID) -> Void
    let onDuplicateSticker: (EditorSticker.ID) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> StickerCanvasUIView {
        let view = StickerCanvasUIView()
        view.coordinator = context.coordinator
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: StickerCanvasUIView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.canvasScale = canvasScale
        context.coordinator.isBackgroundTransformEnabled = isBackgroundTransformEnabled
        uiView.updateBorder()
        context.coordinator.syncBackgroundView()
        context.coordinator.syncStickerViews()
        context.coordinator.updateToolbar()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: EditorCanvasHostView
        weak var canvasView: StickerCanvasUIView?
        var canvasScale: CGFloat
        var isBackgroundTransformEnabled: Bool

        private var stickerViews: [UUID: StickerItemView] = [:]
        private var panStartOffset: CGSize = .zero
        private var pinchStartScale: CGFloat = 1
        private var rotationStartAngle: CGFloat = 0
        private var backgroundPanStartOffset: CGSize = .zero
        private var backgroundPinchStartScale: CGFloat = 1
        private var isTransformingSticker = false

        init(_ parent: EditorCanvasHostView) {
            self.parent = parent
            self.canvasScale = parent.canvasScale
            self.isBackgroundTransformEnabled = parent.isBackgroundTransformEnabled
        }

        func attach(to canvasView: StickerCanvasUIView) {
            self.canvasView = canvasView

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleCanvasTap(_:)))
            tap.delegate = self
            canvasView.addGestureRecognizer(tap)

            let backgroundPan = UIPanGestureRecognizer(target: self, action: #selector(handleBackgroundPan(_:)))
            backgroundPan.delegate = self
            canvasView.backgroundImageView.addGestureRecognizer(backgroundPan)

            let backgroundPinch = UIPinchGestureRecognizer(target: self, action: #selector(handleBackgroundPinch(_:)))
            backgroundPinch.delegate = self
            canvasView.backgroundImageView.addGestureRecognizer(backgroundPinch)

            canvasView.toolbarView.onDuplicate = { [weak self] in
                self?.duplicateSelectedSticker()
            }
            canvasView.toolbarView.onDelete = { [weak self] in
                self?.deleteSelectedSticker()
            }
            canvasView.toolbarView.onSnip = { [weak self] in
                self?.snipSelectedSticker()
            }
        }

        func syncBackgroundView() {
            guard let canvasView else { return }

            switch parent.background {
            case let .color(colorValue):
                canvasView.backgroundColor = UIColor(colorValue.color)
                canvasView.backgroundImageView.isHidden = true
                canvasView.backgroundImageView.image = nil
                canvasView.backgroundImageView.transform = .identity
                canvasView.backgroundImageView.center = CGPoint(x: canvasView.bounds.midX, y: canvasView.bounds.midY)
            case let .image(backgroundImage):
                canvasView.backgroundColor = .black
                canvasView.backgroundImageView.isHidden = false
                canvasView.backgroundImageView.image = UIImage(data: backgroundImage.data)
                canvasView.backgroundImageView.frame = canvasView.bounds
                canvasView.backgroundImageView.center = CGPoint(
                    x: canvasView.bounds.midX + backgroundImage.offset.width,
                    y: canvasView.bounds.midY + backgroundImage.offset.height
                )
                canvasView.backgroundImageView.transform = CGAffineTransform(
                    scaleX: max(backgroundImage.scale, 1),
                    y: max(backgroundImage.scale, 1)
                )
            }

            canvasView.backgroundImageView.isUserInteractionEnabled = isBackgroundTransformEnabled
        }

        func syncStickerViews() {
            guard let canvasView else { return }

            let ids = Set(parent.stickers.map(\.id))
            for (id, view) in stickerViews where !ids.contains(id) {
                view.removeFromSuperview()
                stickerViews.removeValue(forKey: id)
            }

            for sticker in parent.stickers {
                let stickerView = stickerViews[sticker.id] ?? makeStickerView(for: sticker)
                configure(stickerView, with: sticker, in: canvasView)
                if stickerView.superview == nil {
                    canvasView.addSubview(stickerView)
                }
                canvasView.bringSubviewToFront(stickerView)
            }

            canvasView.bringSubviewToFront(canvasView.toolbarView)
        }

        private func makeStickerView(for sticker: EditorSticker) -> StickerItemView {
            let view = StickerItemView(id: sticker.id)
            view.isUserInteractionEnabled = true

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleStickerTap(_:)))
            tap.delegate = self
            view.addGestureRecognizer(tap)

            let pan = UIPanGestureRecognizer(target: self, action: #selector(handleStickerPan(_:)))
            pan.delegate = self
            view.addGestureRecognizer(pan)

            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handleStickerPinch(_:)))
            pinch.delegate = self
            view.addGestureRecognizer(pinch)

            let rotation = UIRotationGestureRecognizer(target: self, action: #selector(handleStickerRotation(_:)))
            rotation.delegate = self
            view.addGestureRecognizer(rotation)

            stickerViews[sticker.id] = view
            return view
        }

        private func configure(_ view: StickerItemView, with sticker: EditorSticker, in canvasView: StickerCanvasUIView) {
            view.updateImage(using: sticker.content)
            view.bounds = CGRect(origin: .zero, size: CGSize(width: view.baseSize, height: view.baseSize))
            view.center = CGPoint(
                x: canvasView.bounds.midX + sticker.offset.width,
                y: canvasView.bounds.midY + sticker.offset.height
            )
            view.applyTransform(scale: sticker.scale, rotation: sticker.rotation)
            view.setSelected(parent.selectedStickerID == sticker.id)
        }

        @objc private func handleCanvasTap(_ gesture: UITapGestureRecognizer) {
            guard let canvasView else { return }
            let point = gesture.location(in: canvasView)
            let hitView = canvasView.hitTest(point, with: nil)
            if hitView === canvasView || hitView === canvasView.backgroundImageView {
                parent.selectedStickerID = nil
                updateToolbar()
            }
        }

        @objc private func handleBackgroundPan(_ gesture: UIPanGestureRecognizer) {
            guard isBackgroundTransformEnabled,
                  parent.selectedStickerID == nil,
                  case let .image(backgroundImage) = parent.background else {
                return
            }

            switch gesture.state {
            case .began:
                backgroundPanStartOffset = backgroundImage.offset
            case .changed:
                let translation = gesture.translation(in: canvasView)
                updateBackground(offset: CGSize(
                    width: backgroundPanStartOffset.width + translation.x / max(canvasScale, 0.001),
                    height: backgroundPanStartOffset.height + translation.y / max(canvasScale, 0.001)
                ), scale: backgroundImage.scale)
            case .ended, .cancelled, .failed:
                parent.onBackgroundTransformCommitted()
            default:
                break
            }
        }

        @objc private func handleBackgroundPinch(_ gesture: UIPinchGestureRecognizer) {
            guard isBackgroundTransformEnabled,
                  parent.selectedStickerID == nil,
                  case let .image(backgroundImage) = parent.background else {
                return
            }

            switch gesture.state {
            case .began:
                backgroundPinchStartScale = max(backgroundImage.scale, 1)
            case .changed:
                updateBackground(offset: backgroundImage.offset, scale: max(backgroundPinchStartScale * gesture.scale, 1))
            case .ended, .cancelled, .failed:
                parent.onBackgroundTransformCommitted()
            default:
                break
            }
        }

        @objc private func handleStickerTap(_ gesture: UITapGestureRecognizer) {
            guard let stickerView = gesture.view as? StickerItemView else { return }
            setSelectedSticker(stickerView.stickerID)
        }

        @objc private func handleStickerPan(_ gesture: UIPanGestureRecognizer) {
            guard let stickerView = gesture.view as? StickerItemView,
                  let index = stickerIndex(for: stickerView.stickerID) else {
                return
            }

            switch gesture.state {
            case .began:
                beginTransform(for: stickerView.stickerID)
                panStartOffset = parent.stickers[index].offset
            case .changed:
                let translation = gesture.translation(in: canvasView)
                updateStickerOffset(
                    at: index,
                    offset: CGSize(
                        width: panStartOffset.width + translation.x / max(canvasScale, 0.001),
                        height: panStartOffset.height + translation.y / max(canvasScale, 0.001)
                    )
                )
            case .ended, .cancelled, .failed:
                endTransform()
            default:
                break
            }
        }

        @objc private func handleStickerPinch(_ gesture: UIPinchGestureRecognizer) {
            guard let stickerView = gesture.view as? StickerItemView,
                  let index = stickerIndex(for: stickerView.stickerID) else {
                return
            }

            switch gesture.state {
            case .began:
                beginTransform(for: stickerView.stickerID)
                pinchStartScale = parent.stickers[index].scale
            case .changed:
                updateStickerScale(at: index, scale: clampStickerScale(pinchStartScale * gesture.scale))
            case .ended, .cancelled, .failed:
                endTransform()
            default:
                break
            }
        }

        @objc private func handleStickerRotation(_ gesture: UIRotationGestureRecognizer) {
            guard let stickerView = gesture.view as? StickerItemView,
                  let index = stickerIndex(for: stickerView.stickerID) else {
                return
            }

            switch gesture.state {
            case .began:
                beginTransform(for: stickerView.stickerID)
                rotationStartAngle = parent.stickers[index].rotation
            case .changed:
                updateStickerRotation(at: index, rotation: rotationStartAngle + gesture.rotation)
            case .ended, .cancelled, .failed:
                endTransform()
            default:
                break
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            let backgroundPair =
                (gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPinchGestureRecognizer) ||
                (gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer)
            let stickerTransforms =
                (gestureRecognizer is UIPanGestureRecognizer ||
                 gestureRecognizer is UIPinchGestureRecognizer ||
                 gestureRecognizer is UIRotationGestureRecognizer) &&
                (otherGestureRecognizer is UIPanGestureRecognizer ||
                 otherGestureRecognizer is UIPinchGestureRecognizer ||
                 otherGestureRecognizer is UIRotationGestureRecognizer)

            return (backgroundPair || stickerTransforms) && gestureRecognizer.view === otherGestureRecognizer.view
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            if gestureRecognizer.view === canvasView?.backgroundImageView {
                return isBackgroundTransformEnabled && parent.selectedStickerID == nil
            }
            return true
        }

        func updateToolbar() {
            guard let canvasView else { return }
            guard !isTransformingSticker,
                  let selectedID = parent.selectedStickerID,
                  let selectedView = stickerViews[selectedID],
                  selectedView.superview != nil else {
                canvasView.toolbarView.setHidden(true, animated: true)
                return
            }

            let size = canvasView.toolbarView.bounds.size == .zero
                ? CGSize(width: 164, height: 46)
                : canvasView.toolbarView.bounds.size
            let frame = selectedView.frame
            let centerX = min(max(frame.midX, size.width / 2 + 14), canvasView.bounds.maxX - size.width / 2 - 14)
            let topY = min(frame.maxY + 16, canvasView.bounds.maxY - size.height - 14)

            canvasView.toolbarView.updatePosition(centerX: centerX, topY: topY)
            canvasView.toolbarView.setHidden(false, animated: true)
        }

        private func setSelectedSticker(_ id: UUID?) {
            parent.selectedStickerID = id
            updateToolbar()
        }

        private func stickerIndex(for id: UUID) -> Int? {
            parent.stickers.firstIndex(where: { $0.id == id })
        }

        private func updateStickerOffset(at index: Int, offset: CGSize) {
            guard parent.stickers.indices.contains(index) else { return }
            parent.stickers[index].offset = offset
        }

        private func updateStickerScale(at index: Int, scale: CGFloat) {
            guard parent.stickers.indices.contains(index) else { return }
            parent.stickers[index].scale = scale
        }

        private func updateStickerRotation(at index: Int, rotation: CGFloat) {
            guard parent.stickers.indices.contains(index) else { return }
            parent.stickers[index].rotation = rotation
        }

        private func clampStickerScale(_ value: CGFloat) -> CGFloat {
            min(max(value, 0.2), 12)
        }

        private func beginTransform(for id: UUID) {
            isTransformingSticker = true
            setSelectedSticker(id)
            canvasView?.toolbarView.setHidden(true, animated: true)
        }

        private func endTransform() {
            isTransformingSticker = false
            parent.onStickerTransformCommitted()
            updateToolbar()
        }

        private func duplicateSelectedSticker() {
            guard let id = parent.selectedStickerID,
                  let index = stickerIndex(for: id) else { return }
            let source = parent.stickers[index]
            let copy = EditorSticker(
                name: source.name,
                content: source.content,
                offset: CGSize(width: source.offset.width + 18, height: source.offset.height + 18),
                scale: source.scale,
                rotation: source.rotation
            )
            parent.stickers.append(copy)
            parent.selectedStickerID = copy.id
            parent.onDuplicateSticker(copy.id)
            updateToolbar()
        }

        private func deleteSelectedSticker() {
            guard let id = parent.selectedStickerID,
                  let index = stickerIndex(for: id) else { return }
            parent.stickers.remove(at: index)
            parent.selectedStickerID = nil
            parent.onDeleteSticker(id)
            updateToolbar()
        }

        private func snipSelectedSticker() {
            guard let id = parent.selectedStickerID else { return }
            parent.onRequestSnip(id)
        }

        private func updateBackground(offset: CGSize, scale: CGFloat) {
            guard case let .image(backgroundImage) = parent.background,
                  let canvasView,
                  let image = canvasView.backgroundImageView.image else { return }

            let clampedScale = max(scale, 1)
            let clampedOffset = clampBackgroundOffset(
                offset,
                imageSize: image.size,
                canvasSize: canvasView.bounds.size,
                scale: clampedScale
            )

            parent.background = .image(
                EditorBackgroundImage(
                    data: backgroundImage.data,
                    offset: clampedOffset,
                    scale: clampedScale
                )
            )
        }

        private func clampBackgroundOffset(_ offset: CGSize, imageSize: CGSize, canvasSize: CGSize, scale: CGFloat) -> CGSize {
            let aspectFillScale = max(canvasSize.width / max(imageSize.width, 1), canvasSize.height / max(imageSize.height, 1))
            let filledSize = CGSize(width: imageSize.width * aspectFillScale * scale, height: imageSize.height * aspectFillScale * scale)
            let maxX = max((filledSize.width - canvasSize.width) / 2, 0)
            let maxY = max((filledSize.height - canvasSize.height) / 2, 0)
            return CGSize(
                width: min(max(offset.width, -maxX), maxX),
                height: min(max(offset.height, -maxY), maxY)
            )
        }
    }
}

private final class StickerCanvasUIView: UIView {
    weak var coordinator: EditorCanvasHostView.Coordinator?
    let backgroundImageView = UIImageView()
    let toolbarView = StickerSelectionToolbarView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        layer.cornerRadius = 44
        layer.cornerCurve = .continuous
        isMultipleTouchEnabled = true

        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        backgroundImageView.isUserInteractionEnabled = true
        addSubview(backgroundImageView)
        addSubview(toolbarView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundImageView.frame = bounds
        coordinator?.updateToolbar()
    }

    func updateBorder() {
        layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        layer.borderWidth = 1
    }
}

private final class StickerItemView: UIView {
    let stickerID: UUID
    let baseSize: CGFloat = 128

    private let imageView = UIImageView()

    init(id: UUID) {
        self.stickerID = id
        super.init(frame: .zero)
        isMultipleTouchEnabled = true
        clipsToBounds = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        addSubview(imageView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
    }

    func updateImage(using content: EditorSticker.Content) {
        switch content {
        case let .image(data):
            imageView.image = UIImage(data: data)
        }
    }

    func setSelected(_ isSelected: Bool) {
        layer.borderWidth = isSelected ? 2 : 0
        layer.borderColor = UIColor.white.cgColor
        layer.cornerRadius = 6
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.white.cgColor
        layer.shadowOpacity = isSelected ? 0.22 : 0
        layer.shadowRadius = 18
        layer.shadowOffset = CGSize(width: 0, height: 6)
    }

    func applyTransform(scale: CGFloat, rotation: CGFloat) {
        transform = CGAffineTransform(rotationAngle: rotation).scaledBy(x: scale, y: scale)
    }
}

private final class StickerSelectionToolbarView: UIVisualEffectView {
    var onDuplicate: (() -> Void)?
    var onDelete: (() -> Void)?
    var onSnip: (() -> Void)?

    private let stackView = UIStackView()

    init() {
        super.init(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        alpha = 0
        isHidden = true
        layer.cornerRadius = 23
        layer.cornerCurve = .continuous
        clipsToBounds = true

        contentView.addSubview(stackView)
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fillEqually
        stackView.spacing = 2
        stackView.addArrangedSubview(makeButton(systemName: "plus.square.on.square", action: #selector(handleDuplicate)))
        stackView.addArrangedSubview(makeButton(systemName: "trash", action: #selector(handleDelete)))
        stackView.addArrangedSubview(makeButton(systemName: "scissors", action: #selector(handleSnip)))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        stackView.frame = bounds.insetBy(dx: 8, dy: 6)
    }

    func updatePosition(centerX: CGFloat, topY: CGFloat) {
        let size = CGSize(width: 164, height: 46)
        frame = CGRect(x: centerX - size.width / 2, y: topY, width: size.width, height: size.height)
    }

    func setHidden(_ hidden: Bool, animated: Bool) {
        let animations = { self.alpha = hidden ? 0 : 1 }
        if hidden {
            guard !isHidden else { return }
            if animated {
                UIView.animate(withDuration: 0.18, animations: animations) { _ in
                    self.isHidden = true
                }
            } else {
                animations()
                isHidden = true
            }
        } else {
            isHidden = false
            if animated {
                UIView.animate(withDuration: 0.18, animations: animations)
            } else {
                animations()
            }
        }
    }

    private func makeButton(systemName: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.tintColor = .white
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func handleDuplicate() { onDuplicate?() }
    @objc private func handleDelete() { onDelete?() }
    @objc private func handleSnip() { onSnip?() }
}
