# ElectronShell 宪法原则

> 本文件从**现有代码事实**中提取工程已遵循的原则，用于约束后续迭代。
> 每一条都对应可核对的代码位置；若某条与代码不一致，应视为待修复缺陷。

---

## 第一条：平台与形态

1. **Stage Model 唯一**：所有 Ability 均继承 `UIAbility` 系（`EntryAbility extends WebAbility`，而 `WebAbility extends WebBaseAbility extends UIAbility`）。
   - 位置：`electron/src/main/ets/entryability/*.ets`、`web_engine/src/main/ets/ability/WebBaseAbility.ets`
2. **多形态优先**：模块 `deviceTypes` 覆盖 `default`(手机) / `tablet` / `2in1` / `tv`，任何新增能力必须同时对这四类形态做能力可用性判断。
   - 位置：`electron/src/main/module.json5`、`web_engine/src/main/module.json5`
3. **能力缺失不得致命**：设备形态差异导致的窗口/系统栏能力缺失，必须 `try/catch` + 记录日志后继续。
   - 位置：`electron/src/main/ets/entryability/EntryAbility.ets`（`applyImmersiveFullScreen`）

## 第二条：ArkTS 语言约束

1. **禁止动态类型**：不使用 `any`、`object` 泛用、动态属性访问；结构化数据用 `interface` 声明，动态键用 `Record`。
   - 反例防护位置：`electron/src/main/ets/service/*.ets`、`common/*.ets`
2. **显式类型标注**：类字段、方法返回值、回调参数均标注类型。
3. **异常统一转换**：`catch (error)` 后以 `const err = error as BusinessError` 取 `code`/`message`，并输出 `hilog`。
   - 位置：`ShellUrlStore`、`ElectronShellBridge`、`ShellOverlay`

## 第三条：状态与渲染

1. **状态集中且不可直改**：组件状态一律 `@State`，通过整体赋值触发刷新，禁止就地修改嵌套字段。
2. **跨组件共享通过 LocalStorage**：`xcomponentId`、`startUri`、`window`、`cmdArgs` 等由 `WebAbility` 写入 `LocalStorage`，页面用 `@LocalStorageLink` 消费。
   - 位置：`web_engine/src/main/ets/ability/WebAbility.ets`（`loadContent` 前的 `para`）、`electron/src/main/ets/pages/*.ets`
3. **组件化**：可复用的界面单元必须抽成 `@Component`；同一 UI 逻辑不得在多个页面复制粘贴。
   - 位置：`ShellOverlay` 被 `pages/Index.ets` 与 `pages/NodeHandleWindow.ets` 共用

## 第四条：分层与职责

1. **三层结构**：`common`（常量与纯函数）、`service`（存储、通道等副作用）、`components`/`pages`（视图）。视图层不直接操作文件与偏好存储。
   - 位置：`electron/src/main/ets/{common,service,components,pages}`
2. **纯逻辑可测**：URL 规整/校验等纯逻辑必须与 UI、IO 解耦，便于单测。
   - 位置：`common/ShellUrlHelper.ets`
3. **单例访问外部资源**：`ShellUrlStore`、`ElectronShellBridge` 采用 `getInstance()` 单例并实现幂等 `init()`，避免重复打开句柄。

## 第五条：内核边界

1. **不改上游语义**：`web_engine`（HAR）作为上游能力提供方，本工程只做「装配 + 必要的最小配置修正」（bundleName、deviceTypes、权限 `reason`），不修改其运行语义。
2. **通信走应用自有通道**：ArkTS 与 Electron 主进程之间通过应用沙箱内的状态文件通信，不依赖上游未导出符号。
   - 位置：`service/ElectronShellBridge.ets`、`web_engine/.../app/main.js`
3. **时序安全**：必须先写完状态再启动内核；内核首帧强制应用一次状态。

## 第六条：安全与凭据

1. **最小必要权限**：权限清单在上游基础上按需裁剪，保留项必须说明用途；新增权限必须有 `reason` 与 `usedScene`；裁剪与保留的判定记录在 `specs/001-electron-shell/plan.md` §8.1。
2. **调试签名与正式签名分离**：仓库内只允许存在**调试**签名材料（设备绑定、自签名），且必须在 `signing/README.txt` 说明其用途与限制；正式发布必须使用 DevEco 自动签名（华为 AGC profile），不得把密文口令写入文档。
3. **内核侧最小权限**：`BrowserWindow` 使用 `nodeIntegration: false`、`contextIsolation: true`，网页脚本不得直接访问 Node 能力。
   - 位置：`web_engine/.../app/main.js`

## 第七条：可观测性

1. **关键路径必留痕**：状态文件路径、发布序号与 URL、导航成功/失败均必须有日志（`hilog` 或 Chromium 控制台）。
2. **日志分级**：可恢复异常用 `warn`，不可恢复用 `error`，正常流程关键节点用 `info`。

## 第八条：资源与工程卫生

1. **大体积二进制不入库**：Electron `.so` 与 `resfile` 运行时资源通过 `scripts/assemble-resources.sh` 从源工程装配，并按 `runtime-manifest.json` 校验 MD5。
2. **来源可追溯**：内核版本、来源工程、装配清单记录在 `runtime-manifest.json` 与 `specs/TECH.md`。
3. **脚本幂等**：构建、装配、签名脚本可重复执行且结果一致（覆盖写入、不依赖手工中间状态）。

## 第九条：文档即契约

1. **规格先于实现**：新增功能先在 `specs/<编号>-<名称>/spec.md` 定义 FR 编号，再落实现。
2. **测试用例可执行**：界面功能模块必须提供 `test-cases.md`，用例需包含前置、步骤、预期、对应 FR，并可通过 `hdc`/`uitest` 复现。
3. **文档与代码同步**：`specs/STRUCTURE.md` 的页面/路由清单、`TECH.md` 的依赖版本必须随代码变更同步更新。

---

## 附：违反即阻断（Gate）

以下情形不允许合入：

- 出现 `any`、动态属性访问、就地修改 `@State` 嵌套字段；
- 视图中直接调用 `fileIo` / `preferences`（应经 `service` 层）；
- 新增未声明 `reason` 的用户授权权限；
- 提交包含 Electron `.so`、HAP、`build/` 产物；
- 未更新 `specs/` 与 `test-cases.md` 的功能变更。
