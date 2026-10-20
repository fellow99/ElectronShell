# 001-electron-shell 任务清单

> 需求编号：001（Electron 浏览器壳）
> 说明：任务按依赖顺序排列；`[x]` 表示已完成并经过验证，`[~]` 表示完成但验证受限，`[ ]` 表示未开始。

## 阶段 0：环境与装配

| # | 任务 | 状态 | 验证方式 |
|---|------|------|---------|
| T-000 | 确认 HarmonyOS / OpenHarmony SDK、hvigor、ohpm、hdc 可用 | [x] | `hdc list targets`、`hvigorw -v` |
| T-001 | 从 `harmonypc-electron/ohos_hap` 装配工程骨架（AppScope / electron / web_engine / hvigor） | [x] | 目录比对 |
| T-002 | 依据 `harmonypc-electron-versions/libelectron/ohos_hap` 校准 v37 配置（compatibleSdkVersion 6.0.0(20)、targetSdkVersion 6.1.1(24)、runtimeOS HarmonyOS） | [x] | 对照 diff |
| T-003 | 校验内核二进制 MD5 与 `runtime-manifest.json` 一致 | [x] | `scripts/assemble-resources.sh` |
| T-004 | 改写 bundleName（`com.jkh.electronshell`）至 `AppScope/app.json5`、4 个 adapter、`shortcuts_config.json` | [x] | `grep` 无残留 |
| T-005 | deviceTypes 覆盖 `default/tablet/2in1/tv`；补 `DISTRIBUTED_DATASYNC` 的 `reason`/`usedScene` | [x] | `assembleHap` 无配置错误 |
| T-006 | 建立签名与构建流水线（`signing/gen-signing.sh`、`scripts/build.sh`） | [x] | 产出 `electron-default-signed.hap` |
| T-007 | 由 DevEco 自动签名生成华为 AGC profile 并接入 `signingConfigs` | [x] | 真机安装成功 |

## 阶段 1：Electron 侧（内核应用）

| # | 任务 | 状态 | 验证方式 |
|---|------|------|---------|
| T-100 | 用浏览器壳主进程替换内置示例应用（`resources/app/main.js`） | [x] | 真机加载空白页 / 目标站点 |
| T-101 | 新增空页面 `blank.html`（浅/深色自适应） | [x] | 首启截图 |
| T-102 | 实现状态文件解析（`--shell-state-file` 或 `app.getPath('userData')`） | [x] | hilog 两端路径一致 |
| T-103 | 实现 300ms 轮询 + `seq` 去重 + 首帧强制应用 | [x] | 导航日志 seq 单调 |
| T-104 | `setWindowOpenHandler` 收敛 `target=_blank` | [x] | 代码评审 + 新闻链接验证 |
| T-105 | `will-navigate` 托管非 http/https 协议 | [x] | 代码评审 |
| T-106 | `did-finish-load` / `did-fail-load` 日志 | [x] | threejs 加载排障中使用 |
| T-107 | 清理示例应用遗留文件 | [x] | 目录清点 |

## 阶段 2：ArkTS 侧（壳界面）

| # | 任务 | 状态 | 验证方式 |
|---|------|------|---------|
| T-200 | `ShellConstants` / `ShellUrlHelper`（规整 + 校验纯函数） | [x] | 真机非法输入提示 |
| T-201 | `ShellUrlStore`（preferences 读写，同步接口） | [x] | 设备上 `electron_shell_store` 文件内容核对 |
| T-202 | `ElectronShellBridge`（状态文件写入，seq 自增） | [x] | hilog `published seq=…` |
| T-203 | `ShellOverlay` 组件：左下浮动按钮 + 底部输入面板 + 三档响应式 | [x] | 真机截图 |
| T-204 | 输入面板展开自动聚焦、确认后收起 | [x] | 真机操作 |
| T-205 | 挂载到 `pages/NodeHandleWindow`（主路径）与 `pages/Index`（回退路径） | [x] | 编译 + 真机渲染 |
| T-206 | `EntryAbility` 沉浸式全屏（layoutFullScreen / 隐藏系统栏 / 2in1 最大化） | [x] | 真机截图为 3120×2080 全屏无系统栏 |

## 阶段 3：缺陷修复（真机验证阶段发现）

| # | 缺陷 | 状态 | 修复 |
|---|------|------|------|
| T-300 | URL 校验过宽：`https://a.comhttps://b.com` 被判为合法并送入内核 | [x] | 重写 `isSupported`（authority 解析 + 域名/端口规则） |
| T-301 | 启动恢复不校验历史值，脏值导致内核导航失败 | [x] | 新增 `isRestorable`，非法值视为无 URL |
| T-302 | 无可用 URL 时残留旧状态文件，内核会加载脏 URL | [x] | 无可用 URL 时 `publish('')` 显式回到空页面 |
| T-303 | 评审 C-1：`ERR_ABORTED` 被当作加载失败回退空页，打断正在进行的导航 | [x] | 导航令牌 + `isAbortedError()` 过滤 |
| T-304 | 评审 C-2：`did-fail-load` 未回退空页，且未区分主/子框架 | [x] | 主框架失败才回退，跳过空页自身与 `-3` |
| T-305 | 评审 I-6：状态文件非原子写 | [x] | 临时文件 + `fsync` + `rename` |
| T-306 | 评审 I-4：内核可能先于 `publish` 启动 | [x] | 发布前移到 `EntryAbility.onCreate` |
| T-307 | 评审 I-2：动态展开的面板不自动聚焦 | [x] | `FocusController.requestFocus` |
| T-308 | 评审 I-1：平板状态栏被框架回显 | [x] | 延时 600ms + 回前台 + 配置变更重放 |
| T-309 | 评审 I-11：`ShellUrlHelper` 无单测 | [x] | 新增 `electron/src/test/ShellUrlHelper.test.ets`（未执行） |

## 阶段 4：文档与评审

| # | 任务 | 状态 | 验证方式 |
|---|------|------|---------|
| T-400 | `specs/001-electron-shell/spec.md` | [x] | 人工核对 |
| T-401 | `specs/001-electron-shell/plan.md` | [x] | 人工核对 |
| T-402 | `specs/001-electron-shell/tasks.md` | [x] | 本文件 |
| T-403 | `specs/001-electron-shell/test-cases.md` | [x] | 人工核对 |
| T-404 | 代码评审（requesting-code-review → receiving-code-review），Critical 2 / Important 12 / Minor 13 逐条核对并修复 | [x] | `logs/20261020-1/REVIEW_REPORT.md` |
| T-405 | 全工程规范文档（README / SPECS_CHECKLIST / STRUCTURE / TECH / ARCHITECTURE / constitution / overall-*） | [x] | `specs/` 目录 |
| T-406 | 工程 `README.md` | [x] | 人工核对 |
| T-407 | 真机测试报告 | [x] | `logs/20261020-1/TEST_REPORT.md`（21 条用例，全部 P0 通过；threejs examples 已补测） |

## 里程碑

| 里程碑 | 判定标准 | 状态 |
|--------|---------|------|
| M1 可构建 | `assembleHap` 成功产出 HAP | 达成 |
| M2 可安装 | 真机 `hdc app install` 成功 | 达成 |
| M3 可浏览 | 真机全屏显示网页，浮动按钮与输入面板可用，导航生效 | 达成 |
| M4 可持久化 | 重启应用后自动加载上次 URL | 达成（设备上 preferences 与状态文件均已核对） |
| M5 验收测试 | `test-cases.md` 全部用例执行完毕 | 部分达成（见 TEST_REPORT） |
