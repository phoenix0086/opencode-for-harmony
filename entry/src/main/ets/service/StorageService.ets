import { preferences } from '@kit.ArkData';
import { Logger } from '../utils/Logger';
import { Constants } from '../utils/Constants';
import { common } from '@kit.AbilityKit';

/**
 * Persistent key-value storage backed by ArkPreferences.
 * Stores server configs, auth tokens, and user settings.
 */
export class StorageService {
  private store: preferences.Preferences | null = null;
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async init(): Promise<void> {
    try {
      this.store = await preferences.getPreferences(this.context, 'opencode_prefs');
      Logger.info('StorageService initialized');
    } catch (err) {
      Logger.error('StorageService init failed: ' + String(String(err)));
    }
  }

  async getString(key: string, defaultValue: string = ''): Promise<string> {
    if (!this.store) return defaultValue;
    try {
      const val = await this.store.get(key, defaultValue);
      return val as string;
    } catch (err) {
      Logger.error('StorageService getString error: ' + String(String(err)));
      return defaultValue;
    }
  }

  async setString(key: string, value: string): Promise<void> {
    if (!this.store) return;
    try {
      await this.store.put(key, value);
      await this.store.flush();
    } catch (err) {
      Logger.error('StorageService setString error: ' + String(String(err)));
    }
  }

  async getNumber(key: string, defaultValue: number = 0): Promise<number> {
    if (!this.store) return defaultValue;
    try {
      const val = await this.store.get(key, defaultValue);
      return val as number;
    } catch (err) {
      Logger.error('StorageService getNumber error: ' + String(String(err)));
      return defaultValue;
    }
  }

  async setNumber(key: string, value: number): Promise<void> {
    if (!this.store) return;
    try {
      await this.store.put(key, value);
      await this.store.flush();
    } catch (err) {
      Logger.error('StorageService setNumber error: ' + String(String(err)));
    }
  }

  async getBoolean(key: string, defaultValue: boolean = false): Promise<boolean> {
    if (!this.store) return defaultValue;
    try {
      const val = await this.store.get(key, defaultValue);
      return val as boolean;
    } catch (err) {
      Logger.error('StorageService getBoolean error: ' + String(String(err)));
      return defaultValue;
    }
  }

  async setBoolean(key: string, value: boolean): Promise<void> {
    if (!this.store) return;
    try {
      await this.store.put(key, value);
      await this.store.flush();
    } catch (err) {
      Logger.error('StorageService setBoolean error: ' + String(String(err)));
    }
  }

  async delete(key: string): Promise<void> {
    if (!this.store) return;
    try {
      await this.store.delete(key);
      await this.store.flush();
    } catch (err) {
      Logger.error('StorageService delete error: ' + String(String(err)));
    }
  }

  async clear(): Promise<void> {
    if (!this.store) return;
    try {
      await this.store.clear();
      await this.store.flush();
    } catch (err) {
      Logger.error('StorageService clear error: ' + String(String(err)));
    }
  }
}
