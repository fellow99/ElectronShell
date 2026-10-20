# ElectronShell 测试用例索引

> 最后更新：2026-10-20
> 本文件是全工程测试用例的**索引与总览**。逐条用例的前置条件、步骤与预期结果见各模块 `test-cases.md`。

---

## 1. 用例目录

| 模块 | 用例文档 | 用例数 | 最近执行 |
|------|---------|-------|---------|
| 001-electron-shell | [001-electron-shell/test-cases.md](./001-electron-shell/test-cases.md) | 21 | 2026-10-20（部分，见 `logs/20261020-1/TEST_REPORT.md`） |
| **合计** | 1 个模块 | **21** | — |

---

## 2. 用例分布

| 功能域 | 用例编号区间 | 数量 | 优先级分布 |
|--------|-------------|------|-----------|
| 全屏与沉浸式 | TC-001-001 ~ 002 | 2 | P0×1，P1×1 |
| 启动加载 | TC-001-010 ~ 012 | 3 | P0×2，P1×1 |
| 浮动入口与地址输入 | TC-001-020 ~ 025 | 6 | P0×4，P1×1，P2×1 |
| 内核导航 | TC-001-030 ~ 035 | 6 | P0×2，P1×3，P2×1 |
| 本地持久化 | TC-001-040 ~ 042 | 3 | P0×2，P1×1 |
| 响应式布局 | TC-001-050 ~ 053 | 4 | P1×3，P2×1 |
| 可观测性 | TC-001-060 | 1 | P2×1 |

---

## 3. 需求覆盖矩阵

| 需求 ID | 说明 | 覆盖用例 |
|---------|------|---------|
| FR-001-001 | 全屏布局覆盖系统栏区域 | TC-001-001 |
| FR-001-002 | 隐藏状态栏与导航指示条（失败可降级） | TC-001-001 |
| FR-001-003 | 2in1 最大化 + 沉浸式 | TC-001-001 / TC-001-002 |
| FR-001-010 | 启动读取本地 URL | TC-001-011 |
| FR-001-011 | 有合法 URL 则加载、面板收起 | TC-001-011 / TC-001-041 |
| FR-001-012 | 无 URL 则空页面 + 展开面板 | TC-001-010 |
| FR-001-013 | 非法历史值按无 URL 处理 | TC-001-012 |
| FR-001-020 | 左下角常驻浮动按钮 | TC-001-020 / TC-001-021 |
| FR-001-021 | 点击展开面板并聚焦 | TC-001-021 |
| FR-001-022 | 面板提供「前往」与「✕」 | TC-001-021 / TC-001-025 |
| FR-001-023 | 输入规整（补 https://） | TC-001-022 |
| FR-001-024 | 输入校验 + 就地报错 | TC-001-023 |
| FR-001-025 | 保存 → 导航 → 收起 | TC-001-022 / TC-001-042 |
| FR-001-026 | 键盘 Go 等价「前往」 | TC-001-024 |
| FR-001-030 | 同窗口跳转 | TC-001-030 / TC-001-031 / TC-001-032 |
| FR-001-031 | 新窗口请求收敛 | TC-001-033 |
| FR-001-032 | 外部协议交系统 | TC-001-034 |
| FR-001-033 | 导航失败回退空页面 + 日志 | TC-001-035 |
| FR-001-040 | URL 持久化 | TC-001-040 / TC-001-042 |
| FR-001-041 | 持久化失败不阻断导航 | （由代码评审覆盖，未设计独立用例） |
| FR-001-050 | 三档断点 | TC-001-050 / TC-001-051 |
| FR-001-051 | 窗口尺寸变化实时重排 | TC-001-052 / TC-001-053 |
| FR-001-052 | 面板宽度约束 | TC-001-050 / TC-001-051 |
| FR-001-053 | 控件尺寸随档位变化 | TC-001-051 |
| 非功能-可观测性 | 关键路径日志 | TC-001-060 |

---

## 4. 执行环境与命令基线

| 项 | 值 |
|----|----|
| 设备 | `HAD-W32`（2in1，API 26，3120×2080），序列号 `3QC0226526001227` |
| 安装 | `hdc app install -r electron/build/default/outputs/default/electron-default-signed.hap` |
| 启动 | `hdc shell aa start -a EntryAbility -b com.jkh.electronshell` |
| 停止 | `hdc shell aa force-stop com.jkh.electronshell` |
| 抓屏 | `hdc shell snapshot_display -f /data/local/tmp/s.jpeg` + `hdc file recv` |
| 布局 | `hdc shell "uitest dumpLayout -b com.jkh.electronshell -p /data/local/tmp/l.json"` |
| 输入 | `hdc shell "uitest uiInput click <x> <y>"` / `uitest uiInput text <text>` / `uitest uiInput keyEvent 2055`（删除） |
| 日志 | `hdc shell hilog -x`（注意本机 hilog 不支持 `-x -z` 组合） |
| 应用数据 | `hdc shell cat /data/app/el2/100/base/com.jkh.electronshell/files/electron-shell-state.json` |

---

## 5. 已知限制与未覆盖项

| 项 | 说明 | 建议 |
|----|------|------|
| TC-001-032（threejs examples 点击） | 执行时设备被其它应用抢占前台 | 设备空闲时按 `TEST_REPORT.md` 补测步骤执行 |
| TC-001-024 / 033 / 034 | 需特定页面或键盘交互 | 纳入下一轮回归 |
| TC-001-050~053 | 需手动改变窗口尺寸/旋转 | 在平板与手机形态上补测 |
| 单元测试 | 未搭建 hypium 可跑用例 | 建议为 `ShellUrlHelper` 增加表驱动测试 |
| 自动化 | 依赖 `hdc`/`uitest` 人工编排 | 可将 `logs` 中的脚本沉淀为 `scripts/test-*.sh` |
