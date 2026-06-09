import { http } from '@kit.NetworkKit';
import { Logger } from '../utils/Logger';
import { Constants } from '../utils/Constants';
import { ServerInfo } from '../model/ServerInfo';

/**
 * HTTP client for communicating with the OpenCode server.
 * Supports GET/POST/PUT/DELETE with basic auth.
 */
export class HttpService {
  private server: ServerInfo | null = null;

  setServer(server: ServerInfo): void {
    this.server = server;
  }

  private buildUrl(path: string): string {
    if (!this.server) {
      throw new Error('Server not configured');
    }
    const base = this.server.url.replace(/\/+$/, '');
    return base + path;
  }

  private buildHeaders(): Record<string, string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    };
    if (this.server) {
      const auth = this.server.getAuthHeader();
      if (auth.length > 0) {
        headers['Authorization'] = auth;
      }
    }
    return headers;
  }

  async get<T>(path: string): Promise<T> {
    const url = this.buildUrl(path);
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: this.buildHeaders(),
        connectTimeout: Constants.HTTP_TIMEOUT_MS,
        readTimeout: Constants.HTTP_TIMEOUT_MS,
        expectDataType: http.HttpDataType.OBJECT
      });
      if (response.responseCode === 200) {
        return response.result as T;
      }
      throw new Error(`HTTP ${response.responseCode}: ${JSON.stringify(response.result)}`);
    } catch (err) {
      Logger.error('HTTP GET %{public}s failed: %{public}s', path, String(err));
      throw new Error(String(err));
    } finally {
      httpRequest.destroy();
    }
  }

  async post<T>(path: string, body?: Object): Promise<T> {
    const url = this.buildUrl(path);
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: this.buildHeaders(),
        extraData: body ? JSON.stringify(body) : undefined,
        connectTimeout: Constants.HTTP_TIMEOUT_MS,
        readTimeout: Constants.HTTP_TIMEOUT_MS,
        expectDataType: http.HttpDataType.OBJECT
      });
      if (response.responseCode >= 200 && response.responseCode < 300) {
        return response.result as T;
      }
      throw new Error(`HTTP ${response.responseCode}: ${JSON.stringify(response.result)}`);
    } catch (err) {
      Logger.error('HTTP POST %{public}s failed: %{public}s', path, String(err));
      throw new Error(String(err));
    } finally {
      httpRequest.destroy();
    }
  }

  async put<T>(path: string, body?: Object): Promise<T> {
    const url = this.buildUrl(path);
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.PUT,
        header: this.buildHeaders(),
        extraData: body ? JSON.stringify(body) : undefined,
        connectTimeout: Constants.HTTP_TIMEOUT_MS,
        readTimeout: Constants.HTTP_TIMEOUT_MS,
        expectDataType: http.HttpDataType.OBJECT
      });
      if (response.responseCode >= 200 && response.responseCode < 300) {
        return response.result as T;
      }
      throw new Error(`HTTP ${response.responseCode}: ${JSON.stringify(response.result)}`);
    } catch (err) {
      Logger.error('HTTP PUT %{public}s failed: %{public}s', path, String(err));
      throw new Error(String(err));
    } finally {
      httpRequest.destroy();
    }
  }

  async delete<T>(path: string): Promise<T> {
    const url = this.buildUrl(path);
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.DELETE,
        header: this.buildHeaders(),
        connectTimeout: Constants.HTTP_TIMEOUT_MS,
        readTimeout: Constants.HTTP_TIMEOUT_MS,
        expectDataType: http.HttpDataType.OBJECT
      });
      if (response.responseCode >= 200 && response.responseCode < 300) {
        return response.result as T;
      }
      throw new Error(`HTTP ${response.responseCode}: ${JSON.stringify(response.result)}`);
    } catch (err) {
      Logger.error('HTTP DELETE %{public}s failed: %{public}s', path, String(err));
      throw new Error(String(err));
    } finally {
      httpRequest.destroy();
    }
  }

  async checkHealth(): Promise<boolean> {
    try {
      await this.get<Record<string, string>>(Constants.API_HEALTH);
      return true;
    } catch {
      return false;
    }
  }
}
