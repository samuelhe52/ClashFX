### Bug Fixes

- **Menu Bar Speed Indicator No Longer Shakes** — The upload/download speed text now redraws inside a stable menu bar item width instead of resizing the whole status item whenever the number of digits changes, so nearby menu bar icons no longer jump when speeds cross values like `9.xx` → `10.xx`. (#122)
- **Enhanced Mode Restore Is More Reliable After Restart** — When ClashFX launches with Enhanced Mode previously enabled, it now retries the restore flow for up to about one minute while the privileged helper and external core come online. This avoids giving up after a single early attempt during app or macOS startup. (#123)

### Contributors

- @pengtalk — Reported the menu bar speed indicator width jitter (#122)
- @pengtalk — Reported Enhanced Mode not reliably restoring after restart (#123)

---

### 修复

- **菜单栏网速显示不再抖动** — 上传 / 下载速度文字现在会在固定宽度的菜单栏区域内重绘，不再因为数字位数变化而调整整个状态栏图标宽度，因此网速从 `9.xx` 变成 `10.xx` 时旁边图标不会再跳动。(#122)
- **增强模式重启恢复更可靠** — 如果退出或重启前已开启增强模式，ClashFX 启动后现在会在约一分钟内持续重试恢复流程，等待 privileged helper 和外部核心就绪，避免在应用或系统刚启动时只尝试一次就放弃。(#123)

### 贡献者

- @pengtalk — 反馈菜单栏网速显示宽度变化导致图标抖动的问题 (#122)
- @pengtalk — 反馈重启后增强模式不能稳定自动恢复的问题 (#123)

<!-- Previous release notes -->

---

### Bug Fixes

- **Enhanced Mode Now Respects Your `tun.stack` Setting** — The generated `.enhanced_config.yaml` previously hardcoded `stack: mixed`, silently overriding a user-configured `tun.stack`. If your config set `system` (or `gvisor`), the dashboard showed `mixed` and reverting it never stuck. ClashFX now reads `tun.stack` from your source config, validates it against `system`/`gvisor`/`mixed` (case-insensitive), and only falls back to `mixed` when it is unset or invalid. Both the embedded and external core paths use the same resolved value so they never diverge. (#115)
- **Dashboard Theme & Column Settings Now Persist** — In Enhanced Mode the external controller was assigned a random port on every launch, so the Yacd dashboard origin (`127.0.0.1:PORT`) changed each time and its per-origin `localStorage` (theme, custom columns) appeared to reset. ClashFX now pins a stable controller port (`19090`) and only falls back to a random free port if that port is already taken, keeping the dashboard origin — and your saved preferences — stable across launches. (#115)
- **Enhanced Mode Startup Is More Resilient** — Enabling Enhanced Mode now automatically retries once when the external core fails to bind (e.g. a transient port race or a leftover `mihomo_core` process holding the controller port). Each retry regenerates the config with a fresh port instead of failing outright, so toggling Enhanced Mode on is far less likely to error out and require a manual retry.
- **Reopening ClashFX Reveals the Menu Bar Icon** — When ClashFX is already running and you launch it again from Finder, Spotlight, Launchpad, or the Dock, it now pops open the menu bar menu so you can locate the icon — helpful when the menu bar is crowded and the icon is hidden. Thanks @hangox for the suggestion. (#114)

### Contributors

- @hangox — Suggestion to reveal the menu bar item when reopening an already-running app (#114)

---

### 修复

- **增强模式现在会尊重你的 `tun.stack` 设置** — 之前生成的 `.enhanced_config.yaml` 硬编码 `stack: mixed`，会静默覆盖用户配置的 `tun.stack`。如果你配置了 `system`（或 `gvisor`），控制台却显示 `mixed`，改回去也不生效。现在 ClashFX 会从源配置读取 `tun.stack`，按 `system`/`gvisor`/`mixed`（不区分大小写）校验，仅在未设置或非法时才回退到 `mixed`。内置核心与外部核心两条路径使用同一个解析结果，不会再不一致。(#115)
- **控制台主题与列设置现在能持久保存** — 增强模式下外部控制器每次启动都分配随机端口，导致 Yacd 控制台的 origin（`127.0.0.1:端口`）每次都变，其按 origin 隔离的 `localStorage`（主题、自定义列）看起来被重置。现在 ClashFX 固定使用稳定的控制器端口（`19090`），仅当该端口被占用时才回退到随机空闲端口，从而让控制台 origin —— 以及你保存的偏好 —— 在多次启动间保持稳定。(#115)
- **增强模式启动更稳健** — 开启增强模式时，若外部核心绑定失败（例如瞬时端口竞争，或残留的 `mihomo_core` 进程仍占用控制器端口），现在会自动重试一次。每次重试都会用新端口重新生成配置，而不是直接报错，因此开启增强模式更不容易失败、无需手动重试。
- **重新打开 ClashFX 时会弹出菜单栏图标** — 当 ClashFX 已在运行、你又从访达 / Spotlight / 启动台 / Dock 再次打开它时，现在会自动弹出菜单栏菜单，方便你定位图标 —— 在菜单栏拥挤、图标被隐藏时尤其有用。感谢 @hangox 的建议。(#114)

### 贡献者

- @hangox — 建议在重复打开已运行的 app 时显示菜单栏项 (#114)
