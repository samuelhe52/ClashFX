### New Features

- **Bypass Common Chinese Apps Toggle** — Enhanced Mode menu now includes an opt-in toggle that injects a curated `PROCESS-NAME` rule-set into the generated config, letting high-frequency Chinese apps (WeChat, QQ, DingTalk, Feishu, Bilibili, etc.) bypass the proxy and go direct. The list is maintained at https://github.com/Clash-FX/cn-apps-direct and updates automatically every 24 hours. Defaults to off; existing users see no behavior change after update.
- **Hidden Proxy Groups Now Honored** — Proxy groups marked `hidden: true` in YAML are now filtered from the status bar menu, matching mihomo's documented semantics. Hidden groups still participate in speed tests and rule routing internally.

### Bug Fixes

- **Status Bar No Longer Shows Duplicate Icon On Restart** — Restarting ClashFX from the menu no longer leaves an old "Quitting…" menu bar icon next to the new instance. The restart flow now removes the status item immediately, tears down Enhanced Mode before relaunching, and waits for the new instance's `applicationDidFinishLaunching` before terminating the old one. Average restart takes 0.45–1.1 seconds and the menu bar transitions cleanly.
- **Launch Crash Under macOS 26 SDK Fixed** — `WKWebsiteDataStore` calls were moved back to the main queue. Under Xcode 26's stricter main-thread checker, calling these WebKit APIs from a background queue would crash the app on launch.

---
### 新功能

- **国内 App 直连开关** — 增强模式菜单新增"Bypass Common Chinese Apps"开关。打开后会在生成的配置顶部注入一个 rule-provider，引用 ClashFX 团队维护的 PROCESS-NAME 直连清单（https://github.com/Clash-FX/cn-apps-direct），让微信、QQ、钉钉、飞书、哔哩哔哩等高频客户端绕开代理走直连。名单每 24 小时自动更新，开关默认关闭，老用户升级后行为无变化。
- **隐藏代理组现在生效** — YAML 中标记 `hidden: true` 的代理组会从菜单栏隐藏，对齐 mihomo 文档语义。隐藏的组在内部仍参与测速和规则路由。

### 修复

- **重启后状态栏不再残留旧图标** — 从菜单重启 ClashFX 不会再出现新老两个图标并存、老图标卡在 "Quitting…" 的问题。重启流程改为立刻摘除老图标、先清理增强模式释放 mihomo_core 和端口、等待新实例 `applicationDidFinishLaunching` 后才退出老实例。重启平均耗时 0.45–1.1 秒，菜单栏切换干净无残留。
- **macOS 26 SDK 下启动崩溃修复** — `WKWebsiteDataStore` 调用移回主线程。Xcode 26 收紧的主线程检查器会在后台队列调用这些 WebKit API 时直接 crash 应用。
