import { http } from '@kit.NetworkKit';
import { Logger } from '../utils/Logger';
import { Constants } from '../utils/Constants';
import { ServerInfo } from '../model/ServerInfo';

/**
 * HTTP client for communicating with the local OpenCode Runtime.
 */
export class HttpService {
  private server: ServerInfo | null = null;

  setServer(server: ServerInfo): void {
    this.server = server;
  }

  getBaseUrl(): string {
    if (!this.server) return '';
    return this.server.url.replace(/\/+$/, '');
  }

  private buildUrl(path: string): string {
    if (!this.server) throw new Error('Runtime not configured');
    return this.server.url.replace(/\/+$/, '') + path;
  }

  private buildHeaders(extra?: Record<string, string>): Record<string, string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    };
    if (this.server) {
      const auth = this.server.getAuthHeader();
      if (auth.length > 0) headers['Authorization'] = auth;
    }
    if (extra) {
      for (const key of Object.keys(extra)) headers[key] = extra[key];
    }
    return headers;
  }

  private parseResult<T>(result: Object | string | ArrayBuffer | undefined | null): T {
    if (result === undefined || result === null) return undefined as T;
    if (typeof result === 'string') {
      if (result.length === 0) return undefined as T;
      try { return JSON.parse(result) as T; } catch { return result as T; }
    }
    return result as T;
  }

  private async request<T>(path: string, method: http.RequestMethod, body?: Object, extraHeaders?: Record<string, string>): Promise<T> {
    const url = this.buildUrl(path);
    const httpRequest = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: method,
        header: this.buildHeaders(extraHeaders),
        connectTimeout: Constants.HTTP_TIMEOUT_MS,
        readTimeout: Constants.HTTP_TIMEOUT_MS,
        expectDataType: http.HttpDataType.OBJECT
      };
      if (body !== undefined) options.extraData = JSON.stringify(body);
      const response = await httpRequest.request(url, options);
      if (response.responseCode >= 200 && response.responseCode < 300) return this.parseResult<T>(response.result);
      throw new Error(`HTTP ${response.responseCode}: ${JSON.stringify(response.result)}`);
    } catch (err) {
      Logger.error('HTTP %{public}s %{public}s failed: ', String(method), path + String(String(err)));
      throw new Error(String(err));
    } finally {
      httpRequest.destroy();
    }
  }

  async get<T>(path: string): Promise<T> { return this.request<T>(path, http.RequestMethod.GET); }
  async post<T>(path: string, body?: Object): Promise<T> { return this.request<T>(path, http.RequestMethod.POST, body); }
  async put<T>(path: string, body?: Object): Promise<T> { return this.request<T>(path, http.RequestMethod.PUT, body); }
  async delete<T>(path: string): Promise<T> { return this.request<T>(path, http.RequestMethod.DELETE); }

  async patch<T>(path: string, body?: Object): Promise<T> {
    return this.request<T>(path, http.RequestMethod.POST, body, { 'X-HTTP-Method-Override': 'PATCH' });
  }

  async checkHealth(): Promise<boolean> {
    try {
      const result = await this.get<Record<string, Object>>(Constants.API_HEALTH);
      if (!result) return true;
      const healthy = result['healthy'];
      if (typeof healthy === 'boolean') return healthy;
      return true;
    } catch {
      return false;
    }
  }
}
