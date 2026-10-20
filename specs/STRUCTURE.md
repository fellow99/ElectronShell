# ElectronShell 工程结构

> 生成时间：2026-10-20
> 统计口径：`git ls-files`（227 个受版本管理文件）。Electron 二进制 `electron/libs/**`（183MB）与运行时资源 `web_engine/src/main/resources/resfile/*`（除 `resources/app`）由 `scripts/assemble-resources.sh` 装配，不入库。

---

## 1. 顶层结构

```
ElectronShell/
├── AppScope/                       # 应用级配置与资源（bundleName / 图标 / 名称）
│   ├── app.json5                   # bundleName=org.fellow99.ElectronShell, versionName=1.0.0
│   └── resources/base/
│       ├── element/string.json      # app_name = ElectronShell
│       ├── media/                  # ★ 应用图标 app_icon.png（1024×1024 RGBA，被 app.json5 的 icon 引用）
│       └── profile/configuration.json
├── electron/                        # ★ 主 entry HAP 模块（应用本体）
│   ├── src/main/ets/               # ArkTS 源码
│   ├── src/main/resources/         # 字符串 / 颜色 / main_pages.json / shortcuts_config.json
│   ├── src/main/module.json5       # 3 个 UIAbility + 2 个 ExtensionAbility 声明
│   ├── src/test/                   # 本地单测脚手架（hypium）
│   ├── src/ohosTest/               # 仪器化测试脚手架
│   ├── libs/arm64-v8a/             # 【不入库】libelectron.so / libadapter.so / libffmpeg.so
│   ├── build-profile.json5
│   └── oh-package.json5            # 依赖 web_engine（file:../web_engine）
├── web_engine/                      # ★ HAR 模块：Electron 承载能力 + 系统适配层
│   ├── Index.ets                   # barrel：导出 WebAbility/WebWindow/WebNodeHandleWindow 等
│   ├── childProcess.ets            # 导出 WebChildProcess
│   ├── src/main/ets/
│   │   ├── ability/                # WebAbility / WebBaseAbility / ContinueAbility 等 5 个
│   │   ├── adapter/                # 46 个系统能力适配器（Window/File/Notification/Print/...）
│   │   ├── application/            # WebAbilityStage
│   │   ├── common/                 # DI 容器、常量、命令行、窗口样式等
│   │   ├── components/             # WebWindow / WebNodeHandleWindow / MessageBox 等 7 个
│   │   ├── interface/              # NativeContext / WebProxy 等类型契约
│   │   ├── jsbindings/             # 45 个 JSBind 桥接声明
│   │   ├── process/                # WebChildProcess
│   │   └── utils/                  # 日志、字符串、KVStore、上下文工具
│   ├── src/main/cpp/types/libadapter/   # libadapter.so 的 TS 类型声明
│   ├── src/main/resources/
│   │   ├── base|zh_CN|en_US/element/string.json
│   │   └── resfile/                # 【运行时资源】pak/icudtl/locales/electron + resources/app
│   │       └── resources/app/      # ★ 本工程自有 Electron 应用（main.js / blank.html / package.json）
│   ├── src/main/module.json5       # har 类型 + 权限清单
│   └── oh-package.json5            # 依赖 inversify / reflect-metadata
├── scripts/
│   ├── assemble-resources.sh       # 从 harmonypc-electron 装配内核资源并校验 MD5
│   └── build.sh                    # hvigor 构建 + （可选）本地签名
├── signing/                        # OpenHarmony 本地调试签名材料（非发布用）
│   ├── gen-signing.sh              # 生成 keystore / 证书链 / profile.p7b
│   ├── app-keystore.p12, app-cert-chain.cer, app-leaf.cer
│   ├── root-ca.cer, sub-ca.cer, profile.json, profile.p7b
│   └── verify-profile-result.json, README.txt
├── specs/                          # 规范文档（本目录）
├── logs/                           # 开发/评审/测试日志
├── build-profile.json5             # 产品配置：compatibleSdkVersion 6.0.0(20)、runtimeOS HarmonyOS、signingConfigs
├── hvigorfile.ts / hvigor/          # hvigor 构建配置
├── oh-package.json5                # 工程级依赖（@ohos/hypium）
├── runtime-manifest.json           # 上游装配清单（内核版本 v37.2.3、MD5、bundleName 改写记录）
└── local.properties                # 【不入库】本机 SDK / node / hvigor 路径
```

