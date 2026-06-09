/**
 * Application-wide constants.
 */
export class Constants {
  // App
  static readonly APP_NAME: string = 'OpenCode';
  static readonly BUNDLE_NAME: string = 'ai.opencode.harmony';
  static readonly VERSION: string = '1.0.0';

  // Storage keys
  static readonly KEY_SERVER_URL: string = 'server_url';
  static readonly KEY_API_KEY: string = 'api_key';
  static readonly KEY_MODEL: string = 'model';
  static readonly KEY_THEME: string = 'theme';
  static readonly KEY_LANGUAGE: string = 'language';
  static readonly KEY_SESSION_ID: string = 'session_id';
  static readonly KEY_AUTH_USERNAME: string = 'auth_username';
  static readonly KEY_AUTH_PASSWORD: string = 'auth_password';

  // Defaults
  static readonly DEFAULT_SERVER_URL: string = 'http://localhost:3000';
  static readonly DEFAULT_MODEL: string = 'anthropic/claude-sonnet-4-20250514';
  static readonly DEFAULT_THEME: string = 'system';
  static readonly DEFAULT_LANGUAGE: string = 'zh_CN';

  // Network
  static readonly HTTP_TIMEOUT_MS: number = 30000;
  static readonly WS_RECONNECT_INTERVAL_MS: number = 3000;
  static readonly WS_MAX_RECONNECT_ATTEMPTS: number = 10;
  static readonly HEALTH_CHECK_INTERVAL_MS: number = 10000;

  // UI
  static readonly SIDEBAR_WIDTH: number = 240;
  static readonly TITLE_BAR_HEIGHT: number = 48;
  static readonly STATUS_BAR_HEIGHT: number = 32;
  static readonly MAX_MESSAGE_LENGTH: number = 32000;

  // API paths
  static readonly API_HEALTH: string = '/global/health';
  static readonly API_SESSION: string = '/session';
  static readonly API_MESSAGE: string = '/message';
  static readonly API_CONFIG: string = '/config';
  static readonly API_PROVIDER: string = '/provider';
  static readonly API_FILE: string = '/file';
  static readonly API_WORKTREE: string = '/worktree';

  // Themes
  static readonly THEME_SYSTEM: string = 'system';
  static readonly THEME_LIGHT: string = 'light';
  static readonly THEME_DARK: string = 'dark';
}
