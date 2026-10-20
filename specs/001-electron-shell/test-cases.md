# 001-electron-shell 测试用例

> 需求编号：001（Electron 浏览器壳）
> 对应规格：`specs/001-electron-shell/spec.md`
> 测试环境：HarmonyOS 真机 HAD-W32（2in1，API 26，3120×2080）；HarmonyOS 6.1.1 SDK；Electron v37.2.3
> 执行方式：`hdc` + `uitest dumpLayout` / `uitest uiInput` / `snapshot_display` / `hilog`

## 用例命名

`TC-<需求号>-<序号>`；优先级 `P0`（阻断）/ `P1`（主要）/ `P2`（次要）。

---

## 1. 全屏与沉浸式

### TC-001-001（P0）启动后全屏，无系统状态栏与底部导航条

- **前置**：应用已安装并授权；设备为 2in1 形态
- **步骤**：
  1. 点击桌面图标启动应用
  2. `hdc shell snapshot_display -f /data/local/tmp/s.jpeg` 抓屏
- **预期**：截图分辨率等于整屏分辨率（3120×2080）；画面顶部无系统状态栏、底部无任务栏/Dock；浏览内容铺满
- **对应需求**：FR-001-001 / FR-001-002 / FR-001-003

### TC-001-002（P1）PC 窗口最大化并隐藏标题栏

- **步骤**：启动后观察窗口边框
- **预期**：无应用标题栏、无最大化/最小化/关闭按钮；窗口占满屏幕
- **对应需求**：FR-001-003

---

## 2. 启动加载

### TC-001-010（P0）首次启动无 URL 时显示空页面 + 展开输入面板

- **前置**：清除应用数据（或首次安装）
- **步骤**：启动应用
- **预期**：浏览区域显示空页面（居中水印）；底部自动出现 URL 输入面板；输入框获得焦点
- **对应需求**：FR-001-012

### TC-001-011（P0）有本地 URL 时启动直接加载

- **前置**：上次会话确认过 `https://www.baidu.com`
- **步骤**：杀掉应用后重新启动
- **预期**：浏览区域直接显示百度首页；输入面板收起；左下角浮动按钮可见
- **对应需求**：FR-001-010 / FR-001-011

### TC-001-012（P1）历史值为非法 URL 时按无 URL 处理

- **前置**：本地 `last_url` 被写成非法值（如 `https://a.comhttps://b.com`）
- **步骤**：启动应用
- **预期**：不把非法值送入内核；显示空页面并展开输入面板；`hilog` 可见内核未执行 `loadURL` 非法地址
- **对应需求**：FR-001-013

---

## 3. 浮动入口与地址输入

### TC-001-020（P0）浮动按钮位于左下角

- **步骤**：`uitest dumpLayout` 查找文本 `URL` 的节点
- **预期**：节点位于屏幕左下区域（真机实测 bounds 约 `[72,1973][117,1997]`，中心距左边界 < 150px、距底边界 < 120px）
- **对应需求**：FR-001-020

### TC-001-021（P0）点击浮动按钮展开输入面板并聚焦

- **步骤**：点击浮动按钮
- **预期**：底部出现输入面板（含输入框、「前往」按钮、「✕」）；输入框获得焦点（可直接键入）；浮动按钮隐藏
- **对应需求**：FR-001-020 / FR-001-021 / FR-001-022

### TC-001-022（P0）输入域名后确认可跳转

- **步骤**：
  1. 点击浮动按钮
  2. 输入 `www.baidu.com`
  3. 点击「前往」
- **预期**：输入被补全为 `https://www.baidu.com`；浏览区域跳转百度首页；面板收起；浮动按钮重新出现
- **对应需求**：FR-001-023 / FR-001-025

### TC-001-023（P0）非法输入就地报错且不跳转

- **步骤**：输入 `https://a.comhttps://b.com` 后点击「前往」
- **预期**：面板下方出现「请输入有效网址，例如 www.baidu.com」；页面不跳转；面板保持展开
- **对应需求**：FR-001-024

### TC-001-024（P2）软键盘「前往」等价于点击按钮

- **步骤**：输入 `www.threejs.org`，按软键盘 Go 键
- **预期**：与点击「前往」一致（跳转 + 面板收起）
- **对应需求**：FR-001-026

### TC-001-025（P1）点击「✕」收起面板且不改动当前页面

- **步骤**：打开面板后点击「✕」
- **预期**：面板收起，当前网页保持不变，浮动按钮重新出现
- **对应需求**：FR-001-022

---

## 4. 内核导航

