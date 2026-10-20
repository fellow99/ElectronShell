# ElectronShell 技术选型

> 最后更新：2026-10-20
> 版本与依赖均取自工程内实际文件（`build-profile.json5`、`oh-package.json5`、`runtime-manifest.json`、模块 `build-profile.json5`）。

---

## 1. 技术栈总览

| 类别 | 技术 | 版本 | 用途 | 出处 |
|------|------|------|------|------|
| 操作系统 | HarmonyOS | 6.x（真机 API 26） | 运行宿主 | 真机 `param get const.ohos.apiversion` |
| 应用模型 | Stage Model（UIAbility + ExtensionAbility） | — | 应用生命周期与窗口 | `electron/src/main/module.json5` |
| 开发语言（宿主） | ArkTS | 编译 SDK 6.1.1（API 24） | 界面、持久化、窗口控制 | `build-profile.json5` |
| 开发语言（内核侧） | JavaScript（Node/Electron 主进程） | Electron 内置 Node | 窗口创建、导航、事件处理 | `resfile/resources/app/main.js` |
| UI 框架 | ArkUI（声明式，`@Component` / `@Builder` / `@State`） | — | 浮动按钮、输入面板、响应式布局 | `components/ShellOverlay.ets` |
| 浏览器内核 | Electron for HarmonyOS | `v37.2.3-20260825.1`（shell `rc.7-fellow99.baseline.1`） | 网页渲染、网络、多进程 | `runtime-manifest.json` |
| 内核适配层 | `web_engine` HAR（含 `libadapter.so`） | 1.0.0 | 鸿蒙窗口/系统能力 ↔ Electron | `web_engine/oh-package.json5` |
| 构建工具 | hvigor | 6.1（`command-line-tools`） | 编译、打包、签名 | `hvigor/hvigor-config.json5` |
| 包管理 | ohpm | 6.1.2.285 | 依赖安装 | `oh-package.json5` |
| 本地存储 | `@ohos.data.preferences`（轻量键值） | SDK 内置 | 保存最后一次 URL | `service/ShellUrlStore.ets` |
| 文件 IO | `@kit.CoreFileKit` `fileIo` | SDK 内置 | 写状态文件（与内核通信） | `service/ElectronShellBridge.ets` |
| 日志 | `@kit.PerformanceAnalysisKit` `hilog` + Chromium 控制台 | SDK 内置 | 关键路径排障 | 全工程 |
| 测试框架 | `@ohos/hypium` | 1.0.6 | 单测/UI 测试脚手架 | `oh-package.json5` |
| 签名 | DevEco 自动签名（华为 AGC debug profile）+ SDK `hap-sign-tool.jar` | — | 真机安装 | `build-profile.json5`、`scripts/build.sh` |
| DI 容器 | `inversify` + `reflect-metadata` | ^6.0.1 / ^0.1.13 | `web_engine` 内部适配器注入 | `web_engine/oh-package.json5` |

---

## 2. 关键技术决策

### 2.1 为什么使用 HarmonyOS SDK 而不是 OpenHarmony SDK

`web_engine` 依赖 HarmonyOS 专属 Kit：

| Kit | 用途 | OpenHarmony SDK 是否提供 |
|-----|------|------------------------|
| `@kit.ShareKit` | 系统分享 | ❌ |
| `@kit.CoreSpeechKit` | 语音 | ❌ |
| `@kit.CoreVisionKit` | 图像/视觉（形状检测） | ❌ |
| `@kit.StatusBarExtensionKit` | 状态栏卡片 | ❌ |

用 OpenHarmony SDK 编译会得到 `10311003 ArkTS:ERROR ... has no corresponding config file in ArkTS SDK`。因此产品 `runtimeOS` 定为 `HarmonyOS`，`sdk.dir` 指向 DevEco Studio 自带 SDK。

### 2.2 为什么 `compatibleSdkVersion` 是 6.0.0(20)