---

## 2. electron 模块（应用本体）目录明细

```
electron/src/main/ets/
├── Application/AbilityStage.ets        # MyAbilityStage extends WebAbilityStage
├── entryability/
│   ├── EntryAbility.ets                # ★ 主入口：extends WebAbility + 沉浸式全屏
│   ├── BrowserAbility.ets              # 多窗口场景的浏览器 Ability（process: ':browser'）
│   ├── StatelessAbility.ets            # 无状态浏览器 Ability
│   ├── StatusBarEntryAbility.ets       # 状态栏卡片 Extension（statusBarView）
│   └── TaskManagerAbility.ets          # 任务管理场景 Ability
├── extensionAbility/BrowserEmbeddedAbility.ets   # embeddedUI 类型扩展
├── common/
│   ├── ShellConstants.ets              # ★ 存储键 / 状态文件名 / 响应式断点
│   └── ShellUrlHelper.ets              # ★ URL 规整与校验（纯函数）
├── service/
│   ├── ShellUrlStore.ets               # ★ preferences 持久化（last_url）
│   └── ElectronShellBridge.ets         # ★ 与 Electron 的状态文件通道（url + seq）
├── components/ShellOverlay.ets         # ★ 浏览器壳控制层（浮动按钮 + 输入面板 + 响应式）
├── pages/                              # 页面（见第 3 节路由清单）
└── process/CustomChildProcess.ets      # 自定义子进程入口
```

---

## 3. 页面与路由清单

路由注册文件：`electron/src/main/resources/base/profile/main_pages.json`（共 9 条）。页面加载入口为 `WebBaseAbility.getContentPath()`：`IsSupportNodeHandleFeature()` 为真时加载 `pages/NodeHandleWindow`，否则加载 `pages/Index`。

| # | 路由 | 源文件 | 作用 | 入口方式 |
|---|------|--------|------|---------|
| 1 | `pages/Index` | `pages/Index.ets` | XComponent 承载 Electron 内容 + `ShellOverlay` 控制层（回退路径） | `getContentPath()` → `windowStage.loadContent` |
| 2 | `pages/NodeHandleWindow` | `pages/NodeHandleWindow.ets` | ContentSlot 承载 Electron 内容 + `ShellOverlay` 控制层（主路径） | `getContentPath()` → `windowStage.loadContent` |
| 3 | `pages/SubWindow` | `pages/SubWindow.ets` | 子窗口内容（`WebSubWindow`） | `SubWindowAdapter` 创建子窗口时加载 |
| 4 | `pages/NodeHandleSubWindow` | `pages/NodeHandleSubWindow.ets` | NodeHandle 子窗口内容（`WebNodeHandleSubWindow`） | `SubWindowAdapter`（NodeHandle 能力可用时） |
| 5 | `pages/EmbeddedWindow` | `pages/EmbeddedWindow.ets` | 嵌入式窗口内容（`WebEmbeddedWindow`） | `BrowserEmbeddedAbility` |
| 6 | `pages/WindowNode` | `pages/WindowNode.ets` | 窗口节点内容（`WebWindowNode`） | `WindowNode` 场景加载 |
| 7 | `pages/WebPage` | `pages/WebPage.ets` | 通用 Web 承载页（`@Entry` 导出，供扩展使用） | 手动/扩展加载 |
| 8 | `pages/StatusBarPage` | `pages/StatusBarPage.ets` | 状态栏卡片内容 | `StatusBarEntryAbility` |
| 9 | `pages/Login` | `pages/Login.ets` | 登录页面（`ILogin` 回调样式，供需要账号能力的产品复用） | 手动加载 |
| 10 | `pages/QuickLoginButtonComponent` | `pages/QuickLoginButtonComponent.ets` | 快捷登录按钮组件（非路由，被 `Login` 复用） | — |

