/**
 * ArkTS 与 Electron 主进程之间的导航通道。
 *
 * 通道形态：应用级文件目录下的一个 JSON 状态文件
 *   { "url": "https://www.baidu.com", "seq": 3 }
 *
 * 选择文件通道而不是原生命令通道（nativeContext.ExecuteCommand）的原因：
 *   1. 该通道两端都在本工程内，行为完全可预期、可本地验证；
 *   2. 不依赖 web_engine 内部未导出的 JsBindingUtils / CommandType；
 *   3. Electron 侧 --user-data-dir 已指向应用级 filesDir，
 *      两端对同一路径有共识（ApplicationContext.filesDir）。
 *
 * 时序保证：ArkTS 在浏览器组件启动前先写入状态文件，
 * 因此 Electron 主进程首次读到的就是「上次访问的 URL」。
 */

import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ShellConstants } from '../common/ShellConstants';

const TAG: string = 'ElectronShellBridge';
const DOMAIN: number = 0x0000;

interface ShellStatePayload {
  url: string;
  seq: number;
}

export class ElectronShellBridge {
  private static readonly INSTANCE: ElectronShellBridge = new ElectronShellBridge();
  private stateFilePath: string = '';
  private seq: number = 0;

  public static getInstance(): ElectronShellBridge {
    return ElectronShellBridge.INSTANCE;
  }

  /**
   * 绑定应用上下文并计算状态文件绝对路径，重复调用安全（幂等）。
   *
   * @param context 应用上下文
   */
  public init(context: Context): void {
    if (this.stateFilePath.length > 0) {
      return;
    }
    try {
      const filesDir: string = context.getApplicationContext().filesDir;
      this.stateFilePath = `${filesDir}/${ShellConstants.STATE_FILE_NAME}`;
      hilog.info(DOMAIN, TAG, 'state file: %{public}s', this.stateFilePath);
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'resolve state file failed, code=%{public}d, message=%{public}s',
        err.code, err.message);
    }
  }

  /**
   * 当前状态文件绝对路径，仅用于日志与排障。
   *
   * @returns 状态文件路径；未初始化时为空字符串
   */
  public getStateFilePath(): string {
    return this.stateFilePath;
  }

  /**
   * 发布一次导航请求：把 URL 与自增序号写入状态文件。
   *
   * @param url 规整后的 URL，空字符串表示「回到空页面」
   * @returns true 表示写入成功
   */
  public publish(url: string): boolean {
    if (this.stateFilePath.length === 0) {
      hilog.error(DOMAIN, TAG, 'publish skipped: bridge not initialized');
      return false;
    }
    this.seq += 1;
    const payload: ShellStatePayload = { url: url, seq: this.seq };
    const content: string = JSON.stringify(payload);
    let file: fileIo.File | undefined = undefined;
    try {
      file = fileIo.openSync(this.stateFilePath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, content);
      hilog.info(DOMAIN, TAG, 'published seq=%{public}d url=%{public}s', this.seq, url);
      return true;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'publish failed, code=%{public}d, message=%{public}s',
        err.code, err.message);
      return false;
    } finally {
      if (file !== undefined) {
        try {
          fileIo.closeSync(file);
        } catch (error) {
          const err = error as BusinessError;
          hilog.error(DOMAIN, TAG, 'close state file failed, code=%{public}d', err.code);
        }
      }
    }
  }
}
