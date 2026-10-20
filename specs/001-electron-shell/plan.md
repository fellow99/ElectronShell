# 001-electron-shell 技术方案（As-Built）

> 需求编号：001（Electron 浏览器壳）
> 对应规格：`specs/001-electron-shell/spec.md`
> 状态：已实现
> 最后更新：2026-10-20

---

## 1. 技术上下文

### 1.1 运行时环境

| 项 | 值 |
|----|----|
| 应用形态 | HarmonyOS Stage Model，单 entry HAP（模块名 `electron`） |
| 宿主 | HarmonyOS 6.x，真机 `HAD-W32`（2in1，API 26） |
| 编译 SDK | HarmonyOS 6.1.1（API 24，DevEco Studio 自带 SDK） |
| 兼容版本 | `compatibleSdkVersion = 6.0.0(20)`，`targetSdkVersion = 6.1.1(24)` |
| 浏览器内核 | Electron `v37.2.3-20260825.1`（`libelectron.so` + `libadapter.so` + `libffmpeg.so`） |
| 语言 | ArkTS（前端壳） + JavaScript（Electron 主进程） |
| 构建 | hvigor 6.1 + ohpm，签名由 DevEco 自动签名（华为 AGC profile）提供 |

### 1.2 依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| `web_engine`（本工程 HAR 模块） | 1.0.0 | 提供 `WebAbility`、`WebNodeHandleWindow`、`WebWindow` 等 Electron 承载能力与 46 个系统适配器 |
| `inversify` | ^6.0.1 | `web_engine` 内部 DI 容器 |
| `reflect-metadata` | ^0.1.13 | `web_engine` 装饰器元数据 |
| `@ohos/hypium` | 1.0.6 | 单元/UI 测试框架（脚手架保留） |
| `libadapter.so`（types） | — | `web_engine` 原生桥接口类型声明 |

---

## 2. 宪法符合性

| 原则（见 `specs/constitution.md`） | 结论 | 说明 |
|--------------|------|------|
| ArkTS First / 无动态类型 | ✅ | 新增 ArkTS 代码全部显式类型，未使用 `any`；JSON 仅在内核侧 JavaScript 中使用 |
| Stage Model | ✅ | 入口为 `EntryAbility extends WebAbility`（`UIAbility` 子类） |
| 组件可复用 | ✅ | 界面逻辑抽为 `ShellOverlay` 组件，`Index` 与 `NodeHandleWindow` 两个页面复用同一份实现 |
| 状态不可直改 | ✅ | 全部通过 `@State` 赋值触发刷新，未就地修改嵌套对象 |
| 单一职责 / 分层 | ✅ | `common`（常量与纯函数工具）、`service`（存储与内核通道）、`components`（视图）三层 |
| 关键路径可观测 | ✅ | 状态文件路径、发布序号、导航成功/失败均输出 `hilog` / Chromium 日志 |
| 资源来自既定来源 | ✅ | 内核二进制与 `resfile` 资源全部从 `harmonypc-electron` / `harmonypc-electron-versions` 提取，MD5 与 `runtime-manifest.json` 一致 |
| 不得硬编码凭据 | ⚠️ 部分 | `signing/gen-signing.sh` 与 `scripts/build.sh` 内含**调试**密钥口令（自签名材料、仅本机可用）；生产签名必须走 DevEco 自动签名，不落在仓库内 |

---

## 3. 关键技术决策

### 3.1 内容承载组件：优先 NodeHandle，回退 XComponent

`web_engine` 的 `WebBaseAbility.getContentPath()` 在 `IsSupportNodeHandleFeature()` 为真时加载 `pages/NodeHandleWindow`（`ContentSlot` 承载原生窗口），否则加载 `pages/Index`（`XComponent(SURFACE)`）。

**决策**：不覆盖 `getContentPath()`，而是把同一份 `ShellOverlay` 同时挂到两个页面上（`Stack` 叠加）。这样既能复用框架的形态判断，又保证两种承载方式下都有一致的控制层。真机（API 26）走 NodeHandle 路径，实测 ArkUI 层（浮动按钮 / 输入面板）可正常叠加显示在 Electron 内容之上。

### 3.2 ArkTS ↔ Electron 通信：应用级文件状态文件

