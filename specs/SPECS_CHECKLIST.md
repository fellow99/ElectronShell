# 规格文档检查清单

> 最后更新：2026-10-20
> 用途：追踪每个规范文档的完成情况。`✅ 完成` / `🟡 部分` / `⬜ 未开始`。

---

## 一、项目级文档

| # | 文档 | 路径 | 状态 | 说明 |
|---|------|------|------|------|
| P-01 | 文档索引 | [README.md](./README.md) | ✅ 完成 | 文档总览、模块索引、快速导航 |
| P-02 | 规格检查清单 | [SPECS_CHECKLIST.md](./SPECS_CHECKLIST.md) | ✅ 完成 | 本文件 |
| P-03 | 工程结构 | [STRUCTURE.md](./STRUCTURE.md) | ✅ 完成 | 目录树 + 页面/路由清单 + Ability 清单 |
| P-04 | 技术选型 | [TECH.md](./TECH.md) | ✅ 完成 | 技术栈、版本、依赖、选型理由 |
| P-05 | 整体架构 | [ARCHITECTURE.md](./ARCHITECTURE.md) | ✅ 完成 | 分层、运行时拓扑、数据流、决策与限制 |
| P-06 | 宪法原则 | [constitution.md](./constitution.md) | ✅ 完成 | 九条原则 + 合入红线 |
| P-07 | 整体规格 | [overall-spec.md](./overall-spec.md) | ✅ 完成 | 系统定位、用户故事、功能域、边界 |
| P-08 | 整体技术方案 | [overall-plan.md](./overall-plan.md) | ✅ 完成 | 技术上下文、宪法符合性、横切关注点、部署 |
| P-09 | 测试用例索引 | [overall-test-cases.md](./overall-test-cases.md) | ✅ 完成 | 用例目录、分布、需求覆盖矩阵 |

> 按需求约定，本工程**不产出** `API.md`、`overall-api.md`、`overall-data-model.md`（无对外 API 服务、无独立数据模型层；数据契约已并入 `001-electron-shell/spec.md` 第 4 节与 `plan.md` 第 4 节）。

---

## 二、模块级文档（001-electron-shell）

| # | 文档 | 路径 | 状态 | 说明 |
|---|------|------|------|------|
| M-01 | 功能规格 | [001-electron-shell/spec.md](./001-electron-shell/spec.md) | ✅ 完成 | 5 个用户故事、24 条 FR、7 个验收场景 |
| M-02 | 技术方案 | [001-electron-shell/plan.md](./001-electron-shell/plan.md) | ✅ 完成 | 技术上下文、5 个关键决策、数据模型、接口契约 |
| M-03 | 任务清单 | [001-electron-shell/tasks.md](./001-electron-shell/tasks.md) | ✅ 完成 | 4 个阶段 34 个任务 + 5 个里程碑 |
| M-04 | 测试用例 | [001-electron-shell/test-cases.md](./001-electron-shell/test-cases.md) | ✅ 完成 | 21 条用例（P0×9 / P1×9 / P2×3），含执行状态 |

---

## 三、工程文档（工程根目录）

| # | 文档 | 路径 | 状态 | 说明 |
|---|------|------|------|------|
| R-01 | 工程 README | [../README.md](../README.md) | ✅ 完成 | 项目介绍、环境要求、快速开始、使用说明、调试测试、FAQ |

---

## 四、过程记录（logs）

| # | 文档 | 路径 | 状态 | 说明 |
|---|------|------|------|------|
| L-01 | 开发日志与自查清单 | [../logs/20261020-1/DEV_CHECKLIST.md](../logs/20261020-1/DEV_CHECKLIST.md) | ✅ 完成 | 环境、13 项自查、编译警告说明 |
| L-02 | 代码评审报告 | [../logs/20261020-1/REVIEW_REPORT.md](../logs/20261020-1/REVIEW_REPORT.md) | ✅ 完成 | Critical 2 / Important 12 / Minor 13 的核对与处置 |
| L-03 | 测试清单与报告 | [../logs/20261020-1/TEST_REPORT.md](../logs/20261020-1/TEST_REPORT.md) | ✅ 完成 | 21 条用例执行记录、补测记录、回归验证 |

---

## 五、统计数据

| 类别 | 数量 |
|------|------|
| 项目级文档 | 9 |
| 模块 | 1（001-electron-shell） |
| 模块级文档 | 4 |
| 工程文档 | 1 |
| 过程记录 | 3 |
| **文档合计** | **17** |

---

## 六、完成度判定

| 判定项 | 结论 |
|--------|------|
| 是否扫描完整工程 | ✅ `specs/STRUCTURE.md` 覆盖 227 个受版本管理文件、9 条路由、5 个 Ability |
| 是否阅读 README 与 docs | ✅ 阅读源工程 `harmonypc-electron/README.md` 与 `ohos_hap/docs/*`（Electron 集成/Addon 指导），结论并入 `TECH.md` 与 `001-electron-shell/plan.md` |
| 是否分析各模块源码 | ✅ `web_engine`（126 个 ets）、`electron`（24 个 ets）、Electron 主进程均有分析记录 |
| 是否记录页面/路由清单 | ✅ `STRUCTURE.md` 第 3 节 |
| 是否逐模块输出规格 | ✅ 1 个功能模块 |
| 是否输出测试用例 | ✅ 21 条，含执行状态 |
| 是否做代码评审 | ✅ `logs/20261020-1/REVIEW_REPORT.md` |
| 是否真机验证 | ✅ 全部 P0 用例通过（`logs/20261020-1/TEST_REPORT.md`） |

---

## 七、待办（后续迭代）

| # | 事项 | 优先级 |
|---|------|--------|
| T1 | 执行 `electron/src/test/ShellUrlHelper.test.ets` 单测 | 中 |
| T2 | 在平板形态验证沉浸式全屏（I-1 延时重放效果）与顶部留白 | 中 |
| T3 | 补测 `TC-001-024`（软键盘 Go）、`TC-001-033/034`（新窗口/外部协议） | 中 |
| T4 | 评估开启渲染进程沙箱（`sandbox: true`）的可行性 | 中 |
| T5 | 紧凑档与横竖屏重排在手机形态实测 | 低 |
| T6 | 状态文件轮询改 `fs.watch` 以消除 ≤300ms 延迟 | 低 |
