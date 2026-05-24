### New Features

- **Refined Menu Bar Icon Choices** — Appearance settings now present a cleaner built-in menu bar icon set, with the new outline and solid cat-face icons promoted to the first choices after Default.

### Bug Fixes

- **Settings Window Layout Loop Fixed** — Opening Appearance settings no longer triggers the AppKit layout-pass loop crash, and the icon/menu settings area remains scrollable.
- **Built-in App Icon Visual Size Normalized** — Built-in app icons now keep transparent visual padding inside their 1024×1024 assets so they appear closer to standard macOS Dock icon sizing.
- **Menu Bar Icon Labels Simplified** — Built-in menu bar icon names no longer include generic “scheme/variant” prefixes across supported languages.

---
### 新功能

- **菜单栏图标方案优化** — 外观设置现在提供更精简的内置菜单栏图标列表，并将新的线框猫脸和实心猫脸提升到默认图标后的前两位。

### 修复

- **设置窗口布局循环崩溃修复** — 打开外观设置时不再触发 AppKit layout pass loop 崩溃，图标和托盘菜单设置区域也能正常滚动。
- **内置应用图标视觉尺寸校准** — 内置应用图标在 1024×1024 资源中保留透明视觉边距，使 Dock 中显示大小更接近 macOS 标准图标。
- **菜单栏图标名称简化** — 所有支持语言中的内置菜单栏图标名称都移除了“方案/Variant”等通用前缀。