**问题**：`web_engine` 内部的 `nativeContext.ExecuteCommand(CommandType.kOpenURL)` 未通过 `Index.ets` 导出，且 `CommandLineAdapter` 仅支持启动期参数。

**备选方案**：

| 方案 | 优点 | 缺点 | 结论 |
|------|------|------|------|
| A. 扩展 `web_engine/Index.ets` 导出 `JsBindingUtils` + `CommandType` | 直接调用原生命令 | 依赖未公开语义的 `kOpenURL` 行为；改动上游 barrel | 未采用 |
| B. `startAbility` 带 `uri` 触发 `onNewWant` | 无需改上游 | 经过 AbilityManager 一圈，副作用不可控（重复窗口风险） | 未采用 |
| C. 应用级文件状态文件 | 两端都在本工程内、行为完全可验证、无上游改动 | 需要轮询 | **采用** |

**实现**：状态文件 `<ApplicationContext.filesDir>/electron-shell-state.json`，内容 `{ "url": string, "seq": number }`。

- ArkTS 侧 `ElectronShellBridge.publish(url)` 覆盖写入并自增 `seq`；
- Electron 侧 `main.js` 默认取 `app.getPath('userData')`（启动参数 `--user-data-dir=/data/storage/el2/base/files/` 已指向同一目录），也支持 `--shell-state-file=<绝对路径>` 覆盖；
- 内核每 300ms 轮询一次，`seq` 变化即执行 `loadURL`；首次启动强制应用一次（`applyState(true)`），保证「先写完状态文件 → 再启动内核」的时序安全。

真机日志已确认两端路径一致：
```
ElectronShellBridge: state file: /data/storage/el2/base/files/electron-shell-state.json
Electron: [ElectronShell] state file: /data/storage/el2/base/files/electron-shell-state.json
```

### 3.3 内置 Electron 应用替换

`web_engine/src/main/resources/resfile/resources/app` 原本是「系统信息查看器」示例（含主进程 794 行、多个 HTML/导出脚本）。本工程替换为浏览器壳主进程：

- `main.js`（约 190 行）：创建无边框 `BrowserWindow`、状态文件轮询、`loadURL` / 空页面、`setWindowOpenHandler` 收敛新窗口、`will-navigate` 外链托管、`did-fail-load` / `did-finish-load` 日志；
- `blank.html`：无 URL 时的空页面（浅色/深色自适应，居中水印）；
- `package.json`：`main = main.js`；
- 删除示例专用文件（`system-info.html`、`help.html`、`calendar.html`、`tray.js`、`updater.js`、`i18n.js`、`export-*.js`、`locales/`）。

### 3.4 沉浸式全屏

`EntryAbility.onWindowStageCreate` 在 `super` 之后调用 `applyImmersiveFullScreen()`：

1. `this.updateAvoidAreaStatus(true)`（`WebBaseAbility` 提供的公共方法，内部设置 `setWindowLayoutFullScreen(true)` 并隐藏状态栏 / 导航指示条）；
2. 再显式 `setWindowLayoutFullScreen(true)` + `setSpecificSystemBarEnabled('status' | 'navigationIndicator', false)`；
3. 2in1 形态 `maximize(MaximizePresentation.ENTER_IMMERSIVE_DISABLE_TITLE_AND_DOCK_HOVER)`。

每一步独立 `try/catch`，能力缺失只记日志（手机、平板、TV、2in1 能力矩阵不同）。

### 3.5 URL 规整与校验

不复用 `URL` 全局对象（实测会把 `https://a.comhttps://b.com` 当合法地址），改为显式解析：

1. 去空白；2. 无 scheme 补 `https://`；3. 仅接受 `http/https`；4. 取 authority 段（到第一个 `/`、`?`、`#` 为止）；5. 端口若存在须为 1~5 位数字；6. 主机名须匹配域名规则或等于 `localhost`。

启动恢复额外经过 `ShellUrlHelper.isRestorable()`，避免把历史脏值送进内核（该缺陷在真机验证阶段被发现并修复）。

---

## 4. 数据模型

