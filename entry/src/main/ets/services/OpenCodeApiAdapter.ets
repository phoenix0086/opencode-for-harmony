import { http } from '@kit.NetworkKit';
import { Logger } from '../utils/Logger';
import { errStr } from '../utils/ErrorUtil';
import { OpenCodeCapabilities, ServerMode, CapabilityResult } from './OpenCodeCapabilities';
import { ChatMessage } from '../model/ChatMessage';

/**
 * Unified API adapter for OpenCode Runtime.
 * Routes calls to /api/... (v2) or legacy endpoints based on detected server mode.
 */
export interface SessionInfo {
  id: string;
  name: string;
  createdAt: string;
  updatedAt: string;
  model?: string;
  agent?: string;
}

export interface PromptInput {
  text: string;
  model?: string;
  agent?: string;
}

export interface PromptResult {
  ok: boolean;
  error?: string;
}

export class OpenCodeApiAdapter {
  private baseUrl: string = '';
  private mode: ServerMode = 'unknown';
  private caps: CapabilityResult | null = null;
  private detector: OpenCodeCapabilities = new OpenCodeCapabilities();

  setBaseUrl(url: string): void {
    this.baseUrl = url.replace(/\/+$/, '');
    this.detector.setBaseUrl(url);
  }

  async detectCapabilities(): Promise<CapabilityResult> {
    this.caps = await this.detector.detect();
    this.mode = this.caps.mode;
    Logger.info(`API adapter mode: ${this.mode}, version: ${this.caps.version}`);
    return this.caps;
  }

  getMode(): ServerMode { return this.mode; }
  getCapabilities(): CapabilityResult | null { return this.caps; }

  // ══════════════════════════════════════════════════════════
  //  Health
  // ══════════════════════════════════════════════════════════
  async health(): Promise<Record<string, Object>> {
    if (this.mode === 'api-v2') {
      return this.get('/api/health');
    }
    return this.get('/global/health');
  }

  // ══════════════════════════════════════════════════════════
  //  Sessions
  // ══════════════════════════════════════════════════════════
  async listSessions(): Promise<SessionInfo[]> {
    if (this.mode === 'api-v2') {
      const data = await this.get<{ data: Object[] }>('/api/session');
      return this.normalizeSessions(data.data ?? []);
    }
    const arr = await this.get<Object[]>('/session');
    return this.normalizeSessions(arr ?? []);
  }

  async createSession(input?: { model?: string; agent?: string; location?: string }): Promise<SessionInfo> {
    if (this.mode === 'api-v2') {
      const data = await this.post<{ data: Record<string, Object> }>('/api/session', input ?? {});
      return this.normalizeSession(data.data ?? {});
    }
    const data = await this.post<Record<string, Object>>('/session', input ?? {});
    return this.normalizeSession(data);
  }

  async getSession(sessionId: string): Promise<SessionInfo> {
    if (this.mode === 'api-v2') {
      const data = await this.get<{ data: Record<string, Object> }>(`/api/session/${sessionId}`);
      return this.normalizeSession(data.data ?? {});
    }
    const data = await this.get<Record<string, Object>>(`/session/${sessionId}`);
    return this.normalizeSession(data);
  }

  // ══════════════════════════════════════════════════════════
  //  Prompt
  // ══════════════════════════════════════════════════════════
  async sendPrompt(sessionId: string, input: PromptInput): Promise<PromptResult> {
    if (this.mode === 'api-v2') {
      try {
        await this.post(`/api/session/${sessionId}/prompt`, {
          prompt: input.text,
          model: input.model,
          agent: input.agent
        });
        return { ok: true };
      } catch (e) {
        return { ok: false, error: errStr(e) };
      }
    }
    // Legacy: prompt_async
    try {
      await this.post(`/session/${sessionId}/prompt_async`, { text: input.text });
      return { ok: true };
    } catch (e) {
      return { ok: false, error: errStr(e) };
    }
  }

  // ══════════════════════════════════════════════════════════
  //  Wait / Poll
  // ══════════════════════════════════════════════════════════
  async waitSession(sessionId: string): Promise<Record<string, Object>> {
    if (this.mode === 'api-v2') {
      return this.post(`/api/session/${sessionId}/wait`, {});
    }
    // Legacy: no wait endpoint, return empty
    return {};
  }

  // ══════════════════════════════════════════════════════════
  //  Messages
  // ══════════════════════════════════════════════════════════
  async listMessages(sessionId: string): Promise<Object[]> {
    if (this.mode === 'api-v2') {
      const data = await this.get<{ data: Object[] }>(`/api/session/${sessionId}/message`);
      return data.data ?? [];
    }
    return this.get<Object[]>(`/session/${sessionId}/message`);
  }

  // ══════════════════════════════════════════════════════════
  //  Context
  // ══════════════════════════════════════════════════════════
  async getSessionContext(sessionId: string): Promise<Record<string, Object>> {
    if (this.mode === 'api-v2') {
      const data = await this.get<{ data: Record<string, Object> }>(`/api/session/${sessionId}/context`);
      return data.data ?? {};
    }
    return {};
  }

