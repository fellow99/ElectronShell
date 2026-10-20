// Copyright (c) 2024 Huawei Device Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import window from '@ohos.window';
import Want from '@ohos.app.ability.Want';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import { Configuration } from '@ohos.app.ability.Configuration';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { WebAbility } from 'web_engine';

const TAG: string = 'EntryAbility';
const DOMAIN: number = 0x0000;

/**
 * 应用入口 Ability。
 *
 * 在 web_engine 的 WebAbility 之上只做一件事：把宿主窗口切到沉浸式全屏，
 * 让 Electron 浏览器内容真正铺满屏幕（覆盖系统状态栏与底部导航条）。
 */
export default class EntryAbility extends WebAbility {
  onConfigurationUpdate(config: Configuration) {
    super.onConfigurationUpdate(config);
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    super.onCreate(want, launchParam);
  }

  onDestroy() {
    super.onDestroy();
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    super.onWindowStageCreate(windowStage);
    this.applyImmersiveFullScreen();
  }

  onWindowStageDestroy() {
    super.onWindowStageDestroy();
  }

  onForeground() {
    super.onForeground();
  }

  onBackground() {
    super.onBackground();
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
};