```ts
// 状态文件（磁盘）
interface ShellStatePayload {
  url: string;   // 规整后的 URL，空字符串表示回到空页面
  seq: number;   // 单调递增，内核以此判断"有新请求"
}

// 偏好存储（preferences: electron_shell_store）
last_url: string  // 最后一次确认的 URL
```

状态机（每次确认导航）：

```
[输入] --normalize--> [候选 URL] --isSupported?--> 否 --> [错误提示, 面板保持]
                                            |
                                            是
                                            v
             saveLastUrl() --> publish(url, seq+1) --> 面板收起
                                            |
                                            v
                   内核轮询发现 seq 变化 --> loadURL(url) --> did-finish-load / did-fail-load
```

---

## 5. 接口契约

### 5.1 对外提供

| 接口 | 位置 | 说明 |
|------|------|------|
| `ShellOverlay` | `electron/src/main/ets/components/ShellOverlay.ets` | 浏览器壳控制层组件（浮动按钮 + 输入面板） |
| `ShellUrlHelper.normalize/isSupported/isEmpty/isRestorable` | `electron/src/main/ets/common/ShellUrlHelper.ets` | URL 规整与校验纯函数 |
| `ShellUrlStore.getInstance().init/getLastUrl/saveLastUrl` | `electron/src/main/ets/service/ShellUrlStore.ets` | URL 持久化（preferences） |
| `ElectronShellBridge.getInstance().init/publish/getStateFilePath` | `electron/src/main/ets/service/ElectronShellBridge.ets` | 与内核的导航通道 |
| `ShellConstants` | `electron/src/main/ets/common/ShellConstants.ets` | 存储键名、状态文件名、断点常量 |

### 5.2 对外消费

| 依赖 | 用途 |
|------|------|
| `web_engine.WebAbility` | Ability 基类（窗口、生命周期、单实例、沉浸式工具方法） |
| `web_engine.WebNodeHandleWindow` | `ContentSlot` 承载 Electron 原生窗口（主路径） |
| `web_engine.WebWindow` | `XComponent` 承载 Electron 原生窗口（回退路径） |
| `@kit.ArkData` `preferences` | 键值持久化 |
| `@kit.CoreFileKit` `fileIo` | 状态文件写入 |
| `@kit.ArkUI` `window` | 窗口尺寸监听、全屏与系统栏控制 |

### 5.3 事件协议

| 事件 | 触发方 | 消费方 | 语义 |
|------|--------|--------|------|
| 状态文件 `seq` 变化 | ArkTS | Electron 主进程 | 发生一次新的导航请求 |
| `windowSizeChange` | 系统 | `ShellOverlay` | 重算响应式档位 |
| `did-finish-load` / `did-fail-load` | Chromium | 日志 | 导航结果可观测 |
| `setWindowOpenHandler` | 页面脚本 | Electron 主进程 | 新窗口请求收敛到当前窗口 |

---

## 6. 实现策略

### 6.1 架构模式

```
┌─────────────────────────────────────────────────────┐
│ ArkUI 层：Stack                                     │
│  ├─ Row { WebNodeHandleWindow() }   ← Electron 内容 │
│  └─ ShellOverlay()                  ← 控制层叠加    │
└───────────────┬─────────────────────┬───────────────┘
                │ RunBrowser/内容尺寸  │ preferences / 状态文件
                v                     v
┌───────────────────────────┐  ┌──────────────────────────┐
│ web_engine (HAR)          │  │ 应用沙箱                  │
│  WebAbility / NodeHandle  │  │  <files>/electron-shell-  │
│  46 个系统适配器           │  │  state.json (url, seq)    │
│  libadapter.so (JSI)      │  │  preferences: last_url    │
└─────────┬─────────────────┘  └────────────┬─────────────┘
          v                                 │ 300ms 轮询
┌───────────────────────────────────────────▼─────────────┐
│ Electron v37 主进程 (resources/app/main.js)             │
│  BrowserWindow(frame:false) → loadURL / blank.html      │
│  setWindowOpenHandler / will-navigate / did-fail-load   │
└─────────────────────────────────────────────────────────┘
```

### 6.2 关键算法

