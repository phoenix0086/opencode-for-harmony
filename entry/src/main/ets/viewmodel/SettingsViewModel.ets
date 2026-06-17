import { StorageService } from '../services/StorageService';
import { Constants } from '../utils/Constants';
import { Logger } from '../utils/Logger';

/**
 * View model for the settings page.
 * Manages user preferences persistence and theme configuration.
 */
export class SettingsViewModel {
  serverUrl: string = Constants.DEFAULT_SERVER_URL;
  username: string = '';
  password: string = '';
  model: string = Constants.DEFAULT_MODEL;
  theme: string = Constants.DEFAULT_THEME;
  language: string = Constants.DEFAULT_LANGUAGE;

  private storage: StorageService | null = null;

  async load(storage: StorageService): Promise<void> {
    this.storage = storage;
    this.serverUrl = await storage.getString(Constants.KEY_SERVER_URL, Constants.DEFAULT_SERVER_URL);
    this.username = await storage.getString(Constants.KEY_AUTH_USERNAME, '');
    this.password = await storage.getString(Constants.KEY_AUTH_PASSWORD, '');
    this.model = await storage.getString(Constants.KEY_MODEL, Constants.DEFAULT_MODEL);
    this.theme = await storage.getString(Constants.KEY_THEME, Constants.DEFAULT_THEME);
    this.language = await storage.getString(Constants.KEY_LANGUAGE, Constants.DEFAULT_LANGUAGE);
    Logger.info('SettingsViewModel loaded');
  }

  async save(): Promise<void> {
    if (!this.storage) return;
    await this.storage.setString(Constants.KEY_SERVER_URL, this.serverUrl);
    await this.storage.setString(Constants.KEY_AUTH_USERNAME, this.username);
    await this.storage.setString(Constants.KEY_AUTH_PASSWORD, this.password);
    await this.storage.setString(Constants.KEY_MODEL, this.model);
    await this.storage.setString(Constants.KEY_THEME, this.theme);
    await this.storage.setString(Constants.KEY_LANGUAGE, this.language);
    Logger.info('SettingsViewModel saved');
  }

  async reset(): Promise<void> {
    this.serverUrl = Constants.DEFAULT_SERVER_URL;
    this.username = '';
    this.password = '';
    this.model = Constants.DEFAULT_MODEL;
    this.theme = Constants.DEFAULT_THEME;
    this.language = Constants.DEFAULT_LANGUAGE;
    await this.save();
    Logger.info('SettingsViewModel reset to defaults');
  }
}
