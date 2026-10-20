# 开发日志 2026-10-20 / 01

> 需求：001-electron-shell（Electron 浏览器壳）
> 工程：`d:\oh-workspace\DevEcoStudioProjects\ElectronShell`
> 分支：`specs/001-electron-shell`

## 环境

| 项 | 值 |
|----|----|
| 系统 | Windows 10（Git Bash） |
| Node / ohpm | Node v18.20.1，ohpm 6.1.2.285 |
| 构建 | hvigor（`D:\oh-workspace\command-line-tools\bin\hvigorw.bat`） |
| 编译 SDK | `D:\oh-workspace\DevEco Studio\sdk`（HarmonyOS 6.1.1 / API 24） |
| 设备 | `3QC0226526001227` → `HAD-W32`，2in1，API 26 |
| 内核 | Electron `v37.2.3-20260825.1` |

## DEV_CHECKLIST

| # | 事项 | 结论 | 证据 |
|---|------|------|------|
| 1 | 装配工程骨架（AppScope/electron/web_engine/hvigor） | ✅ | 目录结构与 `harmonypc-electron/ohos_hap` 一致（新增 common/service/components） |
| 2 | 依据 v37 patch 校准 SDK 与 runtimeOS | ✅ | OpenHarmony SDK 缺少 `@kit.ShareKit`/`@kit.CoreSpeechKit`/`@kit.CoreVisionKit`/`@kit.StatusBarExtensionKit`，切换为 HarmonyOS SDK 后编译通过 |
| 3 | bundleName 改写 | ✅ | `grep -rn "com.huawei.ohos_electron"` 仅 `runtime-manifest.json`（作为上游来源记录保留） |
| 4 | deviceTypes 覆盖 phone/tablet/2in1/tv | ✅ | `phone` 不被 OpenHarmony 校验接受，改用 `default`（等效手机）+ tablet + 2in1 + tv |
| 5 | `DISTRIBUTED_DATASYNC` 补 `reason`/`usedScene` | ✅ | 编译错误 `00303222` 消除 |
| 6 | 本地调试签名材料生成 | ✅ | `signing/verifiy-profile-result.json` → `verifiedPassed: true` |
| 7 | 真机安装 | ✅（改用 DevEco 自动签名后） | 本地 OpenHarmony 自签名被设备拒绝：`fail to verify pkcs7 file`；内核日志 `it do not come from trusted root`；改用华为 AGC debug profile 后 `install bundle successfully` |
| 8 | 沉浸式全屏 | ✅ | 截图 3120×2080，无系统状态栏/标题栏 |
| 9 | 浮动按钮 + 输入面板 | ✅ | `uitest dumpLayout` 找到 `Text[URL]`、`Button[前往]`；截图可见 |
| 10 | URL 持久化 | ✅ | 设备 preferences 文件含 `last_url`；状态文件 `{url,seq}` 同步 |
| 11 | 百度首页 + 新闻链接 | ✅ | 截图两张 |
| 12 | threejs.org 首页 | ✅ | 截图；站点首字节约 10~20s |
| 13 | threejs examples → 具体示例 | ⛔ 阻塞 | 执行时设备被用户其它应用抢占前台，`uitest` 找不到目标节点 |

## 编译警告（存量，非本次引入）

- `web_engine/src/main/ets/interface/CommonInterface.ts`：`Cannot find name 'GestureEvent'`（上游类型声明缺失，仅在 `import type` 场景出现，不影响产物）
- 多个 `getShared` 已废弃提示（`pages/*`，上游脚手架写法）
- `QuickLoginButtonComponent.ets` / `Login.ets` 的 `tag`/`text` API 兼容性提示（上游遗留页面）

## 结论

浏览器壳主链路（全屏 → 承载 Electron → 输入 URL → 导航 → 持久化）已在真机跑通；唯一未完成的验收项是 threejs 示例页点击，原因为设备被其它应用占用。
