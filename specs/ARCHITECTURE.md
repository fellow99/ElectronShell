# ElectronShell 整体架构

> 最后更新：2026-10-20
> 本文描述**已实现**的架构（As-Built），所有层次与调用关系均可在代码中核对。

---

## 1. 分层视图

```
┌──────────────────────────────────────────────────────────────────────────┐
│ 表现层（ArkUI / ArkTS）                                                   │
│  ├─ pages/NodeHandleWindow.ets     ContentSlot 承载（主路径）             │
│  ├─ pages/Index.ets                XComponent 承载（回退路径）            │
│  └─ components/ShellOverlay.ets    浮动按钮 + 底部 URL 面板 + 三档响应式  │
├──────────────────────────────────────────────────────────────────────────┤
│ 业务/服务层（ArkTS service）                                              │
│  ├─ service/ShellUrlStore.ets      preferences 持久化（last_url）         │
│  ├─ service/ElectronShellBridge.ets 状态文件通道（url + seq，300ms 轮询） │
│  └─ common/ShellUrlHelper.ets      URL 规整 / 校验（纯函数，无 IO）       │
├──────────────────────────────────────────────────────────────────────────┤
│ 宿主能力层（web_engine HAR，上游）                                        │
│  ├─ ability/WebAbility.ets         窗口、生命周期、单实例、沉浸式工具      │
│  ├─ components/WebNodeHandleWindow.ets / WebWindow.ets                    │
│  ├─ adapter/*（46 个）             系统能力适配（Window/File/Print/…）    │
│  ├─ jsbindings/*（45 个）          JSI 绑定声明                           │
│  └─ cpp/types/libadapter           libadapter.so 原生桥（N-API）          │
├──────────────────────────────────────────────────────────────────────────┤
│ 内核层（Electron v37.2.3，原生多进程）                                    │
│  ├─ resources/app/main.js          BrowserWindow + 导航 + 事件            │
│  ├─ libelectron.so（183MB）        浏览器引擎（Chromium + Node）          │
│  ├─ libffmpeg.so / libadapter.so   媒体与鸿蒙适配                          │
│  └─ resfile/*                      pak / icudtl / locales / snapshot      │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 2. 运行时拓扑

```
        ┌─────────────────────────────────────────────┐
        │ HarmonyOS 系统（窗口管理 / 输入法 / 网络）   │
        └───────┬───────────────────────┬─────────────┘
                │ window/SystemBar API  │ 触摸事件
                v                       v
┌───────────────────────────────────────────────────────────────┐
│ 应用主进程（org.fellow99.ElectronShell）                            │
│  ArkTS 运行时 ── WebAbility ── LocalStorage（xcomponentId 等）  │
│      │                                                        │
│      │ ContentSlot(NodeContent) / XComponent(SURFACE)          │
│      v                                                        │
│  Electron 主进程（同进程内嵌 chromium 子进程）                  │
│   ├─ BrowserWindow(frame:false)                                │
│   ├─ :Renderer   ← 网页渲染（进程名 org.fellow99.ElectronShell:Renderer）│
│   ├─ :GPU        ← 合成/光栅                                    │
│   └─ :NetworkService ← 网络                                     │
└───────────────────────────────────────────────────────────────┘
```

真机观察到的子进程（`ps -A`）：`org.fellow99.ElectronShell`（主）、`:Renderer`、`:GPU`、`:NetworkService`、`:browser`。

---

## 3. 数据流

### 3.1 启动（有本地 URL）

```
EntryAbility.onCreate
  └─ WebAbility.onCreate（分配 xcomponentId、初始化适配器）
EntryAbility.onWindowStageCreate
  ├─ WebAbility.onWindowStageCreate（监听窗口事件、loadContent(pages/NodeHandleWindow)）
  └─ applyImmersiveFullScreen（layoutFullScreen + 隐藏系统栏 + 2in1 最大化）
页面渲染 → ShellOverlay.aboutToAppear
  ├─ ShellUrlStore.init + getLastUrl
  ├─ isRestorable(url) ?
  │    是 → urlText=url；ElectronShellBridge.publish(url)   ← 写状态文件
  │    否 → editorVisible=true；publish('')                 ← 清空状态文件
  └─ attachSizeListener
WebNodeHandleWindow.aboutToAppear → nativeContext.runBrowser(args)  ← 启动内核
Electron main.js：applyState(true) → loadURL(状态文件中的 url) 或 loadFile(blank.html)
```

关键时序保证：**ArkTS 先写状态文件，再由内容组件启动内核**；内核首帧强制应用一次状态，因此「上次访问的 URL」不会丢。

### 3.2 用户导航

```
用户点击浮动按钮 → editorVisible=true（TextInput 获得焦点）
用户输入 → TextInput.onChange → urlText
用户点「前往」/键盘 Go → ShellOverlay.submit()
  ├─ ShellUrlHelper.normalize(urlText)       补 https://
  ├─ ShellUrlHelper.isSupported(url)         不合法 → errorText，结束
  ├─ ShellUrlStore.saveLastUrl(url)          preferences 落盘
  ├─ ElectronShellBridge.publish(url)        状态文件 {url, seq+1}
  └─ editorVisible=false                     面板收起
