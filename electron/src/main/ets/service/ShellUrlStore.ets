/**
 * 最近访问 URL 的本地持久化。
 *
 * 使用 HarmonyOS 轻量键值存储（preferences）保存唯一一条记录：最后一次确认访问的 URL。
 * 采用同步接口，保证「启动时读取」与「确认时写入」在页面生命周期内是确定性的。
 */

import preferences from '@ohos.data.preferences';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ShellConstants } from '../common/ShellConstants';

const TAG: string = 'ShellUrlStore';
const DOMAIN: number = 0x0000;

export class ShellUrlStore {
  private static readonly INSTANCE: ShellUrlStore = new ShellUrlStore();
  private store: preferences.Preferences | undefined = undefined;

  public static getInstance(): ShellUrlStore {
    return ShellUrlStore.INSTANCE;
  }

  /**
   * 绑定应用上下文并打开偏好存储，重复调用安全（幂等）。
   *
   * @param context 应用上下文
   */
  public init(context: Context): void {
    if (this.store !== undefined) {
      return;
    }
    try {
      const options: preferences.Options = { name: ShellConstants.PREFERENCES_NAME };
      this.store = preferences.getPreferencesSync(context, options);
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'open preferences failed, code=%{public}d, message=%{public}s',
        err.code, err.message);
    }
  }

  /**
   * 读取本地保存的 URL。
   *
   * @returns 已保存的 URL；未保存或读取失败时返回空字符串
   */
  public getLastUrl(): string {
    if (this.store === undefined) {
      return '';
    }
    try {
      const value: preferences.ValueType = this.store.getSync(ShellConstants.KEY_LAST_URL, '');
      if (typeof value === 'string') {
        return value;
      }
      return '';
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'read last url failed, code=%{public}d, message=%{public}s',
        err.code, err.message);
      return '';
    }
  }

  /**
   * 保存 URL 到本地存储（覆盖写入并立即落盘）。
   *
   * @param url 规整后的 URL
   * @returns true 表示保存成功
   */
  public saveLastUrl(url: string): boolean {
    if (this.store === undefined) {
      return false;
    }
    try {
      this.store.putSync(ShellConstants.KEY_LAST_URL, url);
      this.store.flushSync();
      return true;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'save last url failed, code=%{public}d, message=%{public}s',
        err.code, err.message);
      return false;
    }
  }
}
