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
   *   - 长度不超过 2048；
   *   - authority（域名 + 可选端口）不得包含空白；
   *   - 主机名支持域名、localhost（大小写不敏感）、IPv4、方括号 IPv6；端口范围 1~65535。
   *
   * 该实现刻意不复用 `URL` 全局对象：宽松解析器会接受
   * `https://a.comhttps://b.com` 这类拼接串，把非法地址送进浏览器组件。
   *
   * @param url 已规整的 URL
   * @returns true 表示可以交给浏览器组件加载
   */
  public static isSupported(url: string): boolean {
    const text: string = url.trim();
    if (text.length === 0 || text.length > 2048) {
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
    let authority: string = rest.substring(0, hostEnd);
    if (authority.length === 0 || new RegExp('\\s').test(authority)) {
      return false;
    }

    // 去掉 userinfo（user:pass@host）
    const atIndex: number = authority.lastIndexOf('@');
    if (atIndex >= 0) {
      authority = authority.substring(atIndex + 1);
    }
    if (authority.length === 0) {
      return false;
    }

    // 方括号 IPv6：[::1] 或 [::1]:8080
    if (authority.charAt(0) === '[') {
      const closeIndex: number = authority.indexOf(']');
      if (closeIndex < 0) {
        return false;
      }
      const ipv6: string = authority.substring(1, closeIndex);
      if (!new RegExp('^[0-9A-Fa-f:.]+$').test(ipv6) || ipv6.indexOf(':') < 0) {
        return false;
      }
      const after: string = authority.substring(closeIndex + 1);
      if (after.length === 0) {
        return true;
      }
      if (after.charAt(0) !== ':') {
        return false;
      }
      return ShellUrlHelper.isValidPort(after.substring(1));
    }

    let host: string = authority;
    const colonIndex: number = authority.lastIndexOf(':');
    if (colonIndex >= 0) {
      host = authority.substring(0, colonIndex);
      if (!ShellUrlHelper.isValidPort(authority.substring(colonIndex + 1))) {
        return false;
      }
    }

    // 允许结尾的点（FQDN 写法）
    if (host.length > 1 && host.charAt(host.length - 1) === '.') {
      host = host.substring(0, host.length - 1);
    }
    const lowerHost: string = host.toLowerCase();
    if (lowerHost === 'localhost') {
      return true;
    }
    if (new RegExp('^[0-9]{1,3}(\\.[0-9]{1,3}){3}$').test(lowerHost)) {
      return ShellUrlHelper.isValidIpv4(lowerHost);
    }
    const hostPattern: RegExp =
      new RegExp('^[a-z0-9]([a-z0-9\\-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9\\-]*[a-z0-9])?)+$');
    return hostPattern.test(lowerHost);
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

  /**
   * 端口合法性：1~65535 的十进制整数。
   *
   * @param port 端口字符串
   * @returns true 表示合法
   */
  private static isValidPort(port: string): boolean {
    if (!new RegExp('^[0-9]{1,5}$').test(port)) {
      return false;
    }
    const value: number = Number.parseInt(port, 10);
    return value >= 1 && value <= 65535;
  }

  /**
   * IPv4 每段取值 0~255。
   *
   * @param ip 形如 `192.168.1.1` 的字符串
   * @returns true 表示合法
   */
  private static isValidIpv4(ip: string): boolean {
    const parts: string[] = ip.split('.');
    if (parts.length !== 4) {
      return false;
    }
    for (let i = 0; i < parts.length; i++) {
      const value: number = Number.parseInt(parts[i], 10);
      if (Number.isNaN(value) || value < 0 || value > 255) {
        return false;
      }
    }
    return true;
  }
}