- 上游 v37 模板使用 `compatibleSdkVersion: "6.0.0(20)"`，与 `web_engine` 中 `deviceInfo.sdkApiVersion >= 20/22` 的能力分支相匹配；
- `targetSdkVersion` 取本地 SDK 最高版本 `6.1.1(24)`，真机 API 26 向下兼容。

### 2.3 为什么设备类型是 `default/tablet/2in1/tv` 而不是 `phone/...`

hvigor 校验提示 `Currently, the device type 'phone' is not supported in module.json5`；`default` 即手机形态的通用取值。四类形态的覆盖关系：

| 需求形态 | module.json5 取值 |
|---------|-------------------|
| phone | `default` |
| tablet | `tablet` |
| 2in1 | `2in1` |
| tv | `tv` |

### 2.4 为什么不用 ArkUI `Web` 组件

需求要求的是 **Electron** 浏览器组件（项目定位是 Electron on HarmonyOS 测试壳），ArkUI `Web` 基于系统 ArkWeb 内核，无法满足「验证 Electron 渲染 + 网络 + 多进程」的目标。工程内另有一个基于 `Web` 组件的独立工程（`BrowserShell`），不属本需求范围。

### 2.5 未装配 `libc++_shared.so` 的原因

`runtime-manifest.json` 的 `libcxx` 字段声明该库来源为 DevEco SDK，但实测三个内核二进制的 `DT_NEEDED` 中均无 `libc++_shared.so`（`llvm-readelf -d` 校验），即无需随包分发；强行内置反而可能与系统同名库产生版本冲突。该差异已在 `scripts/assemble-resources.sh` 输出中显式说明。

---

## 3. 依赖清单

### 3.1 工程级（`oh-package.json5`）

| 依赖 | 版本 | 类型 |
|------|------|------|
| `@ohos/hypium` | 1.0.6 | devDependencies |

### 3.2 electron 模块（`electron/oh-package.json5`）

| 依赖 | 版本 | 类型 |
|------|------|------|
| `web_engine` | `file:../web_engine` | dependencies |

### 3.3 web_engine 模块（`web_engine/oh-package.json5`）

| 依赖 | 版本 | 类型 |
|------|------|------|
| `inversify` | ^6.0.1 | dependencies |
| `reflect-metadata` | ^0.1.13 | dependencies |
| `libadapter.so`（types） | `file:./src/main/cpp/types/libadapter` | devDependencies |

### 3.4 内核运行时资源（`runtime-manifest.json`）

| 资源 | 版本 / MD5 | 是否入库 |
|------|-----------|---------|
| `libelectron.so` | `D97D27B98220C28858EE9486E5048510` | 否（装配） |
| `libadapter.so` | `A8FD1ABFBAC39A31DB1F8D16745576E3` | 否（装配） |
| `libffmpeg.so` | `E7D2B9808F62EA8421A86789DD818A49` | 否（装配） |
| `resfile/*`（pak/icudtl/locales/electron 等，约 18MB） | 与 v37 发行包一致 | 否（装配） |
| `resfile/resources/app`（本工程 Electron 应用） | 工程自有 | 是 |

---

## 4. 开发与构建环境要求

| 项 | 要求 | 本机实测 |
|----|------|---------|
| DevEco Studio | 6.0+（提供 HarmonyOS SDK 与 jbr） | `D:\oh-workspace\DevEco Studio` |
| HarmonyOS SDK | API 20 及以上 | 6.1.1（API 24） |
| Node.js | 18.x | v18.20.1 |
| hvigor / ohpm | 6.1+ | `D:\oh-workspace\command-line-tools` |
| hdc | 随 SDK | `.../OpenHarmony/Sdk/23/toolchains/hdc.exe` |
| 设备 | HarmonyOS 真机或模拟器，开启开发者模式 | `HAD-W32`（2in1，API 26） |

> 注意：`NODE_OPTIONS` 若包含 `--openssl-legacy-provider` 会导致 hvigor 报 `ERR_WORKER_INVALID_EXEC_ARGV`，构建脚本已 `unset NODE_OPTIONS`。
