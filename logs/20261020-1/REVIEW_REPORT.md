# 代码评审报告 2026-10-20 / 01

> 需求：001-electron-shell
> 评审方式：`requesting-code-review`（派发独立评审代理，只给代码与规格，不给会话历史）
> 处置方式：`receiving-code-review`（逐条核对代码事实后再决定修复 / 记录 / 反驳）
> 评审范围：本次新增/修改的 10 个代码与脚本文件（`web_engine` 其余部分为上游产物，不在范围）

---

## 1. 评审输入

| 项 | 内容 |
|----|------|
| 规格 | `specs/001-electron-shell/spec.md`（FR-001-001 … FR-001-053） |
| 方案 | `specs/001-electron-shell/plan.md` |
| 用例 | `specs/001-electron-shell/test-cases.md` |
| 代码 | `ShellOverlay.ets`、`ShellUrlHelper.ets`、`ShellConstants.ets`、`ShellUrlStore.ets`、`ElectronShellBridge.ets`、`EntryAbility.ets`、`pages/NodeHandleWindow.ets`、`pages/Index.ets`、`resources/app/main.js`、`resources/app/blank.html`、`scripts/build.sh`、`scripts/assemble-resources.sh`、`signing/gen-signing.sh` |

评审员给出的结论摘要：主链路设计自洽，风险集中在 **Electron 侧回退策略** 与 **状态文件通道的原子性/时序**；另有 5 处与规格的明确差距（平板状态栏、输入框自动聚焦、紧凑档宽度、`window.open` 协议分流、`did-fail-load` 回退）。

---

## 2. Critical（已全部修复）

| 编号 | 问题 | 核对结果 | 修复 |
|------|------|---------|------|
| C-1 | `loadURL()` 在被新导航顶替时以 `ERR_ABORTED` reject，`.catch` 会 `showBlankPage()`，把正在进行的正确导航打断，且 `lastAppliedSeq` 已更新导致不再重试 | **确认成立**。`applyState` 先写 `lastAppliedSeq` 再 `loadURL`，catch 无条件回退空页 | `main.js` 新增 `isAbortedError()` 与导航令牌 `navToken`：`ERR_ABORTED` 直接返回；仅当令牌仍为最新时才回退空页 |
| C-2 | `did-fail-load` 只打日志，未回退空页，与 FR-001-033 不符；未判 `isMainFrame`，子框架失败也当导航失败 | **确认成立** | `did-fail-load` 增加 `isMainFrame === false || errorCode === ERR_ABORTED` 早退；主框架失败时重新应用状态（回退空页），并跳过 `blank.html` 自身失败避免循环 |

---

## 3. Important（除 I-10 外全部处理）

