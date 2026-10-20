/**
 * 浏览器壳前端界面：左下角浮动按钮 + 底部 URL 输入面板。
 *
 * 设计约束：
 *   - 本组件是覆盖在 Electron 浏览器内容之上的「薄」控制层，
 *     本身不拦截空白区域的触摸（HitTestMode.Transparent），保证网页仍可正常交互；
 *   - 所有导航请求都交给 Electron 主进程处理（见 ElectronShellBridge），
 *     ArkTS 侧只负责「取输入、做规整、落本地存储、发请求」；
 *   - 布局按 vp 宽度分为紧凑（手机竖屏）/ 常规（平板）/ 宽屏（2in1、TV）三档，
 *     并对 windowSizeChange 作出响应，因此横竖屏切换会自动重排。
 */

import window from '@ohos.window';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ShellConstants } from '../common/ShellConstants';
import { ShellUrlHelper } from '../common/ShellUrlHelper';
import { ShellUrlStore } from '../service/ShellUrlStore';
import { ElectronShellBridge } from '../service/ElectronShellBridge';

const TAG: string = 'ShellOverlay';
const DOMAIN: number = 0x0000;
const INPUT_ID: string = 'shellUrlInput';

@Component
export struct ShellOverlay {
  @State private urlText: string = '';
  @State private editorVisible: boolean = false;
  @State private errorText: string = '';
  @State private compact: boolean = false;
  @State private panelWidth: string = '68%';
  private urlStore: ShellUrlStore = ShellUrlStore.getInstance();
  private bridge: ElectronShellBridge = ElectronShellBridge.getInstance();
  private hostWindow: window.Window | undefined = undefined;
  private sizeListener: Callback<window.Size> | undefined = undefined;

  aboutToAppear(): void {
    const context: Context = getContext(this);
    this.urlStore.init(context);
    this.bridge.init(context);

    const lastUrl: string = this.urlStore.getLastUrl();
    if (ShellUrlHelper.isRestorable(lastUrl)) {
      // 本地有可用 URL：预填输入框并立即让浏览器组件加载
      this.urlText = lastUrl;
      this.bridge.publish(lastUrl);
    } else {
      // 本地无 URL（或上次保存的值已非法）：浏览器组件展示空页面，同时展开底部输入框
      this.editorVisible = true;
      this.bridge.publish('');
    }
    this.attachSizeListener();
  }

  aboutToDisappear(): void {
    this.detachSizeListener();
  }

