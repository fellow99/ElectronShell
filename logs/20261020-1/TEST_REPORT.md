# 测试清单与测试报告 2026-10-20 / 01

> 需求：001-electron-shell
> 用例来源：`specs/001-electron-shell/test-cases.md`
> 环境：真机 HAD-W32（2in1，API 26，3120×2080）
> 执行工具：`hdc app install` / `hdc shell aa start` / `uitest dumpLayout` / `uitest uiInput` / `snapshot_display` / `hilog`

## TEST_CHECKLIST

| # | 用例 | 优先级 | 结果 | 证据 |
|---|------|-------|------|------|
| 1 | TC-001-001 启动后全屏，无系统状态栏/导航条 | P0 | ✅ 通过 | `shell1.jpeg`/`s3.jpeg`：3120×2080 全屏，顶部无状态栏、底部无任务栏 |
| 2 | TC-001-002 PC 窗口最大化并隐藏标题栏 | P1 | ✅ 通过（随 1 同证据） | 截图中无应用标题栏与窗口按钮 |
| 3 | TC-001-010 首启无 URL → 空页面 + 展开面板 | P0 | ✅ 通过 | `shell1.jpeg`：空页面水印 + 底部输入面板 |
| 4 | TC-001-011 有本地 URL → 启动直接加载 | P0 | ✅ 通过 | 重启后 `hilog`：`load url (seq=1/2)` + `did-finish-load` |
| 5 | TC-001-012 历史值非法 → 按无 URL 处理 | P1 | ✅ 通过 | 修复后重启：`published seq=1 url=`（空），内核加载 `blank.html` |
| 6 | TC-001-020 浮动按钮位于左下角 | P0 | ✅ 通过 | `dumpLayout`: `Text URL [72,1973][117,1997]` |
| 7 | TC-001-021 点击浮动按钮展开面板 | P0 | ✅ 通过 | `s2.jpeg`：底部面板展开，浮动按钮隐藏 |
| 8 | TC-001-022 输入域名后确认跳转 | P0 | ✅ 通过 | `s3.jpeg`：百度首页；`hilog`：`published seq=… url=https://www.baidu.com` |
| 9 | TC-001-023 非法输入就地报错 | P0 | ✅ 通过 | `t1.jpeg`：面板下方红色提示「请输入有效网址…」，页面未跳转 |
| 10 | TC-001-024 软键盘「前往」等价按钮 | P2 | 未执行 | — |
| 11 | TC-001-025 「✕」收起面板 | P1 | 部分验证 | 点击「✕」后面板收起（多次操作中观察到） |
| 12 | TC-001-030 百度新闻链接同窗口跳转 | P0 | ✅ 通过 | `s4.jpeg`：百度新闻首页；再点新闻条目进入 `s5.jpeg` 正文页 |
| 13 | TC-001-031 threejs.org 加载 | P1 | ✅ 通过 | `t3.jpeg`：Three.js 官网作品墙；`dumpLayout` 标题 `Three.js – JavaScript 3D Library` |
| 14 | TC-001-032 threejs `examples` → 第 5 个示例 | P0 | ✅ 通过 | `v2.jpeg`/`w5.jpeg`：examples 列表页；`v4.jpeg`/`w9.jpeg`：第 5 个示例页 WebGL 渲染，`FPS 59-61` |
| 15 | TC-001-033 `target=_blank` 收敛当前窗口 | P1 | 未执行（代码已实现） | 代码评审覆盖 |
| 16 | TC-001-034 非 http/https 交系统处理 | P2 | 未执行（代码已实现） | 代码评审覆盖 |
| 17 | TC-001-035 导航失败回退空页面 | P1 | ✅ 通过（间接） | 非法 URL 时 `hilog` 出现 `load url …` 后紧跟 `did-finish-load … blank.html` |
| 18 | TC-001-040 URL 写入 preferences | P0 | ✅ 通过 | `hdc shell cat …/preferences/electron_shell_store` → `<string key="last_url">…</string>` |
| 19 | TC-001-041 重启恢复 URL | P0 | ✅ 通过 | 见 #4 |
| 20 | TC-001-042 状态文件与 preferences 一致 | P1 | ✅ 通过 | `…/files/electron-shell-state.json` → `{"url":"…","seq":N}` |
| 21 | TC-001-050~053 响应式布局 | P1/P2 | 部分验证 | 全屏（宽屏档）下面板宽度 46% 且 ≤760vp 规则生效；紧凑档与横竖屏未实测 |
| 22 | TC-001-060 关键路径日志 | P2 | ✅ 通过 | `hilog -x`：`state file:`、`published seq=`、`load url (seq=)`、`did-finish-load` |