### TC-001-030（P0）测试站点 1：百度首页 → 点击「新闻」链接

- **测试站点**：`https://www.baidu.com`
- **前置**：应用已安装并启动；URL 输入面板可用
- **步骤**：
  1. 点左下角 **URL** 浮动按钮唤出输入面板
  2. 输入 `www.baidu.com`，点「前往」（输入会被规整为 `https://www.baidu.com`）
  3. 待百度首页渲染完成后，点击页面**顶部导航栏**中的「新闻」链接
- **预期**：
  1. 首页加载完成：`hilog` 出现 `published seq=N url=https://www.baidu.com` 与
     `did-finish-load url=https://www.baidu.com/`；输入面板收起，浮动按钮重新出现
  2. 点击「新闻」后当前浏览区域切换为**百度新闻首页**：
     `did-finish-load url=https://news.baidu.com/`
  3. 全程**不出现第二个系统窗口**；浮动按钮仍可用；页面可滚动、可点击
- **对应需求**：FR-001-030
- **执行状态**：✅ 通过（`com.jkh.electronshell` 与 `org.fellow99.ElectronShell` 两轮均通过；
  证据 `w2.jpeg` 百度首页、`w3.jpeg` 百度新闻）

### TC-001-031（P1）测试站点 2：threejs.org 首页加载

- **测试站点**：`https://www.threejs.org`
- **步骤**：唤出输入面板 → 输入 `https://www.threejs.org` → 点「前往」
- **预期**：浏览区域加载 Three.js 官网首页（左侧 Learn/Tools/Community 导航 + 右侧作品墙）；
  `hilog` 出现 `did-finish-load url=https://threejs.org/`
- **备注**：该站点首字节较慢（实测约 10~20s），属站点网络状况，非应用缺陷；
  等待期间应保持上一页面或空页面，不得出现错误页
- **对应需求**：FR-001-030
- **执行状态**：✅ 通过（`published seq=3` → `did-finish-load url=https://threejs.org/`）

### TC-001-032（P0）测试站点 2：threejs `examples` → 第 5 个示例

- **测试站点**：`https://www.threejs.org`
- **前置**：已完成 TC-001-031，当前停留在 Three.js 官网首页
- **步骤**：
  1. 点击左侧 **Learn** 分组下的 `examples` 链接
  2. 在 `examples` 页面左侧示例列表中，点击**第 5 个**示例：
     `animation / skinning / morph`
     （列表顺序：① animation / keyframes ② animation / skinning / blending
     ③ animation / skinning / additive / blending ④ animation / skinning / ik ⑤ animation / skinning / morph）
- **预期**：
  1. `examples` 列表页加载成功：左侧 `webgl` 分组 + 缩略图网格，被选项有蓝色高亮边框
  2. 点击第 5 个示例后，主区域加载 `three.js webgl - skinning and morphing`
     （页头可见标题与模型署名 `Model by Tomás Laulhé …`）
  3. **WebGL 场景正常渲染**：黄黑配色机器人模型 + 地面网格 + 阴影
  4. 右上 `lil-gui` 控制面板（Controls / States / Emotions / Expressions）可交互，
     切换 `state`、点击 `Jump` 等按钮模型有响应
  5. 左上 FPS 指示器显示约 60（真机实测 `59-61`）
  6. 全程无 `did-fail-load`，不出现第二个系统窗口
- **对应需求**：FR-001-030
- **执行状态**：✅ 通过（2026-10-20，两轮均通过；新包名轮证据 `w5.jpeg` 列表页、`w9.jpeg` 示例页
  含 `FPS 59-61`）
- **备注**：示例顺序以 3120×2080 全屏下左侧栏可见顺序为准；若站点改版导致顺序变化，
  按「第 5 个可见示例」执行，并在测试报告中记录实际示例名

### TC-001-033（P1）`target="_blank"` 收敛到当前窗口

- **前置**：打开一个含 `target="_blank"` 链接的页面
- **步骤**：点击该链接
- **预期**：目标页在当前浏览区域打开；`BrowserWindow` 数量保持为 1
- **对应需求**：FR-001-031

### TC-001-034（P2）非 http/https 协议交由系统处理

- **步骤**：访问含 `mailto:` 链接的页面并点击
- **预期**：不出现空白/错误页；由系统邮件应用接管
- **对应需求**：FR-001-032

### TC-001-035（P1）导航失败回退空页面

- **步骤**：输入一个不存在的主机（如 `https://no-such-host-xyz.invalid`）并确认
- **预期**：页面回退为空页面；`hilog` 出现 `did-fail-load` 或 `loadURL failed`
- **对应需求**：FR-001-033

