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

/** 本地空页面（无 URL 时展示） */
let shellWindow = null;
let stateFile = '';
let lastAppliedSeq = -1;
let pollTimer = null;

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
 * 读取状态文件，任何异常（文件不存在 / 写入中 / JSON 损坏）都视为「无状态」。
 * @param {string} file 状态文件路径
 * @returns {{ url: string, seq: number } | null}
 */
function readState(file) {
  try {
    const raw = fs.readFileSync(file, 'utf-8');
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object') {
      return null;
    }
    return {
      url: typeof parsed.url === 'string' ? parsed.url.trim() : '',
      seq: typeof parsed.seq === 'number' ? parsed.seq : 0
    };
  } catch (err) {
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
 * 把当前状态应用到窗口：seq 未变化时不做任何事（首次加载除外）。
 * @param {boolean} firstLoad 是否为窗口创建后的首次加载
 */
function applyState(firstLoad) {
  if (!shellWindow || shellWindow.isDestroyed()) {
    return;
  }
  const state = readState(stateFile);
  const seq = state ? state.seq : 0;
  if (!firstLoad && seq === lastAppliedSeq) {
    return;
  }
  lastAppliedSeq = seq;

  const url = state ? state.url : '';
  if (isLoadableUrl(url)) {
    console.log(`[ElectronShell] load url (seq=${seq}): ${url}`);
    shellWindow.loadURL(url).catch((err) => {
      console.error('[ElectronShell] loadURL failed:', err && err.message ? err.message : err);
      showBlankPage();
    });
    return;
  }
  showBlankPage();
}

/** 展示本地空页面 */
function showBlankPage() {
  if (!shellWindow || shellWindow.isDestroyed()) {
    return;
  }
  shellWindow.loadFile(BLANK_PAGE).catch((err) => {
    console.error('[ElectronShell] load blank page failed:', err && err.message ? err.message : err);
  });
}

/** 创建承载网页的窗口 */
function createShellWindow() {
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
      sandbox: false
    }
  });

  // 本地页面/网络加载失败时把原因写到日志，便于真机排障
  shellWindow.webContents.on('did-fail-load', (event, errorCode, errorDescription, validatedUrl) => {
    console.error(`[ElectronShell] did-fail-load code=${errorCode} desc=${errorDescription} url=${validatedUrl}`);
  });
  shellWindow.webContents.on('did-finish-load', () => {
    console.log(`[ElectronShell] did-finish-load url=${shellWindow.webContents.getURL()}`);
  });

  shellWindow.setMenuBarVisibility(false);
  shellWindow.setWindowButtonVisibility(false);
  shellWindow.once('ready-to-show', () => {
    shellWindow.show();
  });

  // 页面内的 window.open / target=_blank 一律在当前窗口内打开，保持单窗口浏览
  shellWindow.webContents.setWindowOpenHandler((details) => {
    if (isLoadableUrl(details.url)) {
      shellWindow.loadURL(details.url).catch((err) => {
        console.error('[ElectronShell] open url failed:', err && err.message ? err.message : err);
      });
    }
    return { action: 'deny' };
  });

  // 外部协议（mailto/自定义 scheme）交给系统处理
  shellWindow.webContents.on('will-navigate', (event, url) => {
    if (!isLoadableUrl(url) && !url.startsWith('about:')) {
      event.preventDefault();
      shell.openExternal(url).catch(() => {});
    }
  });

  shellWindow.on('closed', () => {
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
