/*
 * ElectronShell —— 内嵌在 HarmonyOS 应用中的 Electron 浏览器壳主进程。
 *
 * 职责：
 *   1. 创建一个无边框 BrowserWindow，铺满宿主 HarmonyOS 窗口；
 *   2. 从 ArkTS 侧发布的「外壳状态文件」读取目标 URL，加载该 URL；
 *      没有 URL 时加载本地空页面 blank.html；
 *   3. 轮询状态文件，序号变化即视为一次新的导航请求（URL 输入框确认）；
 *   4. 把页面内的新窗口请求（target=_blank / window.open）收敛到当前窗口，
 *      保证浏览体验是单窗口浏览器。
 *
 * 与 ArkTS 的约定（状态文件）：
 *   { "url": "https://www.baidu.com", "seq": 3 }
 *   - 路径由 ArkTS 写入 ApplicationContext.filesDir，Electron 侧默认取
 *     app.getPath('userData')（由启动参数 --user-data-dir 指向同一目录）；
 *   - 也可通过启动参数 --shell-state-file=<绝对路径> 显式指定。
 *
 * 该文件随 HAP 打包进 resources/resfile/resources/app，由 Electron 主进程加载。
 */

'use strict';

const { app, BrowserWindow, shell } = require('electron');
const fs = require('fs');
const path = require('path');

const STATE_FILE_NAME = 'electron-shell-state.json';
const STATE_POLL_INTERVAL_MS = 300;
const BLANK_PAGE = path.join(__dirname, 'blank.html');

/** Chromium 中「导航被新导航顶替」的错误码，属正常控制流，不是失败 */
const ERR_ABORTED = -3;

let shellWindow = null;
let stateFile = '';
/** 已应用的状态序号，初值 -1 保证首次一定应用 */
let lastAppliedSeq = -1;
let pollTimer = null;
/** 导航令牌：每次发起导航自增，异步回调据此判断自己是否已过期 */
let navToken = 0;

/**
 * 解析状态文件路径：优先使用启动参数，其次使用 userData 目录。
 * @returns {string} 状态文件绝对路径
 */
function resolveStateFile() {
  const prefix = '--shell-state-file=';
  const fromArgv = process.argv.find((item) => typeof item === 'string' && item.startsWith(prefix));
  if (fromArgv) {
    return fromArgv.slice(prefix.length);
  }
  return path.join(app.getPath('userData'), STATE_FILE_NAME);
}

/**
 * 读取状态文件。
 *
 * 区分三种情况，避免把「读不到」误判为「URL 为空」：
 *   - 文件不存在（首次启动）→ 返回 { url: '', seq: 0 }；
 *   - 内容损坏 / 写入中 → 返回 null（调用方应视为「无新状态」直接跳过）；
 *   - 正常 → 返回 { url, seq }。
 *
 * @param {string} file 状态文件路径
 * @returns {{ url: string, seq: number } | null}
 */
function readState(file) {
  let raw;
  try {
    raw = fs.readFileSync(file, 'utf-8');
  } catch (err) {
    if (err && err.code === 'ENOENT') {
      return { url: '', seq: 0 };
    }
    console.warn('[ElectronShell] read state failed:', err && err.message ? err.message : err);
    return null;
  }
  try {
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object') {
      console.warn('[ElectronShell] state is not an object, ignored');
      return null;
    }
    return {
      url: typeof parsed.url === 'string' ? parsed.url.trim() : '',
      seq: typeof parsed.seq === 'number' ? parsed.seq : 0
    };
  } catch (err) {
    // 半写 / 截断：本轮跳过，等下次轮询读到完整内容
    console.warn('[ElectronShell] state json invalid, ignored:', err && err.message ? err.message : err);
    return null;
  }
}

/**
 * 判断字符串是否为可加载的绝对 URL。
 * @param {string} url 待校验字符串
 * @returns {boolean}
 */
function isLoadableUrl(url) {
  return /^(https?|file):\/\//i.test(url);
}

/**
 * 判断 loadURL 的 rejection 是否只是「被新导航顶替」。
 * @param {unknown} err 错误对象
 * @returns {boolean}
 */
function isAbortedError(err) {
  if (!err) {
    return false;
  }
  if (err.code === 'ERR_ABORTED' || err.errno === ERR_ABORTED) {
    return true;
  }
  return typeof err.message === 'string' && err.message.indexOf('ERR_ABORTED') >= 0;
}

/**
 * 在当前窗口加载 URL，并返回本次导航令牌。
 * @param {string} url 目标 URL
 * @returns {number} 导航令牌
 */