| 编号 | 问题 | 核对结果 | 处置 |
|------|------|---------|------|
| I-1 | 框架在 `loadContent` 回调里对平板调用 `updateAvoidAreaStatus(false)` 重新显示状态栏，时序晚于我们的同步设置 | **确认成立**（`WebAbility.ets` 的 `getMainWindow`/`loadContent` 回调 + `onPadWindowStageCreate`） | `EntryAbility` 在 `onWindowStageCreate` 后延时 600ms 兜底重放一次，并在 `onForeground`、`onConfigurationUpdate` 再次重放 |
| I-2 | `defaultFocus(true)` 只在页面首次获焦生效，动态展开的面板不会自动聚焦，违反 FR-001-021 | **确认成立** | 移除 `defaultFocus`，`openEditor()` 后在 `setTimeout(0)` 中调用 `getUIContext().getFocusController().requestFocus(INPUT_ID)` |
| I-3 | `aboutToDisappear` 早于 `getLastWindow` promise 兑现时，监听器注册到已销毁组件且永不 `off` | **确认成立** | 新增 `disposed` 标志；promise 回调先判断；`detachSizeListener` 只以 `sizeListener` 判空，解耦 `hostWindow` |
| I-4 | `WebNodeHandleWindow` 的 `aboutToAppear` 先于 `ShellOverlay` 启动内核，`publish()` 晚于内核首帧读取 | **确认成立**（构建顺序），真机日志显示通常 publish 更快，但不保证 | 把「读本地 URL + publish」前移到 `EntryAbility.onCreate`（早于 `onWindowStageCreate`）；`ShellOverlay` 不再在启动时发布 |
| I-5 | `readState()` 任何异常都归一成 `seq=0, url=''`，会被当成一次「新状态」触发空页并打断在飞导航 | **确认成立** | 三态区分：`ENOENT` → 空状态；解析失败/读失败 → 返回 `null`，`applyState` 直接跳过、不改 `lastAppliedSeq` |
| I-6 | 状态文件 `TRUNC` 后再写，存在 0 字节/半截 JSON 窗口；`seq` 在写成功前提交 | **确认成立** | 改为「临时文件 + `fsyncSync` + `renameSync` 原子替换」，`seq` 落盘成功后才提交 |
| I-7 | `setWindowOpenHandler` 对非 http/file 协议静默丢弃，`about:blank` 也不处理 | **确认成立** | 可加载 URL 与 `about:blank` 收敛到当前窗口；其余协议 `shell.openExternal` 并记录失败 |
| I-8 | 紧凑档面板实际宽度 ≈ 88% < FR-001-052 要求的 90%（百分比以带 padding 的父容器为基准） | **确认成立** | 紧凑档内层宽度改为 `100%`，并把父级左右 padding 从 8vp 降到 4vp（实测 ≈95%） |
| I-9 | `closed` 与 `activate` 路径下轮询定时器未清理，窗口重建会叠加定时器 | **确认成立** | `createShellWindow()` 开头与 `closed` 回调内均 `clearInterval` |
| I-10 | 加载任意远程页面时 `sandbox: false`，理论上放大 Chromium 漏洞影响面 | **部分确认**：本地确实显式关闭沙箱；但 Electron for HarmonyOS 移植是否支持渲染进程沙箱无法在本机验证 | **不修复，登记风险**：代码注释与 `SPEC.md`/`plan.md` 风险章节说明；页面侧已启用 `nodeIntegration:false` + `contextIsolation:true`。若后续验证沙箱可用，应优先打开 |
| I-11 | `ShellUrlHelper` 无单元测试 | **确认成立** | 新增 `electron/src/test/ShellUrlHelper.test.ets`（13 组用例，hypium），覆盖拼接串、端口越界、IPv4/IPv6、大小写、尾点、超长、路径空格。**未在本机执行**（需 `hvigorw onDeviceTest` + 设备空闲） |
| I-12 | `build.sh` 以「signed.hap 是否存在」判断 hvigor 是否已签名，会误认上次遗留产物 | **确认成立** | 构建前 `rm -f` 两个产物再判断；同时改为直接调用 `hvigorw.bat`（避免 `cmd //c` 在含空格路径下的引号问题） |

---

## 4. Minor（已处理的项）

| 编号 | 问题 | 处置 |
|------|------|------|
| M-1 | 端口只校验位数，`0` / `99999` 可通过 | 新增 `isValidPort()`：1~65535 |
| M-2 | IPv6、`LOCALHOST` 大写、结尾点被拒 | 支持 `[::1]` / `[::1]:port`；host 转小写比较；去掉单个结尾点 |
| M-3 | 任何空白都判非法，路径带空格无法通过 | 仅对 authority 段禁空白，路径/查询允许空格 |
| M-4 | 无长度上限 | `isSupported` 增加 2048 上限；`TextInput` 增加 `maxLength(2048)` |
| M-5 | 本地非法值未清理，每次启动重复命中 | `EntryAbility.publishInitialUrl()` 中发现非法值时 `saveLastUrl('')` 并打日志 |
| M-6 | `applyWidth` 重复判断同一条件 | 合并为 `if (this.compact)` |
| M-7 | `maximize` 在所有形态无条件调用 | 仅 `deviceInfo.deviceType === '2in1'` 时调用；并在配置变更/回前台时重放沉浸式设置 |
| M-8 | `openExternal` 失败被完全吞掉 | 改为记录错误码与 URL |
| M-11 | `assemble-resources.sh` 的 `--from` 空参静默回退、缺 python/`.so` 时报原始错误 | 增加参数校验、`command -v python` 与三个 `.so` 的存在性预检 |
| M-12 | `gen-signing.sh` 变量名拼写 `DEVeCO_ROOT`，读不到 `DEVECO_ROOT` 环境变量 | 修正为 `DEVECO_ROOT` |
| M-13 | `build.sh` 缺依赖预检、口令硬编码 | 增加签名材料与工具预检并给出指引；口令支持 `SIGN_PWD` 环境变量覆盖 |

