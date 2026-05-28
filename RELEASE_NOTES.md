### Bug Fixes

- **Ignore List in Rule Mode Now Actually Bypasses** — `More Settings → Ignore List` entries were previously ignored by mihomo in Rule mode, leaving the toggle a silent no-op for users not on Enhanced Mode. ClashFX now translates each entry into the appropriate `DOMAIN` / `DOMAIN-SUFFIX` / `IP-CIDR` / `IP-CIDR6` `DIRECT` rule and injects them ahead of your existing `rules:` into a runtime config consumed by mihomo, so bypass entries take effect immediately on reload. Your source config file is never modified. Enhanced Mode and iCloud configs are skipped intentionally and fall back to the original behavior. (#110, #104)
- **WebSocket Crash on Traffic/Log Stream Fixed** — Sparse `EXC_BAD_ACCESS` crashes inside `_outputStreamCallbackFunc` under the `com.vluxe.starscream.websocket` queue have been eliminated by upgrading Starscream from 3.1.1 to 4.0.8. The stream lifecycle was rewritten around the new event-based delegate, with manual connection tracking, `forceDisconnect()` retire semantics, assign-before-connect ordering, main-thread retry timers, and `.peerClosed` handling so the menu bar speed indicator and Connections panel recover cleanly across network changes, sleep/wake, and core restarts. (#109)
- **Disable Enhanced Mode Re-applies Ignore List Rules** — When you toggle Enhanced Mode off, the subsequent config reload now routes through the same rule-patching path as a manual reload, so any configured Ignore List entries are immediately reflected in Rule mode instead of waiting for the next manual reload.

---

### 修复

- **规则模式下「忽略 list」终于真正生效** — 此前在规则模式下，`More Settings → Ignore List` 里的条目并不会被 mihomo 识别，对没开增强模式的用户来说就是个静默失效的开关。现在 ClashFX 会把每条记录翻译成对应的 `DOMAIN` / `DOMAIN-SUFFIX` / `IP-CIDR` / `IP-CIDR6` `DIRECT` 规则，并在加载配置时拼到你原有 `rules:` 的最前面，写入一个内部运行时配置喂给 mihomo，所以忽略条目下次加载即时生效。原始配置文件不会被改动。增强模式和 iCloud 配置会按原行为继续走，不参与注入。(#110, #104)
- **流量 / 日志 WebSocket 偶发崩溃修复** — 队列 `com.vluxe.starscream.websocket` 中 `_outputStreamCallbackFunc` 偶发的 `EXC_BAD_ACCESS` 已经通过把 Starscream 从 3.1.1 升级到 4.0.8 修掉。流监听逻辑围绕新的事件式 delegate 重写，加上手动连接状态跟踪、`forceDisconnect()` 回收语义、先赋值后 connect、主线程重试 timer、`.peerClosed` 处理，菜单栏速率指示器和连接面板在网络切换、睡眠/唤醒、内核重启之后都能干净恢复。(#109)
- **关闭增强模式后忽略 list 立即生效** — 关掉增强模式后的那次自动重载现在会走同样的规则注入路径，规则模式下的忽略 list 不用再手动重载一次。
