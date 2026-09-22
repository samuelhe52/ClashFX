//
//  StatusItemView.swift
//  ClashX
//
//  Created by CYC on 2018/6/23.
//  Copyright © 2018年 yichengchen. All rights reserved.
//

import AppKit
import Foundation

/// Renders the complete status item into one image. Keeping custom views out of
/// `NSStatusBarButton` avoids the menu-close layout/redraw loop seen on recent
/// macOS releases.
final class StatusItemView: StatusItemViewProtocol {
    private enum Layout {
        static let height: CGFloat = 22
        static let iconOnlyWidth: CGFloat = 25
        static let speedTextPadding: CGFloat = 7
        static let trailingPadding: CGFloat = 3
        static let iconCellSize: CGFloat = 18
        static let iconLeading: CGFloat = 3
        static let labelHeight: CGFloat = 10
        static let fixedWidthSample = "999KB/s"
    }

    private weak var button: NSStatusBarButton?
    private var speedAlignmentObserver: NSObjectProtocol?

    private var up = 0
    private var down = 0
    private var showSpeed = true
    private var enableProxy = false
    private var currentWidth = statusItemLengthWithSpeed

    static func create(statusItem: NSStatusItem?) -> StatusItemView {
        let view = StatusItemView()
        if let button = statusItem?.button {
            view.button = button
            button.imagePosition = .imageOverlaps
        } else {
            Logger.log("button = nil")
            AppDelegate.shared.openConfigFolder(view)
        }
        view.speedAlignmentObserver = NotificationCenter.default.addObserver(
            forName: Settings.menuBarSpeedAlignmentDidChange,
            object: nil,
            queue: .main
        ) { [weak view] _ in
            view?.renderImage()
        }
        view.renderImage()
        return view
    }

    deinit {
        if let speedAlignmentObserver {
            NotificationCenter.default.removeObserver(speedAlignmentObserver)
        }
    }

    var preferredWidth: CGFloat {
        guard showSpeed else { return Layout.iconOnlyWidth }
        let attributes: [NSAttributedString.Key: Any] = [.font: StatusItemTool.speedFont]
        let textWidth = ceil((Layout.fixedWidthSample as NSString).size(withAttributes: attributes).width)
        return Layout.iconOnlyWidth + textWidth + Layout.speedTextPadding
    }

    func updateSize(width: CGFloat) {
        currentWidth = width
        renderImage()
    }

    func updateViewStatus(enableProxy: Bool) {
        guard self.enableProxy != enableProxy else { return }
        self.enableProxy = enableProxy
        renderImage()
    }

    func updateSpeedLabel(up: Int, down: Int) {
        guard showSpeed, self.up != up || self.down != down else { return }
        self.up = up
        self.down = down
        renderImage()
    }

    func showSpeedContainer(show: Bool) {
        guard showSpeed != show else { return }
        showSpeed = show
        renderImage()
    }

    func updateSpeedToolTip(_ toolTip: String) {
        button?.toolTip = toolTip
    }

    func reloadMenuImage() {
        renderImage()
    }

    private func renderImage() {
        guard let button else { return }

        let width = currentWidth
        let showSpeed = showSpeed
        let enableProxy = enableProxy
        let upSpeed = SpeedUtils.getMenuBarSpeedString(for: up)
        let downSpeed = SpeedUtils.getMenuBarSpeedString(for: down)
        let speedAlignment = Settings.menuBarSpeedAlignment
        let icon = StatusItemTool.menuImage.copy() as? NSImage
        icon?.isTemplate = false

        let image = NSImage(size: NSSize(width: width, height: Layout.height), flipped: false) { [weak button] _ in
            guard let button else { return false }
            let drawContents = {
                Self.drawIcon(icon, enableProxy: enableProxy)
                if showSpeed {
                    Self.drawSpeed(
                        up: upSpeed,
                        down: downSpeed,
                        width: width,
                        alignment: speedAlignment
                    )
                }
            }
            if #available(macOS 11, *) {
                button.effectiveAppearance.performAsCurrentDrawingAppearance(drawContents)
            } else {
                let previousAppearance = NSAppearance.current
                NSAppearance.current = button.effectiveAppearance
                drawContents()
                NSAppearance.current = previousAppearance
            }
            return true
        }

        // Let AppKit tint the monochrome composite for the menu bar's normal
        // and highlighted states. The rendered alpha still carries the
        // disabled-icon treatment.
        image.isTemplate = true
        button.image = image
    }

    private static func drawIcon(_ icon: NSImage?, enableProxy: Bool) {
        guard let icon, icon.size.width > 0, icon.size.height > 0 else { return }

        let cellRect = CGRect(
            x: Layout.iconLeading,
            y: (Layout.height - Layout.iconCellSize) / 2,
            width: Layout.iconCellSize,
            height: Layout.iconCellSize
        )
        let scale = min(
            cellRect.width / icon.size.width,
            cellRect.height / icon.size.height,
            1
        )
        let iconRect = CGRect(
            x: cellRect.midX - icon.size.width * scale / 2,
            y: cellRect.midY - icon.size.height * scale / 2,
            width: icon.size.width * scale,
            height: icon.size.height * scale
        )

        icon.draw(in: iconRect)
        let tint = enableProxy
            ? NSColor.labelColor
            : NSColor.labelColor.withSystemEffect(.disabled)
        tint.setFill()
        iconRect.fill(using: .sourceAtop)
    }

    private static func drawSpeed(
        up: String,
        down: String,
        width: CGFloat,
        alignment: MenuBarSpeedAlignment
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: StatusItemTool.speedFont,
            .foregroundColor: NSColor.labelColor
        ]
        let upSize = (up as NSString).size(withAttributes: attributes)
        let downSize = (down as NSString).size(withAttributes: attributes)
        let trailingX = width - Layout.trailingPadding
        let textAreaOriginX = Layout.iconOnlyWidth
        let textAreaWidth = max(0, trailingX - textAreaOriginX)

        let upRect = CGRect(
            x: textAreaOriginX + alignment.textOriginX(
                containerWidth: textAreaWidth,
                textWidth: upSize.width
            ),
            y: Layout.height - Layout.labelHeight - 1,
            width: upSize.width,
            height: Layout.labelHeight
        )
        let downRect = CGRect(
            x: textAreaOriginX + alignment.textOriginX(
                containerWidth: textAreaWidth,
                textWidth: downSize.width
            ),
            y: 1,
            width: downSize.width,
            height: Layout.labelHeight
        )
        (up as NSString).draw(in: upRect, withAttributes: attributes)
        (down as NSString).draw(in: downRect, withAttributes: attributes)
    }
}
