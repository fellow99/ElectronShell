# ElectronShell 整体技术方案

> 最后更新：2026-10-20
> 本文是 `overall-spec.md` 的技术对应物：描述**如何**构建整个系统。模块级细节见 `001-electron-shell/plan.md`。

---

## 1. 技术上下文

| 项 | 值 |
|----|----|
| 运行宿主 | HarmonyOS 6.x（真机 API 26，2in1 `HAD-W32`） |
| 应用模型 | Stage Model，单 entry HAP（模块 `electron`）+ 本地 HAR（模块 `web_engine`） |
| 接口语言 | ArkTS（编译 SDK HarmonyOS 6.1.1 / API 24） |
| 内核语言 | JavaScript（Electron 主进程） |
| 浏览器内核 | Electron `v37.2.3-20260825.1` |
| 构建 | hvigor 6.1 + ohpm；签名由 DevEco 自动签名提供 |
| 设备形态 | `default`（手机）/ `tablet` / `2in1` / `tv` |
| 目标 API | `compatibleSdkVersion 6.0.0(20)`，`targetSdkVersion 6.1.1(24)` |

---

## 2. 宪法符合性

| 宪法条款 | 符合性 | 落地方式 |
|---------|-------|---------|
| 一.1 Stage Model 唯一 | ✅ | `EntryAbility extends WebAbility`（→ `WebBaseAbility` → `UIAbility`） |
| 一.2 多形态优先 | ✅ | 两个模块 `deviceTypes` 均覆盖四形态 |
| 一.3 能力缺失不得致命 | ✅ | `applyImmersiveFullScreen` 四段独立 `try/catch` |
| 二.1 禁止动态类型 | ✅ | 新增代码无 `any`，全部显式类型 |
| 二.3 异常统一转换 | ✅ | `catch (error)` → `error as BusinessError` → `hilog` |
| 三.1 状态不可直改 | ✅ | `@State` 整体赋值 |
| 三.3 组件化 | ✅ | `ShellOverlay` 被两个页面复用 |
| 四.1 三层结构 | ✅ | `common` / `service` / `components`+`pages` |
| 四.2 纯逻辑可测 | ✅ | `ShellUrlHelper` 无 IO |
| 五.2 通信走自有通道 | ✅ | 状态文件（见 §4.1） |
| 六.3 内核最小权限 | ✅ | `nodeIntegration:false`、`contextIsolation:true` |
| 七.1 关键路径留痕 | ✅ | 状态文件路径 / seq / load 结果均打印 |
| 八.1 大体积二进制不入库 | ✅ | `.gitignore` + `assemble-resources.sh` |
| 九.1/9.2 规格与用例先行 | ✅ | `specs/001-electron-shell/{spec,plan,tasks,test-cases}.md` |

---

## 3. 实现策略总览

采用「**资源装配 → 宿主壳实现 → 内核应用实现 → 闭环验证**」四段式：

1. **资源装配**：`scripts/assemble-resources.sh` 从 `harmonypc-electron/ohos_hap` 拉取 Electron 三件套与 `resfile`，按 `runtime-manifest.json` 校验 MD5；`web_engine/resources/app` 使用本工程自有实现，不被覆盖。
2. **宿主壳实现（ArkTS）**：在 `electron` 模块内新增 `common` / `service` / `components` 三层，把 URL 策略、持久化、内核通道与界面解耦；`EntryAbility` 在框架之上只增加「沉浸式全屏」。
3. **内核应用实现（JS）**：替换 `resources/app`，由 `main.js` 负责窗口、导航与协议策略，`blank.html` 作为无 URL 时的占位页。
4. **闭环验证**：`scripts/build.sh`（hvigor + 可选本地签名）→ `hdc app install` → `uitest` 驱动 → `hilog` 取证。

---

## 4. 横切关注点

### 4.1 进程间协作（ArkTS ↔ Electron）

```
ArkTS                                  Electron main
─────                                  ─────────────
ShellUrlStore.saveLastUrl(url)   ┐
ElectronShellBridge.publish(url) ┴→ electron-shell-state.json {url, seq}
                                       ↓（300ms 轮询 + seq 去重）
                                     loadURL(url) / loadFile(blank.html)
                                       ↓
                                     did-finish-load / did-fail-load → 日志
```