| 算法 | 位置 | 说明 |
|------|------|------|
| URL 规整 | `ShellUrlHelper.normalize` | 正则判 scheme，缺失补 `https://` |
| URL 校验 | `ShellUrlHelper.isSupported` | 手写 authority 解析 + 域名/端口校验 |
| 状态应用 | `main.js applyState` | `firstLoad || seq !== lastAppliedSeq` 才导航，避免重复刷新 |
| 响应式分档 | `ShellOverlay.applyWidth` | `px2vp` 后与 600/840 断点比较，决定面板宽度与控件尺寸 |

### 6.3 错误处理

| 场景 | 处理 |
|------|------|
| `setWindowLayoutFullScreen` / `setSpecificSystemBarEnabled` / `maximize` 失败 | `catch` + `hilog.warn`，不阻断启动 |
| `getLastWindow` / `windowSizeChange` 注册失败 | `hilog.error`，布局退回默认档位 |
| `preferences` 打开/读写失败 | `hilog.error`，URL 持久化降级为「本次会话有效」 |
| 状态文件写入失败 | `hilog.error` + `publish` 返回 `false`，本次导航不生效（面板仍收起，避免误以为成功） |
| 内核 `loadURL` 失败 | `.catch` → 记录 + 回退空页面 |
| `did-fail-load` | 记录 `code/desc/url` |

### 6.4 性能

- 状态轮询为单文件 `fs.readFileSync`（约 60 字节），300ms 一次，开销可忽略；
- `applyState` 先比较 `seq`，无变化直接返回，不做任何 URL 解析；
- 输入面板使用 `if` 条件渲染 + `TransitionEffect`，不常驻节点；
- 响应式重排仅在 `windowSizeChange` 回调中修改 2~3 个 `@State`，无布局重建。

---

## 7. 测试要点

| 类别 | 关注点 |
|------|--------|
| 纯函数 | `ShellUrlHelper.normalize/isSupported`：协议补全、非法拼接、端口、`localhost`、超长域名 |
| 持久化 | 首次启动无值、重启后读取、写入失败降级 |
| 通道 | 状态文件路径一致性、`seq` 单调、并发写入可容忍（JSON 解析失败即跳过） |
| UI | 浮动按钮展开/收起、错误提示、键盘「前往」、横竖屏与窗口拉伸 |
| 端到端 | 百度首页 → 新闻链接；threejs.org → examples → 具体示例 |
| 已知限制 | 平板非 PC 模式下原生窗口顶部内边距（`statusBarHeight` 由 `WebAbility` 写入 LocalStorage） |

---

## 8. 文件清单

| 文件 | 作用 | 行数 |
|------|------|------|
| `electron/src/main/ets/components/ShellOverlay.ets` | 浏览器壳控制层（按钮 + 输入面板 + 响应式 + 提交流程 + 焦点管理） | 272 |
| `electron/src/main/ets/common/ShellUrlHelper.ets` | URL 规整 / 校验 / 可恢复判定（含端口、IPv4/IPv6、长度上限） | 178 |
| `electron/src/main/ets/common/ShellConstants.ets` | 常量（存储键、状态文件名、断点） | 25 |
| `electron/src/main/ets/service/ShellUrlStore.ets` | preferences 持久化 | 87 |
| `electron/src/main/ets/service/ElectronShellBridge.ets` | 状态文件通道（临时文件 + rename 原子写） | 126 |
| `electron/src/main/ets/entryability/EntryAbility.ets` | 入口 Ability：启动发布初始 URL + 沉浸式全屏（含重放） | 159 |
| `electron/src/main/ets/pages/NodeHandleWindow.ets` | NodeHandle 承载页（叠加控制层） | 116 |
| `electron/src/main/ets/pages/Index.ets` | XComponent 承载页（叠加控制层） | 74 |
| `electron/src/main/resources/resfile/resources/app/main.js` | Electron 主进程（导航令牌、ERR_ABORTED 过滤、单窗口策略） | 293 |
| `electron/src/main/resources/resfile/resources/app/blank.html` | 空页面 | 52 |
| `electron/src/test/ShellUrlHelper.test.ets` | URL 规整与校验的 hypium 单测（13 组） | 87 |
| `scripts/build.sh` | 构建（hvigor + 可选本地签名，含依赖预检） | 92 |
| `scripts/assemble-resources.sh` | 从源工程装配内核资源并校验 MD5 | 99 |
| `signing/gen-signing.sh` | OpenHarmony 本地调试签名材料生成 | 107 |