> 说明：`main_pages.json` 注册 9 条路由（第 10 项为组件而非路由）。本工程实际作为壳使用的只有 `pages/Index` 与 `pages/NodeHandleWindow`；其余页面为上游 `web_engine` 多窗口/状态栏/登录能力的配套页面，保留以保证 `web_engine` 适配器在全部路径下可用。

### Ability / Extension 清单

| 名称 | 类型 | 进程 | 说明 |
|------|------|------|------|
| `EntryAbility` | UIAbility（`mainElement`） | 主进程 | 应用入口，`launchType: specified`，`entity.system.home` + `ohos.want.action.viewData` |
| `BrowserAbility` | UIAbility | `:browser` | 多窗口/独立浏览器进程 |
| `StatelessAbility` | UIAbility | `:browser` | 无状态浏览器实例 |
| `StatusBarEntryAbility` | ExtensionAbility(`statusBarView`) | 主进程 | 状态栏卡片视图 |
| `BrowserEmbeddedAbility` | ExtensionAbility(`embeddedUI`) | 主进程 | 嵌入式 UI 承载 |

---

## 4. web_engine 模块关键目录

| 目录 | 文件数 | 说明 |
|------|-------|------|
| `ets/ability` | 5 | `WebAbility`、`WebBaseAbility`、`WebBaseExtensionAbility`、`WebEmbeddedAbility`、`ContinueAbility` |
| `ets/adapter` | 46 | 系统能力适配器：Window/Dialog/File/Print/Notification/Display/Permission/Clipboard/Media/Bluetooth/DeviceInfo… |
| `ets/jsbindings` | 45 | 与原生 `libadapter.so` 的绑定声明，与 adapter 一一对应 |
| `ets/components` | 7 | `WebWindow`（XComponent）、`WebNodeHandleWindow`（ContentSlot）、`WebSubWindow`、`WebNodeHandleSubWindow`、`WebEmbeddedWindow`、`WebWindowNode`、`MessageBox` |
| `ets/common` | 13 | `InjectModule`（DI）、`Constants`、`CommandLineAdapter`、`AbilityManager`、`WindowStyle`、`NodeHandleManager` 等 |
| `ets/interface` | 3 | `CommonInterface.ts`（`NativeContext` 契约）、`WebProxy.ets`、`Dependency.ets` |
| `ets/utils` | 11 | 日志、字符串栈、`KVStore`、`LaunchHelper`、`JsBindingUtils` 等 |
| `src/main/cpp/types/libadapter` | 2 | `libadapter.so` 的 d.ts 与 oh-package 声明 |
| `resources/resfile/resources/app` | 4 | **本工程自有**：`main.js`、`blank.html`、`package.json`、`electron_white.png` |

---

## 5. 关键配置文件

| 文件 | 作用 |
|------|------|
| `build-profile.json5` | 产品 `compatibleSdkVersion 6.0.0(20)` / `targetSdkVersion 6.1.1(24)` / `runtimeOS HarmonyOS`；`signingConfigs`（DevEco 自动签名）；模块注册 |
| `electron/src/main/module.json5` | entry 模块：deviceTypes、pages、abilities、extensionAbilities |
| `web_engine/src/main/module.json5` | har 模块：deviceTypes、requestPermissions（含 `reason`/`usedScene`）、definePermissions |
| `electron/src/main/resources/base/profile/main_pages.json` | 路由清单（9 条） |
| `electron/src/main/resources/base/profile/shortcuts_config.json` | 桌面快捷方式「OpenNewWindow」 |
| `runtime-manifest.json` | 上游装配清单：`shellVersion`、`binaryVersion v37.2.3-20260825.1`、三个 `.so` 的 MD5、`bundleNameRewrite` 记录、`barrelFile` |
| `local.properties`（不入库） | `sdk.dir` / `nodejs.dir` / `hvigor.dir` |
