import { ServerInfo } from './ServerInfo';
import { ChatMessage } from './ChatMessage';

/**
 * Global application state managed as an observable singleton.
 * Uses @Observed pattern for reactive UI updates.
 */

export enum ConnectionStatus {
  Disconnected = 'disconnected',
  Connecting = 'connecting',
  Connected = 'connected',
  Error = 'error'
}

export enum AppView {
  Home = 'home',
  Chat = 'chat',
  Files = 'files',
  Terminal = 'terminal',
  Settings = 'settings',
  WebView = 'webview'
}

export class SessionInfo {
  id: string = '';
  title: string = '';
  createdAt: number = 0;
  updatedAt: number = 0;
  messageCount: number = 0;

  static fromJson(json: Record<string, Object>): SessionInfo {
    const info = new SessionInfo();
    info.id = (json['id'] as string) ?? '';
    info.title = (json['title'] as string) ?? '';
    info.createdAt = (json['createdAt'] as number) ?? 0;
    info.updatedAt = (json['updatedAt'] as number) ?? 0;
    info.messageCount = (json['messageCount'] as number) ?? 0;
    return info;
  }
}

export class ProviderInfo {
  id: string = '';
  name: string = '';
  models: string[] = [];

  static fromJson(json: Record<string, Object>): ProviderInfo {
    const info = new ProviderInfo();
    info.id = (json['id'] as string) ?? '';
    info.name = (json['name'] as string) ?? '';
    const modelsArr = json['models'];
    if (Array.isArray(modelsArr)) {
      info.models = modelsArr as string[];
    }
    return info;
  }
}