  /** 监听窗口尺寸变化，驱动紧凑 / 常规 / 宽屏三档响应式布局 */
  private attachSizeListener(): void {
    window.getLastWindow(getContext(this)).then((win: window.Window) => {
      this.hostWindow = win;
      this.applyWidth(win.getWindowProperties().windowRect.width);
      this.sizeListener = (size: window.Size): void => {
        this.applyWidth(size.width);
      };
      try {
        win.on('windowSizeChange', this.sizeListener);
      } catch (error) {
        const err = error as BusinessError;
        hilog.error(DOMAIN, TAG, 'register windowSizeChange failed, code=%{public}d', err.code);
      }
    }).catch((error: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'getLastWindow failed, code=%{public}d, message=%{public}s',
        error.code, error.message);
    });
  }

  private detachSizeListener(): void {
    if (this.hostWindow === undefined || this.sizeListener === undefined) {
      return;
    }
    try {
      this.hostWindow.off('windowSizeChange', this.sizeListener);
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'unregister windowSizeChange failed, code=%{public}d', err.code);
    }
    this.sizeListener = undefined;
    this.hostWindow = undefined;
  }

  private applyWidth(widthPx: number): void {
    if (widthPx <= 0) {
      return;
    }
    const widthVp: number = this.getUIContext().px2vp(widthPx);
    this.compact = widthVp < ShellConstants.BREAKPOINT_COMPACT;
    if (widthVp < ShellConstants.BREAKPOINT_COMPACT) {
      this.panelWidth = '92%';
    } else if (widthVp < ShellConstants.BREAKPOINT_WIDE) {
      this.panelWidth = '68%';
    } else {
      this.panelWidth = '46%';
    }
  }

  /** 展开输入面板 */
  private openEditor(): void {
    this.errorText = '';
    this.editorVisible = true;
  }

  /** 收起输入面板（不改变已保存的 URL） */
  private closeEditor(): void {
    this.errorText = '';
    this.editorVisible = false;
  }

  /** 确认输入：规整 -> 校验 -> 持久化 -> 通知 Electron -> 收起面板 */
  private submit(): void {
    const url: string = ShellUrlHelper.normalize(this.urlText);
    if (!ShellUrlHelper.isSupported(url)) {
      this.errorText = '请输入有效网址，例如 www.baidu.com';
      return;
    }
    this.errorText = '';
    this.urlText = url;
    this.urlStore.saveLastUrl(url);
    this.bridge.publish(url);
    this.editorVisible = false;
  }

  build() {
    Column() {
      if (!this.editorVisible) {
        this.FloatingButton()
      }
      if (this.editorVisible) {
        this.UrlPanel()
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End)
    .hitTestBehavior(HitTestMode.Transparent)
  }

  /** 左下角浮动入口按钮 */
  @Builder
  FloatingButton() {
    Stack() {
      Text('URL')
        .fontSize(this.compact ? 10 : 11)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .letterSpacing(0.6)
    }
    .width(this.compact ? 46 : 52)
    .height(this.compact ? 46 : 52)
    .borderRadius(this.compact ? 23 : 26)
    .linearGradient({
      angle: 135,
      colors: [['#FF4A7BF7', 0.0], ['#FF2A55D6', 1.0]]
    })
    .shadow({ radius: 18, color: '#400A3FA8', offsetX: 0, offsetY: 6 })
    .margin({ left: this.compact ? 16 : 24, bottom: this.compact ? 18 : 24 })
    .alignSelf(ItemAlign.Start)
    .onClick(() => this.openEditor())
  }

  /** 底部 URL 输入面板 */
  @Builder
  UrlPanel() {
    Row() {
      Column({ space: this.compact ? 6 : 8 }) {
        Row({ space: this.compact ? 8 : 10 }) {
          TextInput({ text: this.urlText, placeholder: '输入网址，如 www.baidu.com' })
            .id(INPUT_ID)
            .layoutWeight(1)
            .height(this.compact ? 38 : 40)
            .fontSize(this.compact ? 14 : 15)
            .fontColor('#FF1A1D22')
            .backgroundColor(Color.Transparent)
            .placeholderColor('#B3B9C0')
            .caretColor('#FF2A55D6')
            .enterKeyType(EnterKeyType.Go)
            .maxLines(1)
            .defaultFocus(true)
            .onChange((value: string) => {
              this.urlText = value;
              this.errorText = '';
            })
            .onSubmit(() => this.submit())

          Button('前往')
            .type(ButtonType.Capsule)
            .height(this.compact ? 32 : 34)
            .padding({ left: this.compact ? 12 : 16, right: this.compact ? 12 : 16 })
            .fontSize(this.compact ? 13 : 14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .backgroundColor('#FF2A55D6')
            .onClick(() => this.submit())

          Text('✕')
            .fontSize(this.compact ? 15 : 16)
            .fontColor('#8A9099')
            .padding(6)
            .onClick(() => this.closeEditor())
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.errorText.length > 0) {
          Text(this.errorText)
            .fontSize(12)
            .fontColor('#FFE84026')
            .width('100%')
            .textAlign(TextAlign.Start)
        }
      }
      .width(this.panelWidth)
      .constraintSize({ maxWidth: 760 })
      .padding({
        left: this.compact ? 12 : 16,
        right: this.compact ? 8 : 12,
        top: this.compact ? 8 : 10,
        bottom: this.compact ? 8 : 10
      })
      .borderRadius(this.compact ? 20 : 22)
      .backgroundColor('#F7FFFFFF')
      .border({ width: 1, color: '#18000000' })
      .shadow({ radius: 24, color: '#26000000', offsetX: 0, offsetY: 8 })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({
      left: this.compact ? 8 : 16,
      right: this.compact ? 8 : 16,
      bottom: this.compact ? 14 : 20
    })
    .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 24 })))
  }
}
