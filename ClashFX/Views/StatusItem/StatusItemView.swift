//
//  StatusItemView.swift
//  ClashX
//
//  Created by CYC on 2018/6/23.
//  Copyright © 2018年 yichengchen. All rights reserved.
//

import AppKit
import Foundation

/// Renders the status-bar icon + speed labels into a single NSImage and sets it
/// on the NSStatusBarButton. No subview is added to the button, which avoids the
/// runaway layout/redraw cycle that macOS triggers when a custom subview exists
/// and the button highlight state changes (menu close).
class StatusItemView: StatusItemViewProtocol {
    private weak var button: NSStatusBarButton?

    private var up: Int = 0
    private var down: Int = 0
    private var showSpeed: Bool = true
    private var enableProxy: Bool = false
    private var currentWidth: CGFloat = 72

    static func create(statusItem: NSStatusItem?) -> StatusItemView {
        let view = StatusItemView()
        if let button = statusItem?.button {
            view.button = button
        } else {
            Logger.log("button = nil")
            AppDelegate.shared.openConfigFolder(view)
        }
        view.updateViewStatus(enableProxy: false)
        return view
    }

    // MARK: - StatusItemViewProtocol

    func updateSize(width: CGFloat) {
        currentWidth = width
        renderImage()
    }

    func updateViewStatus(enableProxy: Bool) {
        self.enableProxy = enableProxy
        renderImage()
    }

    func updateSpeedLabel(up: Int, down: Int) {
        guard showSpeed else { return }
        var changed = false
        if up != self.up { self.up = up; changed = true }
        if down != self.down { self.down = down; changed = true }
        if changed { renderImage() }
    }

    func showSpeedContainer(show: Bool) {
        showSpeed = show
        renderImage()
    }

    // MARK: - Image rendering

    private func renderImage() {
        guard let button = button else { return }

        let height: CGFloat = 22
        let width = currentWidth

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            // --- Icon ---
            // The image cell area is 18×18 (matching the original xib) but we
            // draw the icon at its natural point-size, centered, to replicate
            // NSImageView's .scaleProportionallyDown behaviour.
            let cellSize: CGFloat = 18
            let cellRect = CGRect(x: 3, y: (height - cellSize) / 2, width: cellSize, height: cellSize)

            if let icon = StatusItemTool.menuImage.copy() as? NSImage {
                icon.isTemplate = false
                let imgSize = icon.size // natural point-size (e.g. 16×16)
                let scale = min(cellRect.width / imgSize.width,
                                cellRect.height / imgSize.height,
                                1.0) // never upscale
                let drawW = imgSize.width * scale
                let drawH = imgSize.height * scale
                let iconRect = CGRect(
                    x: cellRect.midX - drawW / 2,
                    y: cellRect.midY - drawH / 2,
                    width: drawW,
                    height: drawH
                )

                let tint: NSColor = self.enableProxy
                    ? .labelColor
                    : NSColor.labelColor.withSystemEffect(.disabled)
                let tinted = self.tintedImage(icon, color: tint)
                tinted.draw(in: iconRect)
            }

            // --- Speed labels ---
            if self.showSpeed {
                let font = StatusItemTool.font
                let textColor: NSColor = .labelColor
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: textColor,
                ]
                let containerWidth: CGFloat = 32
                let containerX = width - 3 - containerWidth
                let labelHeight: CGFloat = 10

                let upStr = SpeedUtils.getSpeedString(for: self.up)
                let downStr = SpeedUtils.getSpeedString(for: self.down)

                let upSize = (upStr as NSString).size(withAttributes: attrs)
                let downSize = (downStr as NSString).size(withAttributes: attrs)

                let upRect = CGRect(
                    x: containerX + containerWidth - upSize.width,
                    y: height - labelHeight - 1,
                    width: upSize.width,
                    height: labelHeight
                )
                let downRect = CGRect(
                    x: containerX + containerWidth - downSize.width,
                    y: 1,
                    width: downSize.width,
                    height: labelHeight
                )

                (upStr as NSString).draw(in: upRect, withAttributes: attrs)
                (downStr as NSString).draw(in: downRect, withAttributes: attrs)
            }

            return true
        }

        image.isTemplate = false
        button.image = image
        button.imagePosition = .imageOverlaps
    }

    private func tintedImage(_ image: NSImage, color: NSColor) -> NSImage {
        let result = NSImage(size: image.size)
        result.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: image.size),
                   from: .zero,
                   operation: .sourceOver,
                   fraction: 1.0)
        color.set()
        NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
        result.unlockFocus()
        return result
    }
}