  // ══════════════════════════════════════════════════════════
  //  Providers
  // ══════════════════════════════════════════════════════════
  async listProviders(): Promise<Record<string, Object>> {
    if (this.mode === 'api-v2') {
      const data = await this.get<{ data: Record<string, Object> }>('/api/provider');
      return data.data ?? {};
    }
    return this.get<Record<string, Object>>('/provider');
  }

  // ══════════════════════════════════════════════════════════
  //  Models
  // ══════════════════════════════════════════════════════════
  async listModels(): Promise<Object[]> {
    if (this.mode === 'api-v2') {
      const data = await this.get<{ data: Object[] }>('/api/model');
      return data.data ?? [];
    }
    return [];
  }

  // ══════════════════════════════════════════════════════════
  //  Config
  // ══════════════════════════════════════════════════════════
  async getConfig(): Promise<Record<string, Object>> {
    if (this.mode === 'api-v2') {
      const data = await this.get<{ data: Record<string, Object> }>('/api/config');
      return data.data ?? {};
    }
    return this.get<Record<string, Object>>('/config');
  }

  async patchConfig(body: Record<string, Object>): Promise<void> {
    if (this.mode === 'api-v2') {
      await this.patch('/api/config', body);
      return;
    }
    await this.patch('/config', body);
  }

  // ══════════════════════════════════════════════════════════
  //  Files
  // ══════════════════════════════════════════════════════════
  async listFiles(path: string): Promise<Object[]> {
    if (this.mode === 'api-v2' && this.caps?.capabilities.fs) {
      const data = await this.get<{ data: Object[] }>(`/api/fs/list?path=${encodeURIComponent(path)}`);
      return data.data ?? [];
    }
    // Legacy fallback
    return this.get<Object[]>(`/file?path=${encodeURIComponent(path)}`);
  }

  // ══════════════════════════════════════════════════════════
  //  HTTP helpers
  // ══════════════════════════════════════════════════════════
  private async get<T>(path: string): Promise<T> {
    return this.request<T>(path, http.RequestMethod.GET);
  }

  private async post<T>(path: string, body?: Object): Promise<T> {
    return this.request<T>(path, http.RequestMethod.POST, body);
  }

  private async patch<T>(path: string, body?: Object): Promise<T> {
    const headers: Record<string, string> = {};
    headers['X-HTTP-Method-Override'] = 'PATCH';
    return this.request<T>(path, http.RequestMethod.POST, body, headers);
  }

  private async request<T>(path: string, method: http.RequestMethod, body?: Object, extraHeaders?: Record<string, string>): Promise<T> {
    const url = this.baseUrl + path;
    const httpRequest = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: method,
        header: this.buildHeaders(extraHeaders),
        connectTimeout: 30000,
        readTimeout: 30000,
        expectDataType: http.HttpDataType.OBJECT
      };
      if (body !== undefined) options.extraData = JSON.stringify(body);
      const response = await httpRequest.request(url, options);
      if (response.responseCode >= 200 && response.responseCode < 300) {
        return this.parseResult<T>(response.result);
      }
      throw new Error(`HTTP ${response.responseCode}: ${JSON.stringify(response.result)}`);
    } catch (err) {
      Logger.error(`API ${method} ${path} failed: ${errStr(err)}`);
      throw new Error(errStr(err));
    } finally {
      httpRequest.destroy();
    }
  }

  private buildHeaders(extra?: Record<string, string>): Record<string, string> {
    const headers: Record<string, string> = {};
    headers['Content-Type'] = 'application/json';
    headers['Accept'] = 'application/json';
    if (extra) for (const key of Object.keys(extra)) headers[key] = extra[key];
    return headers;
  }

  private parseResult<T>(result: Object | string | ArrayBuffer | undefined | null): T {
    if (result === undefined || result === null) return undefined as T;
    if (typeof result === 'string') {
      if (result.length === 0) return undefined as T;
      try { return JSON.parse(result) as T; } catch (e) { return result as T; }
    }
    return result as T;
  }

  // ══════════════════════════════════════════════════════════
  //  Normalization
  // ══════════════════════════════════════════════════════════
  private normalizeSessions(raw: Object[]): SessionInfo[] {
    return raw.map(item => this.normalizeSession(item as Record<string, Object>));
  }

  private normalizeSession(item: Record<string, Object>): SessionInfo {
    const id = (item['id'] as string) ?? (item['sessionId'] as string) ?? '';
    const name = (item['name'] as string) ?? (item['title'] as string) ?? 'New Session';
    const createdAt = (item['createdAt'] as string) ?? (item['created_at'] as string) ?? '';
    const updatedAt = (item['updatedAt'] as string) ?? (item['updated_at'] as string) ?? '';
    const model = (item['model'] as string) ?? '';
    const agent = (item['agent'] as string) ?? '';
    return { id, name, createdAt, updatedAt, model, agent };
  }
}