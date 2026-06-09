import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import hilog from '@ohos.hilog';
import { window } from '@kit.ArkUI';
import { StorageService } from '../service/StorageService';
import { Logger } from '../utils/Logger';

const DOMAIN: number = 0xFF00;

/**
 * Main entry ability for the OpenCode HarmonyOS app.
 * Initializes storage, configures the window, and loads the main page.
 */
export default class EntryAbility extends UIAbility {
  storageService: StorageService | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'OpenCode', 'EntryAbility onCreate');
    this.storageService = new StorageService(this.context);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'OpenCode', 'EntryAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'OpenCode', 'EntryAbility onWindowStageCreate');

    // Configure the main window
    windowStage.getMainWindow((err, win) => {
      if (err.code) {
        Logger.error('Failed to get main window: %{public}s', JSON.stringify(err));
        return;
      }

      // Set up window for 2-in-1 (laptop) use
      win.setWindowLayoutFullScreen(false);

      // Set system bar colors
      const sysBarProps: window.SystemBarProperties = {
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: '#000000',
        navigationBarContentColor: '#000000'
      };
      win.setWindowSystemBarProperties(sysBarProps);

      // Keyboard avoidance is handled automatically in stage model
    });

    // Load the main page
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        Logger.error('Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'OpenCode', 'Content loaded successfully');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'OpenCode', 'EntryAbility onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'OpenCode', 'EntryAbility onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'OpenCode', 'EntryAbility onBackground');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'OpenCode', 'EntryAbility onNewWant');
  }
}
