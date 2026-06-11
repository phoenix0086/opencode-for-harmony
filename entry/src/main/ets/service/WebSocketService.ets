import { webSocket } from '@kit.NetworkKit';
import { Logger } from '../utils/Logger';
import { Constants } from '../utils/Constants';
import { ServerInfo } from '../model/ServerInfo';
import { errStr } from '../utils/ErrorUtil';

export type WSMessageHandler = (data: string) => void;
export type WSStatusHandler = (connected: boolean) => void;

/**
 * WebSocket client for real-time streaming from the OpenCode server.
 * Handles connection lifecycle, reconnection, and message dispatch.
 */
export class WebSocketService {
  private ws: webSocket.WebSocket | null = null;
  private server: ServerInfo | null = null;
  private onMessage: WSMessageHandler | null = null;
  private onStatus: WSStatusHandler | null = null;
  private reconnectAttempts: number = 0;
  private reconnectTimer: number = -1;
  private connected: boolean = false;
  private shouldReconnect: boolean = true;

  setServer(server: ServerInfo): void {
    this.server = server;
  }

  setMessageHandler(handler: WSMessageHandler): void {
    this.onMessage = handler;
  }

  setStatusHandler(handler: WSStatusHandler): void {
    this.onStatus = handler;
  }

  connect(): void {
    if (!this.server) {
      Logger.error('WebSocketService: server not configured');
      return;
    }
    this.shouldReconnect = true;
    this.doConnect();
  }

  private doConnect(): void {
    if (!this.server) return;

    // Clean up previous WebSocket instance before creating a new one.
    // Without this, reconnecting leaks the old socket and its event listeners.
    if (this.ws) {
      try { this.ws.off('open'); } catch (_) {}
      try { this.ws.off('message'); } catch (_) {}
      try { this.ws.off('close'); } catch (_) {}
      try { this.ws.off('error'); } catch (_) {}
      try { this.ws.close(); } catch (_) {}
      this.ws = null
    }

    const wsUrl = this.server.url.replace(/^http/, 'ws') + '/ws';
    Logger.info('WebSocketService connecting to ' + String(wsUrl));

    this.ws = webSocket.createWebSocket();

    this.ws.on('open', () => {
      Logger.info('WebSocketService connected');
      this.connected = true;
      this.reconnectAttempts = 0;
      this.onStatus?.(true);
    });

    this.ws.on('message', (err: Error, data: string | ArrayBuffer) => {
      if (err) {
        Logger.error('WebSocketService message error: ' + errStr(err));
        return;
      }
      if (typeof data === 'string') {
        this.onMessage?.(data);
      }
    });

    this.ws.on('close', () => {
      Logger.info('WebSocketService closed');
      this.connected = false;
      this.onStatus?.(false);
      this.tryReconnect();
    });

    this.ws.on('error', (err: Error) => {
      Logger.error('WebSocketService error: ' + errStr(err));
      this.connected = false;
      this.onStatus?.(false);
    });

    // Build headers
    const headers: Record<string, string> = {};
    if (this.server.username.length > 0 && this.server.password.length > 0) {
      const combined = this.server.username + ':' + this.server.password;
      headers['Authorization'] = 'Basic ' + encodeBase64(combined);
    }

    this.ws.connect(wsUrl, { header: headers }, (err: Error) => {
      if (err) {
        Logger.error('WebSocketService connect failed: ' + errStr(err));
        this.tryReconnect();
      }
    });
  }

  private tryReconnect(): void {
    if (!this.shouldReconnect) return;
    if (this.reconnectAttempts >= Constants.WS_MAX_RECONNECT_ATTEMPTS) {
      Logger.error('WebSocketService: max reconnect attempts reached');
      return;
    }
    this.reconnectAttempts++;
    Logger.info('WebSocketService: reconnecting in ' + Constants.WS_RECONNECT_INTERVAL_MS.toString() + 'ms (attempt ' +
      this.reconnectAttempts.toString() + ')');

    this.reconnectTimer = setTimeout(() => {
      this.doConnect();
    }, Constants.WS_RECONNECT_INTERVAL_MS) as number;
  }

  send(data: string): void {
    if (!this.ws || !this.connected) {
      Logger.error('WebSocketService: not connected, cannot send');
      return;
    }
    this.ws.send(data, (err: Error) => {
      if (err) {
        Logger.error('WebSocketService send error: ' + errStr(err));
      }
    });
  }

  sendJson(obj: Object): void {
    this.send(JSON.stringify(obj));
  }

  disconnect(): void {
    this.shouldReconnect = false;
    if (this.reconnectTimer >= 0) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = -1;
    }
    if (this.ws) {
      this.ws.close((err: Error) => {
        if (err) {
          Logger.error('WebSocketService close error: ' + String(err.message));
        }
      });
      this.ws = null;
    }
    this.connected = false;
    this.onStatus?.(false);
  }

  isConnected(): boolean {
    return this.connected;
  }
}

function encodeBase64(input: string): string {
  const chars: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  let result: string = '';
  let i: number = 0;
  while (i < input.length) {
    const a: number = input.charCodeAt(i++);
    const b: number = i < input.length ? input.charCodeAt(i++) : 0;
    const c: number = i < input.length ? input.charCodeAt(i++) : 0;
    const idx1: number = a >> 2;
    const idx2: number = ((a & 3) << 4) | (b >> 4);
    const idx3: number = ((b & 15) << 2) | (c >> 6);
    const idx4: number = c & 63;
    result += chars.charAt(idx1) + chars.charAt(idx2);
    if (i > input.length + 1) {
      result += '==';
    } else if (i > input.length) {
      result += chars.charAt(idx3) + '=';
    } else {
      result += chars.charAt(idx3) + chars.charAt(idx4);
    }
  }
  return result;
}