Electron（轮询 300ms）
  ├─ seq 变化 → loadURL(url)
  ├─ did-finish-load / did-fail-load         日志
  └─ 失败 → showBlankPage()
```

### 3.3 页内交互

| 页面行为 | Electron 处理 |
|---------|--------------|
| 普通链接点击 | 默认导航（同窗口） |
| `target="_blank"` / `window.open` | `setWindowOpenHandler` → `loadURL` 到当前窗口，`action: 'deny'` |
| 非 http/https 协议 | `will-navigate` → `preventDefault` + `shell.openExternal` |

---

## 4. 模块职责边界

| 模块 | 职责 | 不负责 |
|------|------|--------|
| `AppScope` | bundleName、版本、图标、应用名 | 业务逻辑 |
| `electron`（entry HAP） | 应用入口、页面、壳 UI、持久化、内核通道 | 系统能力适配 |
| `web_engine`（HAR） | Electron 承载组件、Ability 基类、46 类系统能力适配、窗口样式 | 业务交互、URL 策略 |
| `resources/app`（Electron 应用） | 窗口创建、导航、页面生命周期、协议处理 | 读取应用偏好存储（只读状态文件） |
| `scripts/` | 资源装配、构建、签名 | 运行时代码 |

---

## 5. 部署与运行

### 5.1 产物

| 产物 | 路径 | 体积（实测） |
|------|------|-------------|
| 未签名 HAP | `electron/build/default/outputs/default/electron-default-unsigned.hap` | ≈202MB |
| 已签名 HAP | `electron/build/default/outputs/default/electron-default-signed.hap` | ≈203MB |

> HAP 体积主要来自 `libelectron.so`（181MB）。安装后应用数据目录 `/data/app/el2/100/base/org.fellow99.ElectronShell` 约 400MB（含 Chromium 缓存）。

### 5.2 安装与启动

```bash
hdc app install -r electron/build/default/outputs/default/electron-default-signed.hap
hdc shell aa start -a EntryAbility -b org.fellow99.ElectronShell
```

### 5.3 运行期关键路径（用于排障）

| 路径 | 内容 |
|------|------|
| `/data/app/el2/100/base/org.fellow99.ElectronShell/files/electron-shell-state.json` | ArkTS → Electron 的导航状态（`url`/`seq`） |
| `/data/app/el2/100/base/org.fellow99.ElectronShell/haps/electron/preferences/electron_shell_store` | 偏好存储（`last_url`） |
| `/data/storage/el1/bundle/electron/resources/resfile/resources/app/` | 随包的 Electron 应用 |
| `/data/storage/el1/bundle/libs/arm64/` | 解压出的 `.so` |

---

## 6. 关键架构决策与权衡

| 决策 | 取舍 | 依据 |
|------|------|------|
| 双层承载（ContentSlot 优先 / XComponent 回退） | 兼容 API 差异，代价是两份页面代码 | `WebBaseAbility.getContentPath()` 与 `IsSupportNodeHandleFeature()` |
| ArkUI 控制层叠加在原生内容之上 | 无需改动内核窗口布局；依赖 `HitTestMode.Transparent` 保证网页可交互 | 真机验证叠加显示与点击均正常 |
| 文件状态文件代替 IPC | 简单、可验证、无上游改动；代价是 300ms 轮询延迟 | `web_engine` 未导出 `ExecuteCommand`，`startAbility` 路径副作用不可控 |
| 替换内置 Electron 示例应用 | 完全掌控窗口与导航行为；代价是放弃示例中的系统信息能力 | 需求是浏览器壳，不是示例应用 |
| 沉浸式全屏在 Ability 层完成 | 与窗口生命周期绑定、失败可降级 | `updateAvoidAreaStatus` + `setSpecificWindowBarEnabled` |

---

## 7. 已知限制

| 限制 | 说明 | 影响 |
|------|------|------|
| 平板「非 PC 模式」顶部内边距 | `WebAbility.onPadWindowStageCreate` 会把系统 `statusBarHeight` 写入 LocalStorage，`WebNodeHandleWindow` 用其内缩原生窗口；`EntryAbility` 已通过 600ms 延时重放 + 回前台/配置变更重放来消除状态栏复现 | 2in1 与 PC 模式不受影响；平板非 PC 模式若仍留白，属上游 LocalStorage 写入所致（见 `001-electron-shell/plan.md` R-3） |
| 导航延迟 300ms | 状态文件轮询周期 | 用户可感知极小；如需更快可改 `fs.watch` |
| 单窗口 | `setWindowOpenHandler` 全部收敛到当前窗口 | 不支持多标签/弹窗浏览 |
| 仅 http/https | `isSupported` 白名单 | `file://`、`chrome://` 不可通过输入框访问 |
| 真机签名依赖 DevEco | 需华为账号自动签名 | CI 环境需预置 profile 或改用 OpenHarmony 设备 |
| 渲染进程未开沙箱 | `sandbox: false`（移植支持情况未验证） | 见 `001-electron-shell/plan.md` R-1 |
