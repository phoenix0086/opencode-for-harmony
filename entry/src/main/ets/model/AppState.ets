/**
 * Global application state models.
 */

export enum ConnectionStatus {
  Disconnected = 'disconnected',
  AutoStarting = 'auto_starting',
  Connecting = 'connecting',
  Connected = 'connected',
  StartFailed = 'start_failed',
  Error = 'error'
}

export enum AppView {
  Home = 'home',
  Chat = 'chat',
  Files = 'files',
  Terminal = 'terminal',
  Provider = 'provider',
  Models = 'models',
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

    const createdAt = json['createdAt'] as number;
    const updatedAt = json['updatedAt'] as number;
    if (createdAt) info.createdAt = createdAt;
    if (updatedAt) info.updatedAt = updatedAt;

    const time = json['time'] as Record<string, Object>;
    if (time) {
      const created = time['created'] as number;
      const updated = time['updated'] as number;
      if (created) info.createdAt = created;
      if (updated) info.updatedAt = updated;
    }

    const messageCount = json['messageCount'] as number;
    if (messageCount) info.messageCount = messageCount;
    return info;
  }
}

export class ProviderInfo {
  id: string = '';
  name: string = '';
  models: string[] = [];
  connected: boolean = false;
  source: string = 'runtime';

  static fromJson(json: Record<string, Object>, connectedIds?: string[]): ProviderInfo {
    const info = new ProviderInfo();
    info.id = (json['id'] as string) ?? '';
    info.name = (json['name'] as string) ?? info.id;
    info.connected = connectedIds ? connectedIds.includes(info.id) : false;

    const connectedValue = json['connected'];
    if (typeof connectedValue === 'boolean') {
      info.connected = connectedValue;
    }

    const modelsAny = json['models'];
    if (Array.isArray(modelsAny)) {
      const arr = modelsAny as Object[];
      const out: string[] = [];
      for (const item of arr) {
        if (typeof item === 'string') {
          out.push(item);
        } else if (item && typeof item === 'object') {
          const rec = item as Record<string, Object>;
          const id = (rec['id'] as string) ?? '';
          if (id.length > 0) out.push(id);
        }
      }
      info.models = out;
    } else if (modelsAny && typeof modelsAny === 'object') {
      info.models = Object.keys(modelsAny as Record<string, Object>);
    }

    return info;
  }

  static fromRuntimeMapEntry(id: string, value: Object, connectedIds?: string[]): ProviderInfo {
    const rec = value as Record<string, Object>;
    rec['id'] = id as Object;
    return ProviderInfo.fromJson(rec, connectedIds);
  }
}
