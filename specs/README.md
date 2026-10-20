# 规格文档索引

**项目名称：** ElectronShell（HarmonyOS / OpenHarmony 上的 Electron 浏览器测试壳）
**版本：** 1.0.0（`AppScope/app.json5` → `versionName`）
**技术栈：** ArkTS / ArkUI（HarmonyOS 6.1.1 SDK）+ Electron v37.2.3 + web_engine HAR
**文档生成时间：** 2026-10-20
**最后更新：** 2026-10-20

---

## 一、文档总览

| 层级 | 分类 | 文档数量 | 说明 |
|------|------|---------|------|
| 整体 | 项目级顶层文档 | 9 | 架构、技术、结构、宪法、检查清单、本索引等全局文档 |
| 整体 | 整体规格文档 | 3 | `overall-*` 系列 |
| 模块 | 浏览器壳 | 4 | `001-electron-shell/` |
| 过程 | 开发/评审/测试日志 | 3 | `../logs/20261020-1/`（不在 specs 内，单独统计） |
| **合计** | **13 个文档（specs 内）+ 3 个过程记录** | | `specs/` 下 1 个模块目录 |

> 按需求约定，本工程不产出 `API.md`、`overall-api.md`、`overall-data-model.md`。

---

## 二、项目级顶层文档

全局性的架构、技术、宪法等文档，定义项目基线和开发准则。

| 文档 | 路径 | 说明 |
|------|------|------|
| **整体架构** | [ARCHITECTURE.md](./ARCHITECTURE.md) | 分层视图、运行时拓扑、数据流、架构决策、已知限制 |
| **技术选型** | [TECH.md](./TECH.md) | 技术栈与版本、依赖清单、5 个关键选型理由、环境要求 |
| **宪法原则** | [constitution.md](./constitution.md) | 九条工程原则 + 违反即阻断清单 |
| **工程结构** | [STRUCTURE.md](./STRUCTURE.md) | 目录树、页面/路由清单（9 条）、Ability 清单、关键配置 |
| **检查清单** | [SPECS_CHECKLIST.md](./SPECS_CHECKLIST.md) | 规格文档完成度追踪与待办 |

### 整体规格文档

| 文档 | 路径 | 说明 |
|------|------|------|
| **整体规格** | [overall-spec.md](./overall-spec.md) | 系统定位、用户故事、功能域、非功能要求、系统边界 |
| **整体方案** | [overall-plan.md](./overall-plan.md) | 技术上下文、宪法符合性、横切关注点、测试与部署策略 |
| **测试用例索引** | [overall-test-cases.md](./overall-test-cases.md) | 用例目录、功能域分布、需求覆盖矩阵、命令基线 |

---

## 三、浏览器壳模块（001）

### 001 — Electron 浏览器壳 (Electron Shell)

> 全屏承载 Electron 浏览区域，提供左下角悬浮地址入口与访问记忆的极简浏览器壳。

| 文档 | 链接 | 说明 |
|------|------|------|
| 功能规格 | [001-electron-shell/spec.md](./001-electron-shell/spec.md) | 5 个用户故事、24 条功能需求（FR-001-xxx）、7 个验收场景、依赖与约束 |
| 技术方案 | [001-electron-shell/plan.md](./001-electron-shell/plan.md) | 5 个关键决策（承载组件/通信通道/内置应用/沉浸式/URL 校验）、数据模型、接口契约、文件清单 |
| 任务清单 | [001-electron-shell/tasks.md](./001-electron-shell/tasks.md) | 4 个阶段 34 个任务、3 个真机阶段缺陷、5 个里程碑 |
| 测试用例 | [001-electron-shell/test-cases.md](./001-electron-shell/test-cases.md) | 25 条用例（P0×11、P1×10、P2×4），含执行状态与证据 |

---

## 四、过程记录（工程 logs 目录）

| 文档 | 路径 | 说明 |
|------|------|------|
| 开发日志与自查清单 | [../logs/20261020-1/DEV_CHECKLIST.md](../logs/20261020-1/DEV_CHECKLIST.md) | 环境、13 项实现自查、编译警告归因 |
| 代码评审报告 | [../logs/20261020-1/REVIEW_REPORT.md](../logs/20261020-1/REVIEW_REPORT.md) | `requesting-code-review` 派发的评审结论 + `receiving-code-review` 的逐条核对与处置 |
| 测试清单与报告 | [../logs/20261020-1/TEST_REPORT.md](../logs/20261020-1/TEST_REPORT.md) | 25 条用例执行、补测记录、缺陷清单、评审后回归验证 |

---

## 五、模块编号一览

| 编号 | 模块名 | 英文名 | 分类 |
|------|--------|--------|------|
| 001 | Electron 浏览器壳 | electron-shell | 应用功能 |

---

## 六、模块文档结构规范

每个模块目录 `NNN-name/` 下包含：

| 文件 | 命名 | 说明 |
|------|------|------|
| 功能规格 | `spec.md` | 功能需求、用户故事、验收标准（技术无关） |
| 技术方案 | `plan.md` | 技术实现方案、架构决策、接口契约（实现相关） |
| 任务清单 | `tasks.md` | 开发任务拆解、依赖、里程碑 |
| 测试用例 | `test-cases.md` | 界面功能测试用例（前置/步骤/预期/对应 FR） |

---

## 七、快速导航

| 目标读者 | 推荐阅读顺序 |
|---------|-------------|
| **新加入开发者** | [constitution.md](./constitution.md) → [STRUCTURE.md](./STRUCTURE.md) → [overall-spec.md](./overall-spec.md) → [001 spec.md](./001-electron-shell/spec.md) |
| **架构师 / Tech Lead** | [ARCHITECTURE.md](./ARCHITECTURE.md) → [TECH.md](./TECH.md) → [overall-plan.md](./overall-plan.md) → [REVIEW_REPORT](../logs/20261020-1/REVIEW_REPORT.md) |
| **ArkTS 开发** | [STRUCTURE.md](./STRUCTURE.md) → [001 plan.md](./001-electron-shell/plan.md) → [constitution.md](./constitution.md) |
| **Electron / 前端开发** | [001 plan.md](./001-electron-shell/plan.md) §3.2/§3.3 → `web_engine/src/main/resources/resfile/resources/app/main.js` |
| **测试 / QA** | [overall-test-cases.md](./overall-test-cases.md) → [001 test-cases.md](./001-electron-shell/test-cases.md) → [TEST_REPORT](../logs/20261020-1/TEST_REPORT.md) |
| **产品经理** | [overall-spec.md](./overall-spec.md) → [001 spec.md](./001-electron-shell/spec.md) → [../README.md](../README.md) |

---

**文档维护者：** ElectronShell 开发团队