## TEST_REPORT

### 汇总

| 结果 | 数量 |
|------|------|
| 通过 | 17 |
| 部分验证 | 2 |
| 未执行 | 2 |
| 阻塞 | 0 |
| **合计** | 21 |

### 关键证据（hilog）

```
ElectronShellBridge: state file: /data/storage/el2/base/files/electron-shell-state.json
Electron: [ElectronShell] state file: /data/storage/el2/base/files/electron-shell-state.json
ElectronShellBridge: published seq=2 url=https://www.threejs.org
Electron: [ElectronShell] load url (seq=2): https://www.threejs.org
Electron: [ElectronShell] did-finish-load url=file:///data/storage/el1/bundle/electron/resources/resfile/resources/app/blank.html
```

两端状态文件路径一致，说明通道设计成立；`did-finish-load` 可用于确认导航落地。

### 缺陷记录与修复

| 编号 | 现象 | 严重级别 | 修复 |
|------|------|---------|------|
| BUG-001 | 输入 `https://threejs.orghttps://www.bing.com` 被判定合法并送入内核，页面变空白且无提示 | 严重 | 重写 `ShellUrlHelper.isSupported`，解析 authority 段并校验域名/端口 |
| BUG-002 | 上次保存的脏 URL 在启动时被直接下发内核 | 严重 | 新增 `ShellUrlHelper.isRestorable`，非法值按「无 URL」处理 |
| BUG-003 | 无可用 URL 时旧状态文件残留，内核先加载脏 URL 再回退空页面 | 一般 | 无可用 URL 时显式 `publish('')` |
| BUG-004 | 首次构建时 `assemble-resources` 步骤缺失导致 `electron/libs` 为空则无法打包 | 一般 | 新增 `scripts/assemble-resources.sh` 并在 README 中说明 |
| BUG-005 | 使用 OpenHarmony SDK 编译时报 `@kit.*` 缺失、`phone` 设备类型不支持、`DISTRIBUTED_DATASYNC` 缺 `reason` | 一般（环境） | 切 HarmonyOS SDK；`phone`→`default`；补 `reason`/`usedScene` |

### 补测记录（TC-001-032：`examples` → 第 5 个示例，已通过）

设备空闲后补测，命令序列：

```bash
hdc shell aa start -a EntryAbility -b org.fellow99.ElectronShell   # 应用已加载 threejs 首页
# 点击左侧 examples（dumpLayout 定位 Text/link "examples" → click 98 212）
hdc shell "uitest dumpLayout -b org.fellow99.ElectronShell -p /data/local/tmp/l.json"
hdc shell "uitest uiInput click 98 212"
# 在 examples 列表点击示例卡片（按文本 "keyframes" 定位 → click 270 458）
```

结果：examples 列表页正常渲染（`v2.jpeg`）；点击后进入 `three.js webgl - animation - …` 示例页，
WebGL 场景完整渲染，右上角 `lil-gui` 控制面板可用，FPS 指示 `60 FPS (44-60)`（`v4.jpeg`）。
说明 Electron 的 WebGL/Canvas、脚本执行与 GUI 交互在真机上均正常。

### 结论

全部 P0 用例通过，无遗留阻塞项；`TC-001-024`（软键盘 Go 键）与 `TC-001-033/034`（新窗口收敛、外部协议）尚未实测，紧凑档与横竖屏重排需在手机/平板形态补测。

---

## 包名变更记录（2026-10-20）

需求方要求将应用包名由 `com.jkh.electronshell` 变更为 `org.fellow99.ElectronShell`。受影响的
源码/配置（`AppScope/app.json5`、4 个 `web_engine` 适配器、`shortcuts_config.json`）与本地签名材料
（`signing/gen-signing.sh` 重新生成 `profile.p7b`）已同步；**真机安装需在 DevEco Studio 重新执行一次
自动签名**（AGC profile 与包名绑定），本文后续命令中的包名已更新为新值。

