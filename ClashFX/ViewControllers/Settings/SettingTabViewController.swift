//
//  SettingTabViewController.swift
//  ClashX Pro
//
//  Created by yicheng on 2022/11/20.
//  Copyright © 2022 west2online. All rights reserved.
//

import Cocoa

class SettingTabViewController: NSTabViewController, NibLoadable {
    private let segmentedControlTopPadding: CGFloat = 12
    private let windowScreenPadding: CGFloat = 80

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(macOS 15, *) {
            // NSTabViewController .toolbar style renders as a large gray block
            // on macOS 15 Sequoia — the toolbar layout changed significantly.
            // Fall back to segmentedControlOnTop which renders cleanly.
            tabStyle = .segmentedControlOnTop
        } else {
            tabStyle = .toolbar
        }
        configureTabIcons()
        insertAppearanceTab()
        NSApp.activate(ignoringOtherApps: true)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        adjustSegmentedControlPosition()
    }

    private func configureTabIcons() {
        let symbols = ["gearshape", "keyboard", "hammer"]
        let fallbackGlyphs = ["⚙︎", "⌨︎", "🔨"]

        for (idx, item) in tabViewItems.enumerated() where idx < min(symbols.count, fallbackGlyphs.count) {
            if #available(macOS 11, *), let image = NSImage(systemSymbolName: symbols[idx], accessibilityDescription: nil) {
                item.image = image
            } else {
                item.image = makeFallbackIcon(glyph: fallbackGlyphs[idx])
            }
        }
    }

    private func makeFallbackIcon(glyph: String) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]

        let rect = NSRect(x: 0, y: 1, width: size.width, height: size.height)
        (glyph as NSString).draw(in: rect, withAttributes: attrs)
        image.isTemplate = true
        return image
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        guard let window = view.window,
              let vc = tabViewItem?.viewController else { return }
        var contentSize = vc.preferredContentSize.height > 0
            ? vc.preferredContentSize
            : vc.view.frame.size
        guard contentSize.height > 0 else { return }
        contentSize.height = min(contentSize.height, maximumContentHeight(for: window))
        let newFrame = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize))
        var frame = window.frame
        frame.origin.y += frame.height - newFrame.height
        frame.size.height = newFrame.height
        if let visibleFrame = window.screen?.visibleFrame, frame.minY < visibleFrame.minY + 12 {
            frame.origin.y = visibleFrame.minY + 12
        }
        window.setFrame(frame, display: true, animate: true)
    }

    private func maximumContentHeight(for window: NSWindow) -> CGFloat {
        guard let visibleFrame = window.screen?.visibleFrame else { return 620 }
        return max(360, visibleFrame.height - windowScreenPadding)
    }

    private func adjustSegmentedControlPosition() {
        guard #available(macOS 15, *), tabStyle == .segmentedControlOnTop,
              let contentView = view.window?.contentView,
              let segmentedControl = contentView.firstSubview(ofType: NSSegmentedControl.self) else { return }

        let targetY = contentView.bounds.maxY - segmentedControl.frame.height - segmentedControlTopPadding
        guard abs(segmentedControl.frame.origin.y - targetY) > 0.5 else { return }
        segmentedControl.frame.origin.y = targetY
    }

    private func insertAppearanceTab() {
        let vc = AppearanceSettingViewController()
        let item = NSTabViewItem(viewController: vc)
        item.label = NSLocalizedString("Appearance", comment: "")
        if #available(macOS 11.0, *) {
            item.image = NSImage(systemSymbolName: "paintbrush", accessibilityDescription: nil)
        } else {
            item.image = makeFallbackIcon(glyph: "🎨")
        }
        insertTabViewItem(item, at: 1)
    }
}

private extension NSView {
    func firstSubview<T: NSView>(ofType type: T.Type) -> T? {
        for subview in subviews {
            if let match = subview as? T {
                return match
            }
            if let match = subview.firstSubview(ofType: type) {
                return match
            }
        }
        return nil
    }
}