---

## 8.1 权限清单与裁剪记录

`web_engine/src/main/module.json5` 的权限按**最小必要**原则裁剪，共移除 6 项上游权限：

| 移除的权限 | 等级 | 移除理由 | 功能影响 |
|-----------|------|---------|---------|
| `ohos.permission.READ_WRITE_DOCUMENTS_DIRECTORY` | user_grant / normal | 浏览器壳不做文档另存/目录浏览 | 网页无法直接写入「文档」目录 |
| `ohos.permission.READ_WRITE_DESKTOP_DIRECTORY` | user_grant / **system_basic** | 同上，且属受限权限 | 网页无法直接写入「桌面」目录 |
| `ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY` | user_grant / normal | 同上 | 网页无法直接写入「下载」目录 |
| `ohos.permission.FILE_ACCESS_PERSIST` | system_grant / normal | 仅为持久化文件选择器 URI 授权 | 文件选择器选择的 URI 重启后不再自动授权 |
| `ohos.permission.WEB_NATIVE_MESSAGING` | system_grant / **system_basic** | 未加载任何 Electron/Chrome 扩展 | `NativeMessagingAdapter` 通道不可用 |
| `ohos.permission.READ_PASTEBOARD` | user_grant / **system_basic** | 收敛受限权限；URL 输入框是 ArkUI 组件，粘贴由系统框架处理，不依赖本权限 | **网页内容内无法粘贴**（Ctrl+V / 右键粘贴）；写入剪贴板（复制）仍正常 |

配套代码清理：

- `PermissionManagerAdapter.needPermissions` 移除 `directory_download` / `directory_desktop` / `directory_document` / `pasteboard` 四个映射；原生侧再请求这些类型时走既有的 `unsupported permission` 分支并返回失败，不抛异常。
- `PermissionManagerAdapter.initPermissions()` 增加「无待恢复 URI 时短路」，避免调用依赖 `FILE_ACCESS_PERSIST` 的 `fileShare.activatePermission`。
- 删除 `openPermissionConfirm` 的 `pasteboard` 分支与 `openPasteboardPermissionConfirm()` 死代码，避免把用户引导到并不存在的剪贴板开关。

**保留的关键受限权限**：`ohos.permission.kernel.ALLOW_WRITABLE_CODE_MEMORY` 必须保留——Electron 内置的 V8 启用 JIT（启动参数无 `--jitless`），需要在运行时申请可写且可执行的内存页，鸿蒙默认禁止；移除后表现为启动阶段白屏/崩溃，且不会在 Electron 日志里给出权限名称（由系统在 mmap 阶段拒绝）。

裁剪后剩余：`requestPermissions` 22 项 + `definePermissions` 2 项。

---

## 9. 已知风险（评审登记，暂不修复）

| 编号 | 风险 | 影响 | 处置 |
|------|------|------|------|
| R-1 | `BrowserWindow` 使用 `sandbox: false` | 加载任意远程页面时，Chromium 漏洞的影响面比开启沙箱更大 | 已在代码注释与本表登记；页面侧启用 `nodeIntegration:false` + `contextIsolation:true`。**待验证** OHOS 移植是否支持 `sandbox: true`，可行时应开启 |
| R-2 | 窗口 `backgroundColor` 固定白色，空页面支持深色 | 深色系统下加载空页可能有一次闪白 | 影响 <100ms；改为跟随 `nativeTheme` 需验证移植接口，列入演进项 |
| R-3 | 控制层用固定边距而非安全区 | 若系统导航条隐藏失败，输入面板可能压到手势条区域 | 已通过沉浸式设置重放降低概率；彻底方案需读 `AvoidArea` 做安全区布局 |
| R-4 | 不支持 IDN（如 `https://例子.中国`） | 中文域名需用户自行输入 punycode | 与规格一致（规格只要求域名或 localhost），列为演进项 |
| R-5 | 状态文件轮询 300ms | 地址确认到内核开始加载最多约 300ms | 可改 `fs.watch`，需验证 OHOS inotify 可用性 |