## 5. Minor（记录不修，理由）

| 编号 | 问题 | 不修理由 |
|------|------|---------|
| M-9 | 窗口底色写死白色，深色系统下加载空页会闪白 | 影响为一次 <100ms 的闪白；改为跟随 `nativeTheme` 需额外验证 OHOS 移植的主题接口，收益低。记录在 `plan.md` 已知限制 |
| M-10 | 控制层用固定边距而非安全区，导航条隐藏失败时面板可能压到手势条 | 与 I-1 同源；已通过重放沉浸式设置降低概率。彻底方案需读取 `AvoidArea` 并做安全区布局，改动面较大，纳入演进项 |
| M-2（IDN） | `https://例子.中国` 被拒 | 与规格一致（规格只要求「域名或 localhost」）；IDN 支持需自定义 punycode，列为演进项 |

---

## 6. 规格一致性复核（修复后）

| 需求 | 修复前 | 修复后 |
|------|-------|-------|
| FR-001-001/002（全屏覆盖系统栏） | 平板形态会被框架回显状态栏 | ✅ 延时重放 + 回前台/配置变更重放 |
| FR-001-021（面板展开自动聚焦） | ❌ 仅首次生效 | ✅ `FocusController.requestFocus` |
| FR-001-031（新窗口收敛） | 丢弃 `about:blank` | ✅ 收敛 |
| FR-001-032（外部协议交系统） | ❌ 静默丢弃 | ✅ `openExternal` + 错误日志 |
| FR-001-033（失败回退空页 + 日志） | 仅 promise 路径 | ✅ promise + `did-fail-load`（限主框架） |
| FR-001-052（面板宽度） | 紧凑档 ≈88% | ✅ ≈95% |
| FR-001-013（非法历史值处理） | 未清理脏值 | ✅ 视为无 URL 并清理 |

---

## 7. 复评与验证

| 验证项 | 结果 |
|--------|------|
| ArkTS 编译（`hvigorw assembleHap`） | ✅ BUILD SUCCESSFUL（含全部 ArkTS 改动） |
| `main.js` 语法（`node --check`） | ✅ 通过 |
| 脚本语法（`bash -n` × 3） | ✅ 通过 |
| 真机安装 | ✅ `install bundle successfully` |
| 真机冒烟：重启后直接加载上次 URL、面板收起、浮动按钮就位（验证 I-4/I-6） | ✅ 截图 |
| 真机回归：threejs `examples` → 具体示例（验证 C-1/C-2 未引入回归） | ✅ 示例页 WebGL 以 60 FPS 渲染 |
| 单测（`ShellUrlHelper.test.ets`） | ⚠️ 未执行（需 `onDeviceTest` 与设备空闲） |

---

## 8. 结论

- Critical 2 项、Important 11 项已修复并重新编译验证；`I-10`（沙箱）与 `M-9/M-10`（主题、安全区）作为**已知风险/演进项**记录，不阻塞本期交付；
- 无遗留 Critical；
- 建议下一轮：执行 `ShellUrlHelper` 单测、在平板形态验证 I-1 的最终效果、评估开启渲染进程沙箱。