function navigateTo(url) {
  navToken += 1;
  const token = navToken;
  shellWindow.loadURL(url).catch((err) => {
    if (isAbortedError(err)) {
      // 被后续导航顶替：不处理，避免打断新导航
      return;
    }
    if (token !== navToken) {
      return;
    }
    console.error('[ElectronShell] loadURL failed:',
      err && err.message ? err.message : err, 'url=' + url);
    showBlankPage();
  });
  return token;
}

/**
 * 把当前状态应用到窗口：seq 未变化时不做任何事（首次加载除外）。
 * @param {boolean} firstLoad 是否为窗口创建后的首次加载
 */
function applyState(firstLoad) {
  if (!shellWindow || shellWindow.isDestroyed()) {
    return;
  }
  const state = readState(stateFile);
  if (state === null) {
    // 读不到 / 解析失败：保持现状，等下一次轮询
    return;
  }
  const seq = state.seq;
  if (!firstLoad && seq === lastAppliedSeq) {
    return;
  }
  lastAppliedSeq = seq;

  if (isLoadableUrl(state.url)) {
    console.log(`[ElectronShell] load url (seq=${seq}): ${state.url}`);
    navigateTo(state.url);
    return;
  }
  showBlankPage();
}

/** 展示本地空页面 */
function showBlankPage() {
  if (!shellWindow || shellWindow.isDestroyed()) {
    return;
  }
  navToken += 1;
  shellWindow.loadFile(BLANK_PAGE).catch((err) => {
    if (isAbortedError(err)) {
      return;
    }
    console.error('[ElectronShell] load blank page failed:', err && err.message ? err.message : err);
  });
}

/** 创建承载网页的窗口 */
function createShellWindow() {
  // 窗口重建（如 activate）时先释放旧轮询，避免多定时器并存
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }

  shellWindow = new BrowserWindow({
    width: 1280,
    height: 800,
    show: false,
    frame: false,
    autoHideMenuBar: true,
    backgroundColor: '#FFFFFFFF',
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      // 说明：Electron for HarmonyOS 移植对 Chromium 渲染进程沙箱的支持情况未在本工程验证，
      // 因此显式关闭沙箱；页面侧已通过 nodeIntegration:false + contextIsolation:true 隔离。
      // 该风险记录在 specs/001-electron-shell/plan.md「已知风险」。
      sandbox: false
    }
  });

  // 主框架导航失败才回退空页面；子框架（广告等）失败与「被顶替」忽略
  shellWindow.webContents.on('did-fail-load', (event, errorCode, errorDescription, validatedUrl, isMainFrame) => {
    if (isMainFrame === false || errorCode === ERR_ABORTED) {
      return;
    }
    console.error(`[ElectronShell] did-fail-load code=${errorCode} desc=${errorDescription} url=${validatedUrl}`);
    // 空页面自身失败不再回退，避免来回加载
    if (typeof validatedUrl === 'string' && validatedUrl.indexOf('blank.html') >= 0) {
      return;
    }
    applyState(true);
  });

  shellWindow.webContents.on('did-finish-load', () => {
    if (!shellWindow || shellWindow.isDestroyed()) {
      return;
    }
    console.log(`[ElectronShell] did-finish-load url=${shellWindow.webContents.getURL()}`);
  });

  shellWindow.setMenuBarVisibility(false);
  shellWindow.setWindowButtonVisibility(false);
  shellWindow.once('ready-to-show', () => {
    shellWindow.show();
  });

  // 页面内的 window.open / target=_blank 一律在当前窗口内打开，保持单窗口浏览；
  // 非 http/https/file 协议（mailto、tel 等）交给系统处理。
  shellWindow.webContents.setWindowOpenHandler((details) => {
    const target = details && typeof details.url === 'string' ? details.url : '';
    if (isLoadableUrl(target) || target === 'about:blank') {
      navigateTo(target);
      return { action: 'deny' };
    }
    if (target.length > 0) {
      shell.openExternal(target).catch((err) => {
        console.error('[ElectronShell] openExternal failed:',
          err && err.message ? err.message : err, 'url=' + target);
      });
    }
    return { action: 'deny' };
  });

  // 外部协议（mailto/自定义 scheme）交给系统处理
  shellWindow.webContents.on('will-navigate', (event, url) => {
    if (!isLoadableUrl(url) && !url.startsWith('about:')) {
      event.preventDefault();
      shell.openExternal(url).catch((err) => {
        console.error('[ElectronShell] openExternal failed:',
          err && err.message ? err.message : err, 'url=' + url);
      });
    }
  });

  shellWindow.on('closed', () => {
    if (pollTimer) {
      clearInterval(pollTimer);
      pollTimer = null;
    }
    shellWindow = null;
  });

  applyState(true);
  pollTimer = setInterval(() => applyState(false), STATE_POLL_INTERVAL_MS);
}

app.whenReady().then(() => {
  stateFile = resolveStateFile();
  console.log(`[ElectronShell] state file: ${stateFile}`);
  createShellWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createShellWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
