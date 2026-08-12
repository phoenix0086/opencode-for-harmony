import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import hilog from '@ohos.hilog';
import { window } from '@kit.ArkUI';
import { Logger } from '../utils/Logger';
import { errStr } from '../utils/ErrorUtil';

const DOMAIN: number = 0xFF00;

/**
 * Main entry ability for the OpenCode HarmonyOS app.
 * Initializes the app context, configures the window, and loads the main page.
 *
 * Storage is initialized lazily by Index.aboutToAppear via initStorageService(),
 * not here — to avoid creating a third StorageService instance that holds a
 * stale in-memory copy of preferences.
 */
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'OpenCode', 'EntryAbility onCreate');
    // Store context in AppStorage so pages can access it without deprecated getContext()
    AppStorage.setOrCreate<Context>('appContext', this.context);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'OpenCode', 'EntryAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'OpenCode', 'EntryAbility onWindowStageCreate');

    // Configure the main window
    windowStage.getMainWindow((err, win) => {
      if (err.code) {
        Logger.error('Failed to get main window: ' + String(JSON.stringify(err)));
        return;
      }

      // Set up window for 2-in-1 (laptop) use
      win.setWindowLayoutFullScreen(false);

      // Follow the device sensor in both portrait and landscape. AUTO_ROTATION
      // intentionally ignores the system rotation lock, so the phone client
      // remains rotatable even when the quick-setting toggle is disabled.
      win.setPreferredOrientation(window.Orientation.AUTO_ROTATION)
        .then(() => {
          Logger.info('Window orientation set to AUTO_ROTATION');
        })
        .catch((orientationError: Object) => {
          Logger.warn(`Failed to enable auto rotation: ${errStr(orientationError)}`);
        });

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
        Logger.error('Failed to load content: ' + String(JSON.stringify(err)));
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
