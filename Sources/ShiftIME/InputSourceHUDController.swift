import AppKit

final class InputSourceHUDController {
    private let panel: NSPanel
    private let iconView = NSImageView()
    private let fallbackLabel = NSTextField(labelWithString: "")
    private let nameLabel = NSTextField(labelWithString: "")
    private var hideWorkItem: DispatchWorkItem?

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 150, height: 126),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .utilityWindow

        let effect = NSVisualEffectView(frame: panel.contentView!.bounds)
        effect.autoresizingMask = [.width, .height]
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 18
        effect.layer?.masksToBounds = true
        panel.contentView?.addSubview(effect)

        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        fallbackLabel.alignment = .center
        fallbackLabel.font = .systemFont(ofSize: 42, weight: .medium)
        fallbackLabel.textColor = .labelColor
        fallbackLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.alignment = .center
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        effect.addSubview(iconView)
        effect.addSubview(fallbackLabel)
        effect.addSubview(nameLabel)
        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: effect.topAnchor, constant: 20),
            iconView.centerXAnchor.constraint(equalTo: effect.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 58),
            iconView.heightAnchor.constraint(equalToConstant: 58),
            fallbackLabel.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            fallbackLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            fallbackLabel.widthAnchor.constraint(equalTo: iconView.widthAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -10),
            nameLabel.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -15)
        ])
    }

    func show(source: InputSourceDescriptor) {
        hideWorkItem?.cancel()
        iconView.image = source.icon
        iconView.isHidden = source.icon == nil
        fallbackLabel.stringValue = source.shortLabel
        fallbackLabel.isHidden = source.icon != nil
        nameLabel.stringValue = source.name

        positionOnActiveScreen()
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                self.panel.animator().alphaValue = 0
            } completionHandler: {
                self.panel.orderOut(nil)
            }
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85, execute: item)
    }

    private func positionOnActiveScreen() {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let origin = NSPoint(
            x: frame.midX - panel.frame.width / 2,
            y: frame.midY - panel.frame.height / 2 + frame.height * 0.08
        )
        panel.setFrameOrigin(origin)
    }
}
