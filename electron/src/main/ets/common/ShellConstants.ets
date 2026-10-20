/**
 * ElectronShell 常量定义。
 *
 * 集中放置偏好存储键名、状态文件名称与 URL 前缀，避免魔法字符串散落在各模块。
 */

export class ShellConstants {
  /** 偏好存储（preferences）实例名，用于持久化最近一次访问的 URL */
  public static readonly PREFERENCES_NAME: string = 'electron_shell_store';

  /** 偏好存储中最近一次访问 URL 的键 */
  public static readonly KEY_LAST_URL: string = 'last_url';

  /** ArkTS 与 Electron 主进程之间共享的状态文件名 */
  public static readonly STATE_FILE_NAME: string = 'electron-shell-state.json';

  /** 默认补全的协议前缀 */
  public static readonly HTTPS_SCHEME: string = 'https://';

  /** 紧凑布局断点（vp）：小于该宽度视为竖屏手机等紧凑场景 */
  public static readonly BREAKPOINT_COMPACT: number = 600;

  /** 宽屏断点（vp）：大于等于该宽度使用更宽输入面板 */
  public static readonly BREAKPOINT_WIDE: number = 840;
}
