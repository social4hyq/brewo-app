import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import hilog from '@ohos.hilog';
import { BusinessError } from '@ohos.base';
import { APPEARANCE_STORAGE, Appearance, applyAppearance, loadAppearance } from '../theme/Appearance';
import { configureBrewHost } from '../data/BrewHost';

const TAG = 'Brewo';

export default class EntryAbility extends UIAbility {
  private appearance: Appearance = Appearance.System;

  onCreate(): void {
    configureBrewHost(this.context.filesDir);
    try {
      this.appearance = loadAppearance(this.context);
    } catch (error) {
      hilog.warn(0x0000, TAG, 'Could not read saved appearance');
    }
    AppStorage.setOrCreate(APPEARANCE_STORAGE, this.appearance);
    hilog.info(0x0000, TAG, 'Brewo onCreate');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, TAG, 'onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err: BusinessError) => {
      if (err.code) {
        hilog.error(0x0000, TAG, 'loadContent failed: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(0x0000, TAG, 'loadContent ok');
      try {
        applyAppearance(this.context, this.appearance);
      } catch (error) {
        AppStorage.setOrCreate(APPEARANCE_STORAGE, Appearance.System);
        hilog.warn(0x0000, TAG, 'Could not apply saved appearance');
      }

      // 横屏 PC 窗口：设置合理初始尺寸
      try {
        windowStage.getMainWindow((e: BusinessError, win: window.Window) => {
          if (!e.code) {
            win.setWindowLayoutFullScreen(false).catch(() => {});
          }
        });
      } catch (e) { /* ignore */ }
    });
  }

  onDestroy(): void {
    hilog.info(0x0000, TAG, 'onDestroy');
  }
}