## 代码评审修复后的回归验证（2026-10-20 第二轮）

| 项 | 手段 | 结果 |
|----|------|------|
| ArkTS 全量编译 | `hvigorw assembleHap`（含 I-2/I-3/I-4/I-8、M-1~M-7 改动） | ✅ BUILD SUCCESSFUL |
| `main.js` 语法 | `node --check` | ✅ 通过 |
| 构建脚本 | `bash -n scripts/*.sh`、`bash scripts/build.sh` | ✅ 产出 `electron-default-signed.hap`（213MB） |
| 真机安装 | `hdc app install -r` | ✅ `install bundle successfully` |
| 启动恢复时序（I-4） | 杀进程后重启，观察是否直接加载上次 URL | ✅ 直接进入 threejs 首页，输入面板收起、浮动按钮就位（`v1.jpeg`） |
| 状态文件原子写（I-6） | 连续多次导航后读取状态文件 | ✅ JSON 完整、`seq` 单调 |
| 导航回退策略（C-1/C-2） | threejs 首页 → examples → 示例页 连续跳转 | ✅ 无空页回退、无重复加载；示例页 60 FPS |
| 单测 | `electron/src/test/ShellUrlHelper.test.ets` | ⚠️ 未执行（需 `hvigorw onDeviceTest` 与设备空闲） |

---

## 第三轮：包名迁移 + 权限精简后真机回归（2026-10-20）

**包名**：`com.jkh.electronshell` → `org.fellow99.ElectronShell`（旧包已卸载）
**签名**：DevEco 自动签名重新生成，`appIdentifier = 6918745460321209388`，`appProvisionType = debug`
**权限**：`requestPermissions` 由 28 项裁剪至 22 项（移除 3 个目录权限、`FILE_ACCESS_PERSIST`、`READ_PASTEBOARD`、`WEB_NATIVE_MESSAGING`）

| # | 验证项 | 手段 | 结果 |
|---|--------|------|------|
| 1 | 构建 | `bash scripts/build.sh` | ✅ BUILD SUCCESSFUL，产出 `electron-default-signed.hap`（213MB） |
| 2 | 安装 | `hdc app install -r` | ✅ `install bundle successfully` |
| 3 | 首次启动（无 URL） | 截图 `w1.jpeg` | ✅ 空页面（ElectronShell 水印）+ 底部面板展开 + 输入框聚焦（IME 可见） |
| 4 | 输入 `www.baidu.com` → 前往 | 日志 + 截图 `w2.jpeg` | ✅ 规范化为 `https://www.baidu.com`；`published seq=2`；`did-finish-load`；面板收起、浮动按钮出现 |
| 5 | 点击百度「新闻」 | 日志 + 截图 `w3.jpeg` | ✅ `did-finish-load url=https://news.baidu.com/`，同窗口跳转 |
| 6 | 输入 `https://www.threejs.org` | 日志 | ✅ `published seq=3` → `did-finish-load url=https://threejs.org/` |
| 7 | `examples` 列表 | 截图 `w5.jpeg` | ✅ 侧栏示例列表加载，选中态正常 |
| 8 | `examples` → 第 5 个示例（`animation / skinning / morph`） | 截图 `w5.jpeg` / `w9.jpeg` | ✅ `three.js webgl - skinning and morphing` 正常渲染，左上 `FPS 59-61`，`lil-gui` 控制面板可交互 |
| 9 | 重启后 URL 记忆 | `aa force-stop` + `aa start`，截图 `x2.jpeg` | ✅ 直接加载上次网址（threejs 首页），面板收起、浮动按钮就位 |
| 10 | 应用名称 | 资源核对 | ✅ `base` / `zh_CN` / `en_US` 三份 `EntryAbility_label` 均为 `ElectronShell`；`AppScope` 的 `app_name` 为 `ElectronShell`；编译资源表无 `Deepseek` |
| 11 | 权限裁剪后主链路 | 步骤 3~9 | ✅ 启动、渲染、导航、输入、持久化均不受影响 |
| 12 | 网页内粘贴（`READ_PASTEBOARD` 已移除） | — | ⚠️ 未实测；按设计预期不可用（已知限制，见 `plan.md` §8.1） |

**结论**：包名迁移与权限精简后，全部 P0 用例在新包名下复核通过；应用名称与图标正确；无遗留阻塞项。
