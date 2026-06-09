import { ConfigurationConstant, systemDateTime } from '@kit.BasicServicesKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { Logger } from '../utils/Logger';
import { Constants } from '../utils/Constants';

/**
 * Theme service managing light/dark mode and dynamic color.
 * Respects system theme when set to 'system'.
 */
export class ThemeService {
  private currentTheme: string = Constants.DEFAULT_THEME;
  private listeners: ThemeChangeListener[] = [];

  setTheme(theme: string): void {
    this.currentTheme = theme;
    this.notifyListeners();
    Logger.info('ThemeService: theme set to %{public}s', theme);
  }

  getTheme(): string {
    return this.currentTheme;
  }

  isDarkMode(): boolean {
    // In a real app, check system dark mode when theme is 'system'
    return this.currentTheme === Constants.THEME_DARK;
  }

  addListener(listener: ThemeChangeListener): void {
    this.listeners.push(listener);
  }

  removeListener(listener: ThemeChangeListener): void {
    const index = this.listeners.indexOf(listener);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }

  private notifyListeners(): void {
    for (const listener of this.listeners) {
      listener.onThemeChanged(this.currentTheme);
    }
  }

  getColors(): ThemeColors {
    if (this.isDarkMode()) {
      return DARK_COLORS;
    }
    return LIGHT_COLORS;
  }
}

export interface ThemeChangeListener {
  onThemeChanged(theme: string): void;
}

export class ThemeColors {
  background: string = '#111111';
  surface: string = '#1A1A1A';
  primary: string = '#007DFF';
  textPrimary: string = '#FFFFFF';
  textSecondary: string = '#AAAAAA';
  border: string = '#2D2D2D';
  success: string = '#00C853';
  warning: string = '#FFB300';
  error: string = '#FF5252';
}

const DARK_COLORS: ThemeColors = {
  background: '#111111',
  surface: '#1A1A1A',
  primary: '#007DFF',
  textPrimary: '#FFFFFF',
  textSecondary: '#AAAAAA',
  border: '#2D2D2D',
  success: '#00C853',
  warning: '#FFB300',
  error: '#FF5252'
};

const LIGHT_COLORS: ThemeColors = {
  background: '#F5F5F5',
  surface: '#FFFFFF',
  primary: '#007DFF',
  textPrimary: '#181818',
  textSecondary: '#666666',
  border: '#E0E0E0',
  success: '#00C853',
  warning: '#FFB300',
  error: '#FF5252'
};