---

## 5. 本地持久化

### TC-001-040（P0）确认的 URL 写入本地存储

- **步骤**：确认 `https://www.threejs.org` 后执行
  `hdc shell cat /data/app/el2/100/base/org.fellow99.ElectronShell/haps/electron/preferences/electron_shell_store`
- **预期**：文件内容包含 `<string key="last_url">https://www.threejs.org</string>`
- **对应需求**：FR-001-040
- **实测**：通过

### TC-001-041（P0）重启后恢复该 URL

- **步骤**：`hdc shell aa force-stop org.fellow99.ElectronShell` → `aa start -a EntryAbility -b org.fellow99.ElectronShell`
- **预期**：启动后直接加载 `https://www.threejs.org`，面板收起
- **对应需求**：FR-001-011 / FR-001-040

### TC-001-042（P1）状态文件与偏好存储双写一致

- **步骤**：确认 URL 后执行
  `hdc shell cat /data/app/el2/100/base/org.fellow99.ElectronShell/files/electron-shell-state.json`
- **预期**：内容形如 `{"url":"https://www.threejs.org","seq":N}`，`url` 与 preferences 中一致
- **对应需求**：FR-001-025 / FR-001-040
- **实测**：通过

---

## 6. 响应式布局

### TC-001-050（P1）宽屏档（≥ 840vp）输入面板最大宽度受限

- **前置**：2in1 全屏（约 1560vp 宽）
- **步骤**：打开输入面板并观察宽度
- **预期**：面板宽度约为视口 46%，且不超过 760vp；输入行两侧留白明显
- **对应需求**：FR-001-050 / FR-001-052

### TC-001-051（P1）窗口拉窄到 < 600vp 切换紧凑档

- **步骤**：拖动窗口宽度到 600vp 以下，打开输入面板
- **预期**：面板宽度约为视口 92%；按钮、字号变小；无溢出、无换行错乱
- **对应需求**：FR-001-050 / FR-001-052 / FR-001-053

### TC-001-052（P1）横竖屏切换实时重排

- **步骤**：设备旋转（或在平板上切换横竖屏）后打开输入面板
- **预期**：布局按新宽度立即重排，不需要重启应用
- **对应需求**：FR-001-051

### TC-001-053（P2）软键盘弹出后面板不被遮挡

- **步骤**：展开输入面板使软键盘弹出
- **预期**：面板随可视区上移，输入框与「前往」按钮仍然完整可见可点
- **对应需求**：FR-001-051

---

## 7. 可观测性

### TC-001-060（P2）关键路径日志完备

- **步骤**：`hdc shell hilog -x` 过滤 `ElectronShellBridge|ShellOverlay|ElectronShell]`
- **预期**：可见 `state file: …`、`published seq=N url=…`、`[ElectronShell] load url (seq=N)`、`did-finish-load`
- **对应需求**：非功能需求-可观测性
- **实测**：通过

---

## 执行汇总（2026-10-20）

执行轮次：
- **第 1 轮**：包名 `com.jkh.electronshell`（首版）
- **第 2 轮**：包名 `org.fellow99.ElectronShell`（包名迁移 + 权限 28→22 后回归）

| 结果 | 用例 | 说明 |
|------|------|------|
| 通过（两轮） | TC-001-001、TC-001-010、TC-001-011、TC-001-020、TC-001-021、TC-001-030（百度→新闻）、TC-001-031（threejs 首页）、TC-001-032（examples→第 5 个示例）、TC-001-040、TC-001-060 | 主链路在新旧包名下均稳定 |
| 通过（第 1 轮） | TC-001-002、TC-001-012、TC-001-022、TC-001-023、TC-001-042 | 第 2 轮未重复执行，代码路径未变更 |
| 通过（第 2 轮） | TC-001-041（重启恢复 URL） | 新包名数据目录下已验证 |
| 未执行 | TC-001-024（软键盘 Go）、TC-001-033（`target=_blank`）、TC-001-034（`mailto:`）、TC-001-050~053（响应式/横竖屏） | 需特定页面、键盘交互或多种设备形态 |
| 不具备条件 | 网页内粘贴 | 已按需求移除 `READ_PASTEBOARD`，预期不可用（见 `plan.md` §8.1） |
| 阻塞 | 无 | — |

> 截图与 hilog 证据见 `logs/20261020-1/TEST_REPORT.md`（第 1 轮为 `s*.jpeg`/`t*.jpeg`，第 2 轮为 `w*.jpeg`/`x*.jpeg`）。
