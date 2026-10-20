/**
 * ShellUrlHelper 单元测试（hypium）。
 *
 * 覆盖 URL 规整与校验的边界：协议补全、非法拼接、端口范围、localhost、IPv4/IPv6、
 * 大小写、结尾点、超长、路径带空格等。
 *
 * 运行方式（需连接设备）：
 *   hvigorw assembleHap -p product=default --mode module -p buildMode=debug
 *   hvigorw onDeviceTest -p product=default
 * 或在 DevEco Studio 中右键本文件运行。
 */

import { describe, it, expect } from '@ohos/hypium';
import { ShellUrlHelper } from '../main/ets/common/ShellUrlHelper';

export default function shellUrlHelperTest() {
  describe('ShellUrlHelper', () => {
    it('normalize_adds_https_when_scheme_missing', 0, () => {
      expect(ShellUrlHelper.normalize('www.baidu.com')).assertEqual('https://www.baidu.com');
    });

    it('normalize_keeps_existing_scheme', 0, () => {
      expect(ShellUrlHelper.normalize('http://a.com/x')).assertEqual('http://a.com/x');
      expect(ShellUrlHelper.normalize('  https://a.com  ')).assertEqual('https://a.com');
    });

    it('normalize_empty_returns_empty', 0, () => {
      expect(ShellUrlHelper.normalize('   ')).assertEqual('');
    });

    it('isSupported_accepts_normal_urls', 0, () => {
      expect(ShellUrlHelper.isSupported('https://www.baidu.com')).assertTrue();
      expect(ShellUrlHelper.isSupported('http://a.com/path?x=1#y')).assertTrue();
      expect(ShellUrlHelper.isSupported('https://a.com:8080/')).assertTrue();
      expect(ShellUrlHelper.isSupported('https://a.com.')).assertTrue();
      expect(ShellUrlHelper.isSupported('HTTP://A.COM')).assertTrue();
    });

    it('isSupported_accepts_localhost_and_ip', 0, () => {
      expect(ShellUrlHelper.isSupported('http://localhost')).assertTrue();
      expect(ShellUrlHelper.isSupported('http://LOCALHOST:8080')).assertTrue();
      expect(ShellUrlHelper.isSupported('http://192.168.1.10')).assertTrue();
      expect(ShellUrlHelper.isSupported('http://[::1]:8080/')).assertTrue();
    });

    it('isSupported_rejects_concatenated_urls', 0, () => {
      expect(ShellUrlHelper.isSupported('https://a.comhttps://b.com')).assertFalse();
      expect(ShellUrlHelper.isSupported('https://threejs.orghttps://www.bing.com')).assertFalse();
    });

    it('isSupported_rejects_bad_port', 0, () => {
      expect(ShellUrlHelper.isSupported('https://a.com:0')).assertFalse();
      expect(ShellUrlHelper.isSupported('https://a.com:65536')).assertFalse();
      expect(ShellUrlHelper.isSupported('https://a.com:99999')).assertFalse();
      expect(ShellUrlHelper.isSupported('https://a.com:abc')).assertFalse();
    });

    it('isSupported_rejects_bad_scheme_or_host', 0, () => {
      expect(ShellUrlHelper.isSupported('file:///tmp/a.html')).assertFalse();
      expect(ShellUrlHelper.isSupported('ftp://a.com')).assertFalse();
      expect(ShellUrlHelper.isSupported('https://')).assertFalse();
      expect(ShellUrlHelper.isSupported('https://-bad.com')).assertFalse();
      expect(ShellUrlHelper.isSupported('https://a..com')).assertFalse();
      expect(ShellUrlHelper.isSupported('https://a b.com')).assertFalse();
    });

    it('isSupported_rejects_ipv4_out_of_range', 0, () => {
      expect(ShellUrlHelper.isSupported('http://256.1.1.1')).assertFalse();
      expect(ShellUrlHelper.isSupported('http://1.1.1.999')).assertFalse();
    });

    it('isSupported_rejects_overlong_url', 0, () => {
      const longHost: string = 'a'.repeat(2000) + '.com';
      expect(ShellUrlHelper.isSupported(`https://${longHost}`)).assertFalse();
    });

    it('isSupported_accepts_space_in_path', 0, () => {
      expect(ShellUrlHelper.isSupported('https://a.com/a b')).assertTrue();
    });

    it('isRestorable_requires_valid_url', 0, () => {
      expect(ShellUrlHelper.isRestorable('https://www.baidu.com')).assertTrue();
      expect(ShellUrlHelper.isRestorable('')).assertFalse();
      expect(ShellUrlHelper.isRestorable('https://a.comhttps://b.com')).assertFalse();
    });
  });
}
