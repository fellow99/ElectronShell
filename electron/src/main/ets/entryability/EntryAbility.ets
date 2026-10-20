// Copyright (c) 2024 Huawei Device Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import window from '@ohos.window';
import Want from '@ohos.app.ability.Want';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import { Configuration } from '@ohos.app.ability.Configuration';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { WebAbility } from 'web_engine';
import { ShellUrlHelper } from '../common/ShellUrlHelper';
import { ShellUrlStore } from '../service/ShellUrlStore';
import { ElectronShellBridge } from '../service/ElectronShellBridge';

const TAG: string = 'EntryAbility';
const DOMAIN: number = 0x0000;
/** 框架在 loadContent 回调里会重新显示平板状态栏，延时后再兜底一次沉浸式设置 */
const IMMERSIVE_REAPPLY_DELAY_MS: number = 600;

/**
 * 应用入口 Ability。
 *
 * 在 web_engine 的 WebAbility 之上做两件事：
 *   1. 启动时把「上次访问的 URL」写进状态文件——必须在浏览器内核启动之前完成，
 *      保证内核首帧读到的是最新状态而不是上一次会话的残留；
 *   2. 把宿主窗口切到沉浸式全屏，让 Electron 浏览器内容真正铺满屏幕
 *      （覆盖系统状态栏与底部导航条）。
 */
export default class EntryAbility extends WebAbility {
  onConfigurationUpdate(config: Configuration) {
    super.onConfigurationUpdate(config);
    // 横竖屏 / 窗口模式切换后系统栏可能复现，重新应用一次
    this.applyImmersiveFullScreen();
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    super.onCreate(want, launchParam);
    this.publishInitialUrl();
  }

  onDestroy() {
    super.onDestroy();
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    super.onWindowStageCreate(windowStage);
    this.applyImmersiveFullScreen();
    // loadContent 的回调里框架可能重新显示平板状态栏，延时兜底
    setTimeout(() => this.applyImmersiveFullScreen(), IMMERSIVE_REAPPLY_DELAY_MS);
  }

  onWindowStageDestroy() {
    super.onWindowStageDestroy();
  }

  onForeground() {
    super.onForeground();
    this.applyImmersiveFullScreen();
  }

  onBackground() {
    super.onBackground();
  }

  /**
   * 启动时发布初始导航状态。
   *
   * 时序意义：`onCreate` 早于 `onWindowStageCreate`（内核在此之后启动），
   * 因此状态文件在内核读取之前就已就绪，不依赖轮询「补上」。
   */
  private publishInitialUrl(): void {
    try {
      const store: ShellUrlStore = ShellUrlStore.getInstance();
      const bridge: ElectronShellBridge = ElectronShellBridge.getInstance();
      store.init(this.context);
      bridge.init(this.context);

      const lastUrl: string = store.getLastUrl();
      if (ShellUrlHelper.isRestorable(lastUrl)) {
        const target: string = lastUrl.trim();
        bridge.publish(target);
        return;
      }
      // 历史值缺失或非法：显式回到空页面，并清理脏值
      bridge.publish('');
      if (lastUrl.length > 0) {
        hilog.warn(DOMAIN, TAG, 'discard invalid stored url: %{public}s', lastUrl);
        store.saveLastUrl('');
      }
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'publishInitialUrl failed, code=%{public}d, message=%{public}s',
        err.code, err.message);
    }
  }

  /**
   * 沉浸式全屏：
   *   1. 布局延伸到状态栏与导航条区域（setWindowLayoutFullScreen）；
   *   2. 隐藏状态栏与底部导航条（setSpecificSystemBarEnabled）；
   *   3. 2in1 / PC 形态下最大化并进入沉浸式，隐藏标题栏和 Dock 悬浮。
   *
   * 设备形态不同（手机 / 平板 / 2in1 / TV），部分能力可能不存在，
   * 因此每一步独立 try-catch，失败只记录日志，不影响浏览器主体功能。
   */
  private applyImmersiveFullScreen(): void {
    const mainWindow: window.Window | undefined = this.getWindow();
    if (mainWindow === undefined) {
      hilog.warn(DOMAIN, TAG, 'main window unavailable, skip immersive setup');
      return;
    }

    // 复用框架能力：内部会设置 layoutFullScreen 并隐藏导航条 / 状态栏
    try {
      this.updateAvoidAreaStatus(true);
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'updateAvoidAreaStatus failed, code=%{public}d, message=%{public}s',
        err.code, err.message);
    }

    try {
      mainWindow.setWindowLayoutFullScreen(true).catch((err: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'setWindowLayoutFullScreen failed, code=%{public}d', err.code);
      });
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'setWindowLayoutFullScreen threw, code=%{public}d', err.code);
    }

    try {
      mainWindow.setSpecificSystemBarEnabled('status', false).catch((err: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'hide status bar failed, code=%{public}d', err.code);
      });
      mainWindow.setSpecificSystemBarEnabled('navigationIndicator', false).catch((err: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'hide navigation indicator failed, code=%{public}d', err.code);
      });
    } catch (error) {
      const err = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'setSpecificSystemBarEnabled threw, code=%{public}d', err.code);
    }

    // 仅 2in1 / PC 形态需要最大化，手机与 TV 上调用会稳定失败并产生噪声日志
    if (deviceInfo.deviceType === '2in1') {
      try {
        mainWindow.maximize(window.MaximizePresentation.ENTER_IMMERSIVE_DISABLE_TITLE_AND_DOCK_HOVER)
          .catch((err: BusinessError) => {
            hilog.warn(DOMAIN, TAG, 'maximize failed, code=%{public}d, message=%{public}s',
              err.code, err.message);
          });
      } catch (error) {
        const err = error as BusinessError;
        hilog.warn(DOMAIN, TAG, 'maximize threw, code=%{public}d', err.code);
      }
    }
  }
};