- 文件位置：`<ApplicationContext.filesDir>/electron-shell-state.json`，与 Electron 的 `--user-data-dir`（`/data/storage/el2/base/files/`）天然同目录；
- 也支持 `--shell-state-file=<绝对路径>` 显式覆盖；
- 容错：读失败/JSON 损坏视为「无状态」，下一次轮询自动恢复。

### 4.2 错误处理策略

| 层次 | 策略 |
|------|------|
| 窗口能力 | `try/catch` + `hilog.warn`，功能降级但不阻断启动 |
| 持久化 | `try/catch` + `hilog.error`，仅影响「记住地址」能力 |
| 通道写入 | `try/catch` + 返回 `false` + `hilog.error` |
| 内核导航 | `loadURL().catch` → 回退空页面；`did-fail-load` 记录 code/desc/url |
| 输入校验 | 就地提示，不发起导航，不写状态文件 |

### 4.3 安全

| 面 | 措施 |
|----|------|
| 网页执行环境 | `nodeIntegration: false`、`contextIsolation: true` |
| 协议白名单 | 输入框仅 `http/https`；页面跳转非 `http/https/file/about` 交系统 |
| 新窗口 | 一律在当前窗口打开，避免不可控窗口爆发 |
| 权限 | 沿用上游清单，新增项必须带 `reason`/`usedScene` |
| 凭据 | 仓库仅含设备绑定调试签名材料，使用限制写在 `signing/README.txt` |

### 4.4 日志与可观测性

- 标签：`ElectronShellBridge`、`ShellOverlay`、`ShellUrlStore`、`EntryAbility`（hilog domain `0x0000`）；内核侧前缀 `[ElectronShell]`；
- 关键日志：状态文件绝对路径、`published seq=N url=…`、`load url (seq=N)`、`did-finish-load`、`did-fail-load`。

---

## 5. 测试策略

| 层级 | 手段 | 覆盖 |
|------|------|------|
| 纯函数 | 人工推演 + 真机非法输入验证 | `ShellUrlHelper` |
| 服务层 | 设备文件核对（`preferences` / 状态文件 JSON） | `ShellUrlStore`、`ElectronShellBridge` |
| UI | `uitest dumpLayout` 定位 + `uitest uiInput` 注入 + `snapshot_display` 取证 | `ShellOverlay` |
| 端到端 | `hdc app install` + `aa start` + 真实站点（百度 / Three.js） | 全链路 |
| 日志级 | `hilog -x` 过滤关键字 | 可观测性断言 |

用例见 `specs/001-electron-shell/test-cases.md`，执行记录见 `logs/20261020-1/TEST_REPORT.md`。

---

## 6. 部署策略

### 6.1 构建

```bash
bash scripts/assemble-resources.sh      # 首次克隆后执行一次
bash scripts/build.sh                   # 产出已签名 HAP
```

### 6.2 签名

| 场景 | 方式 | 说明 |
|------|------|------|
| HarmonyOS 真机（本工程实测） | DevEco 自动签名（AGC debug profile） | `build-profile.json5` 的 `signingConfigs` 由 IDE 写入，`hvigor` 直接产出 `-signed.hap` |
| OpenHarmony 设备 / 无账号环境 | `signing/gen-signing.sh` + `hap-sign-tool.jar` | 自签名体系；**不可**用于 HarmonyOS 真机（设备校验 `fail to verify pkcs7 file`） |

### 6.3 发布

本工程为调试/验证用途，不做应用商店发布。若要发布需：

1. 在 AGC 创建正式应用与发布证书；
2. 用 release profile 重新签名；
3. 补齐隐私声明、权限用途说明与软件著作权信息。

---

## 7. 演进方向（不在本期范围）

| 方向 | 价值 | 代价 |
|------|------|------|
| 状态文件轮询改 `fs.watch` | 消除 ≤300ms 导航延迟 | 需验证 OHOS 上 inotify 可用性 |
| 增加刷新/后退/前进 | 更接近浏览器体验 | 需与内核命令通道打通 |
| 平板非 PC 模式顶部留白修复 | 形态覆盖更完整 | 需覆盖 `statusBarHeight` 的 LocalStorage 写入 |
| 单元测试（hypium）覆盖 `ShellUrlHelper` | 回归保障 | 需搭建可以在 CI 跑的测试工程 |
| 通过 `nativeContext.ExecuteCommand` 直连内核 | 去掉文件通道 | 需上游导出符号或推动上游开放 API |
