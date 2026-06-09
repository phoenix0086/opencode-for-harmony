/**
 * Application-wide constants.
 */
export class Constants {
  static readonly APP_NAME: string = 'OpenCode';
  static readonly BUNDLE_NAME: string = 'ai.opencode.harmony';
  static readonly VERSION: string = '1.0.0';

  static readonly KEY_SERVER_URL: string = 'server_url';
  static readonly KEY_API_KEY: string = 'api_key';
  static readonly KEY_MODEL: string = 'model';
  static readonly KEY_THEME: string = 'theme';
  static readonly KEY_LANGUAGE: string = 'language';
  static readonly KEY_SESSION_ID: string = 'session_id';
  static readonly KEY_AUTH_USERNAME: string = 'auth_username';
  static readonly KEY_AUTH_PASSWORD: string = 'auth_password';

  // OpenCode Runtime default is 4096.
  static readonly DEFAULT_SERVER_URL: string = 'http://127.0.0.1:4096';
  static readonly DEFAULT_MODEL: string = '';
  static readonly DEFAULT_THEME: string = 'system';
  static readonly DEFAULT_LANGUAGE: string = 'zh_CN';

  static readonly HTTP_TIMEOUT_MS: number = 30000;
  static readonly POLL_INTERVAL_MS: number = 1000;
  static readonly POLL_MAX_ATTEMPTS: number = 120;
  static readonly HEALTH_CHECK_INTERVAL_MS: number = 10000;

  static readonly SIDEBAR_WIDTH: number = 240;
  static readonly TITLE_BAR_HEIGHT: number = 48;
  static readonly STATUS_BAR_HEIGHT: number = 32;
  static readonly MAX_MESSAGE_LENGTH: number = 32000;

  static readonly API_HEALTH: string = '/global/health';
  static readonly API_SESSION: string = '/session';
  static readonly API_CONFIG: string = '/config';
  static readonly API_PROVIDER: string = '/provider';
  static readonly API_FILE: string = '/file';
  static readonly API_WORKTREE: string = '/worktree';
  static readonly API_VCS: string = '/vcs';

  static sessionMessages(sessionId: string): string {
    return `/session/${sessionId}/message`;
  }

  static sessionPromptAsync(sessionId: string): string {
    return `/session/${sessionId}/prompt_async`;
  }

  static sessionAbort(sessionId: string): string {
    return `/session/${sessionId}/abort`;
  }

  static fileContent(path: string): string {
    return `/file/content?path=${encodeURIComponent(path)}`;
  }

  static vcsDiff(mode: string = 'git'): string {
    return `/vcs/diff?mode=${mode}`;
  }

  static readonly THEME_SYSTEM: string = 'system';
  static readonly THEME_LIGHT: string = 'light';
  static readonly THEME_DARK: string = 'dark';
}
  static readonly WS_RECONNECT_INTERVAL_MS: number = 3000;
  static readonly WS_MAX_RECONNECT_ATTEMPTS: number = 10;
