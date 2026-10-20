/**
 * URL 输入规整与校验。
 *
 * 职责单一：把用户输入转换为可加载的 Web URL，并判断其是否受支持。
 * 不涉及任何 UI 与存储逻辑，便于单独验证。
 */

import { ShellConstants } from './ShellConstants';

export class ShellUrlHelper {
  /**
   * 规整用户输入：
   * - 去首尾空白；
   * - 已带 scheme（形如 `https://`、`file://`）的原样返回；
   * - 否则补全 `https://`。
   *
   * @param rawInput 用户原始输入
   * @returns 规整后的 URL，输入为空时返回空字符串
   */
  public static normalize(rawInput: string): string {
    const text: string = rawInput.trim();
    if (text.length === 0) {
      return '';
    }
    const schemePattern: RegExp = new RegExp('^[a-zA-Z][a-zA-Z0-9+.\\-]*://');
    if (schemePattern.test(text)) {
      return text;
    }
    return ShellConstants.HTTPS_SCHEME + text;
  }

  /**
   * 判断规整后的 URL 是否为受支持的 Web 地址：
   *   - 仅接受 http / https；
   *   - 不允许空白字符；
   *   - 主机名必须是合法域名（或 localhost），可带 1~5 位端口。
   *
   * 该实现刻意不复用 `URL` 全局对象：部分输入（如 `https://a.comhttps://b.com`）
   * 会被宽松解析器接受，从而把非法地址送进浏览器组件。
   *
   * @param url 已规整的 URL
   * @returns true 表示可以交给浏览器组件加载
   */
  public static isSupported(url: string): boolean {
    const text: string = url.trim();
    if (text.length === 0) {
      return false;
    }
    if (new RegExp('\\s').test(text)) {
      return false;
    }

    const schemePattern: RegExp = new RegExp('^(https?):\\/\\/', 'i');
    const schemeMatch: RegExpMatchArray | null = text.match(schemePattern);
    if (schemeMatch === null) {
      return false;
    }

    const rest: string = text.substring(schemeMatch[0].length);
    let hostEnd: number = rest.length;
    for (let i = 0; i < rest.length; i++) {
      const ch: string = rest.charAt(i);
      if (ch === '/' || ch === '?' || ch === '#') {
        hostEnd = i;
        break;
      }
    }
    const hostPort: string = rest.substring(0, hostEnd);
    if (hostPort.length === 0) {
      return false;
    }

    let host: string = hostPort;
    const colonIndex: number = hostPort.lastIndexOf(':');
    if (colonIndex >= 0) {
      host = hostPort.substring(0, colonIndex);
      const port: string = hostPort.substring(colonIndex + 1);
      if (!new RegExp('^[0-9]{1,5}$').test(port)) {
        return false;
      }
    }

    if (host === 'localhost') {
      return true;
    }
    const hostPattern: RegExp =
      new RegExp('^[A-Za-z0-9]([A-Za-z0-9\\-]*[A-Za-z0-9])?(\\.[A-Za-z0-9]([A-Za-z0-9\\-]*[A-Za-z0-9])?)+$');
    return hostPattern.test(host);
  }

  /**
   * 判断 URL 是否为空（未设置任何访问目标）。
   *
   * @param url 待判断字符串
   * @returns true 表示为空
   */
  public static isEmpty(url: string): boolean {
    return url.trim().length === 0;
  }

  /**
   * 判断已保存的 URL 是否可以直接复用（启动恢复场景）。
   *
   * @param url 已保存的 URL
   * @returns true 表示可用
   */
  public static isRestorable(url: string): boolean {
    return !ShellUrlHelper.isEmpty(url) && ShellUrlHelper.isSupported(url.trim());
  }
}
