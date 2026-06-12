import { http } from '@kit.NetworkKit';
import { Logger } from '../utils/Logger';
import { errStr } from '../utils/ErrorUtil';
import { OpenCodeCapabilities, ServerMode, CapabilityResult } from './OpenCodeCapabilities';
import { RuntimeMode } from './RuntimeMode';
import { localRuntimeClient } from './LocalRuntimeClient';

/**
 * Unified API adapter for OpenCode Runtime.
 * Routes calls to /api/... (v2) or legacy endpoints based on detected server mode.
 */

export class SessionInfo {
  id: string = '';
  name: string = '';
  createdAt: string = '';
  updatedAt: string = '';
  model: string = '';
  agent: string = '';
}

export class PromptInput {
  text: string = '';
  model: string = '';
  agent: string = '';
}

export class PromptResult {
  ok: boolean = false;
  error: string = '';
}

export class OpenCodeApiAdapter {
  private baseUrl: string = '';
  private authHeader: string = '';
  private mode: ServerMode = 'unknown';
  private caps: CapabilityResult | null = null;
  private detector: OpenCodeCapabilities = new OpenCodeCapabilities();
  private _runtimeMode: RuntimeMode = 'dev-pc';

  get runtimeMode(): RuntimeMode { return this._runtimeMode; }

  setRuntimeMode(mode: RuntimeMode): void {
    this._runtimeMode = mode;
    Logger.info(`[Adapter] runtime mode set to: ${mode}`);
  }

  private get isLocal(): boolean { return this._runtimeMode === 'local-embedded'; }

  setBaseUrl(url: string, authHeader: string = ''): void {
    this.baseUrl = url.replace(/\/+$/, '');
    this.authHeader = authHeader;
    this.detector.setBaseUrl(url);
    if (authHeader.length > 0) {
      this.detector.setAuthHeader(authHeader);
    }
  }

  async detectCapabilities(): Promise<CapabilityResult> {
    if (this.isLocal) {
      this.mode = 'api-v2';
      const synthetic: CapabilityResult = { mode: 'api-v2', version: 'local-embedded-0.1.0', capabilities: { fs: false } } as CapabilityResult;
      this.caps = synthetic;
      Logger.info('[Adapter] local-embedded: synthetic capabilities returned');
      return synthetic;
    }
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
    if (this.isLocal) return localRuntimeClient.health();
    if (this.mode === 'api-v2') {
      return this.get('/api/health');
    }
    return this.get('/global/health');
  }

  // ══════════════════════════════════════════════════════════
  //  Sessions
  // ══════════════════════════════════════════════════════════
  async listSessions(): Promise<SessionInfo[]> {
    if (this.isLocal) return localRuntimeClient.listSessions();
    if (this.mode === 'api-v2') {
      const data = await this.get('/api/session');
      const arr = this.extractArray(data, 'data');
      return this.normalizeSessions(arr);
    }
    const arr = await this.get('/session');
    return this.normalizeSessions(this.asArray(arr));
  }

  async createSession(input?: Record<string, Object>): Promise<SessionInfo> {
    if (this.isLocal) return localRuntimeClient.createSession(input);
    const body = input ?? {};
    if (this.mode === 'api-v2') {
      const data = await this.post('/api/session', body);
      return this.normalizeSession(this.extractObj(data, 'data'));
    }
    const data = await this.post('/session', body);
    return this.normalizeSession(data);
  }

  async getSession(sessionId: string): Promise<SessionInfo> {
    if (this.isLocal) return localRuntimeClient.getSession(sessionId);
    if (this.mode === 'api-v2') {
      const data = await this.get(`/api/session/${sessionId}`);
      return this.normalizeSession(this.extractObj(data, 'data'));
    }
    const data = await this.get(`/session/${sessionId}`);
    return this.normalizeSession(data);
  }

  async deleteSession(sessionId: string): Promise<boolean> {
    if (this.isLocal) return localRuntimeClient.deleteSession(sessionId);
    try {
      if (this.mode === 'api-v2') {
        await this.delete(`/api/session/${sessionId}`);
      } else {
        await this.delete(`/session/${sessionId}`);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════
  //  Prompt
  // ══════════════════════════════════════════════════════════
  async sendPrompt(sessionId: string, input: PromptInput): Promise<PromptResult> {
    if (this.isLocal) return localRuntimeClient.sendPrompt(sessionId, input);
    const result = new PromptResult();
    if (this.mode === 'api-v2') {
      try {
        const body: Record<string, Object> = {};
        const prompt: Record<string, Object> = {};
        prompt['text'] = input.text;
        body['prompt'] = prompt;
        await this.post(`/api/session/${sessionId}/prompt`, body);
        result.ok = true;
        return result;
      } catch (e) {
        result.error = errStr(e);
        return result;
      }
    }
    // Legacy: prompt_async
    try {
      const body: Record<string, Object> = {};
      const textPart: Record<string, Object> = {};
      textPart['type'] = 'text';
      textPart['text'] = input.text;
      body['agent'] = input.agent.length > 0 ? input.agent : 'build';
      body['parts'] = [textPart];
      await this.post(`/session/${sessionId}/prompt_async`, body);
      result.ok = true;
      return result;
    } catch (e) {
      result.error = errStr(e);
      return result;
    }
  }

  // ══════════════════════════════════════════════════════════
  //  Wait / Poll
  // ══════════════════════════════════════════════════════════
  async waitSession(sessionId: string): Promise<Record<string, Object>> {
    if (this.isLocal) return localRuntimeClient.waitSession(sessionId);
    if (this.mode === 'api-v2') {
      return this.post(`/api/session/${sessionId}/wait`, {});
    }
    return {};
  }

  // ══════════════════════════════════════════════════════════
  //  Messages
  // ══════════════════════════════════════════════════════════
  async listMessages(sessionId: string): Promise<Object[]> {
    if (this.isLocal) return localRuntimeClient.listMessages(sessionId);
    if (this.mode === 'api-v2') {
      const data = await this.get(`/api/session/${sessionId}/message`);
      return this.extractArray(data, 'data');
    }
    const data = await this.get(`/session/${sessionId}/message`);
    return this.asArray(data);
  }

  // ══════════════════════════════════════════════════════════
  //  Context
  // ══════════════════════════════════════════════════════════
  async getSessionContext(sessionId: string): Promise<Record<string, Object>> {
    if (this.isLocal) return localRuntimeClient.getSessionContext(sessionId);
    if (this.mode === 'api-v2') {
      const data = await this.get(`/api/session/${sessionId}/context`);
      return this.extractObj(data, 'data');
    }
    return {};
  }

  // ══════════════════════════════════════════════════════════
  //  Providers
  // ══════════════════════════════════════════════════════════
  async listProviders(): Promise<Record<string, Object>> {
    if (this.isLocal) return localRuntimeClient.listProviders();
    if (this.mode === 'api-v2') {
      const data = await this.get('/api/provider');
      return this.extractObj(data, 'data');
    }
    return this.get('/provider');
  }

  // ══════════════════════════════════════════════════════════
  //  Models
  // ══════════════════════════════════════════════════════════
  async listModels(): Promise<Object[]> {
    if (this.isLocal) return localRuntimeClient.listModels();
    if (this.mode === 'api-v2') {
      const data = await this.get('/api/model');
      return this.extractArray(data, 'data');
    }
    return [];
  }

  // ══════════════════════════════════════════════════════════
  //  Config
  // ══════════════════════════════════════════════════════════
  async getConfig(): Promise<Record<string, Object>> {
    if (this.isLocal) return localRuntimeClient.getConfig();
    if (this.mode === 'api-v2') {
      const data = await this.get('/api/config');
      return this.extractObj(data, 'data');
    }
    return this.get('/config');
  }

  async patchConfig(body: Record<string, Object>): Promise<void> {
    if (this.isLocal) { await localRuntimeClient.patchConfig(body); return; }
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
    if (this.isLocal) return localRuntimeClient.listFiles(path);
    if (this.mode === 'api-v2' && this.caps !== null && this.caps.capabilities.fs) {
      const data = await this.get(`/api/fs/list?path=${encodeURIComponent(path)}`);
      return this.extractArray(data, 'data');
    }
    const data = await this.get(`/file?path=${encodeURIComponent(path)}`);
    return this.asArray(data);
  }

  async findFiles(query: string): Promise<Object[]> {
    if (this.isLocal) return localRuntimeClient.findFiles(query);
    if (this.mode !== 'api-v2') return [];
    const data = await this.get(`/api/fs/find?query=${encodeURIComponent(query)}`);
    return this.extractArray(data, 'data');
  }

  // ══════════════════════════════════════════════════════════
  //  Permissions
  // ══════════════════════════════════════════════════════════
  async listPermissionRequests(): Promise<Object[]> {
    if (this.isLocal) return localRuntimeClient.listPermissionRequests();
    if (this.mode === 'api-v2') {
      const data = await this.get('/api/permission/request');
      return this.extractArray(data, 'data');
    }
    const data = await this.get('/permission');
    return this.asArray(data);
  }

  async listSavedPermissions(): Promise<Object[]> {
    if (this.isLocal) return localRuntimeClient.listSavedPermissions();
    if (this.mode === 'api-v2') {
      const data = await this.get('/api/permission/saved');
      return this.extractArray(data, 'data');
    }
    return [];
  }

  async deleteSavedPermission(id: string): Promise<boolean> {
    if (this.isLocal) return localRuntimeClient.deleteSavedPermission(id);
    if (this.mode !== 'api-v2') return false;
    try {
      await this.delete(`/api/permission/saved/${id}`);
      return true;
    } catch (_) {
      return false;
    }
  }

  async listSessionPermissions(sessionId: string): Promise<Object[]> {
    if (this.isLocal) return localRuntimeClient.listSessionPermissions(sessionId);
    if (this.mode === 'api-v2') {
      const data = await this.get(`/api/session/${sessionId}/permission`);
      return this.extractArray(data, 'data');
    }
    return [];
  }

  async replyPermission(sessionId: string, requestId: string, reply: string): Promise<boolean> {
    if (this.isLocal) return localRuntimeClient.replyPermission(sessionId, requestId, reply);
    try {
      const body: Record<string, Object> = {};
      body['reply'] = reply;
      if (this.mode === 'api-v2') {
        await this.post(`/api/session/${sessionId}/permission/${requestId}/reply`, body);
      } else {
        await this.post(`/permission/${requestId}/reply`, body);
      }
      return true;
    } catch (e) {
      Logger.error(`replyPermission failed: ${errStr(e)}`);
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════
  //  Questions
  // ══════════════════════════════════════════════════════════
  async listQuestions(sessionId: string): Promise<Object[]> {
    if (this.isLocal) return localRuntimeClient.listQuestions(sessionId);
    if (this.mode === 'api-v2') {
      const data = await this.get(`/api/session/${sessionId}/question`);
      return this.extractArray(data, 'data');
    }
    try {
      const data = await this.get(`/question?sessionID=${sessionId}`);
      return this.asArray(data);
    } catch (_) {
      return [];
    }
  }

  async replyQuestion(sessionId: string, requestId: string, optionIDs: string[]): Promise<boolean> {
    if (this.isLocal) return localRuntimeClient.replyQuestion(sessionId, requestId, optionIDs);
    try {
      const body: Record<string, Object> = {};
      body['optionIDs'] = optionIDs;
      if (this.mode === 'api-v2') {
        await this.post(`/api/session/${sessionId}/question/${requestId}/reply`, body);
      } else {
        await this.post(`/question/${requestId}/reply`, body);
      }
      return true;
    } catch (e) {
      Logger.error(`replyQuestion failed: ${errStr(e)}`);
      return false;
    }
  }

  async rejectQuestion(sessionId: string, requestId: string): Promise<boolean> {
    if (this.isLocal) return localRuntimeClient.rejectQuestion(sessionId, requestId);
    if (this.mode !== 'api-v2') return false;
    try {
      await this.post(`/api/session/${sessionId}/question/${requestId}/reject`, {});
      return true;
    } catch (e) {
      Logger.error(`rejectQuestion failed: ${errStr(e)}`);
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════
  //  Commands & Skills
  // ══════════════════════════════════════════════════════════
  async listCommands(): Promise<Object[]> {
    if (this.isLocal) return localRuntimeClient.listCommands();
    if (this.mode === 'api-v2') {
      const data = await this.get('/api/command');
      return this.extractArray(data, 'data');
    }
    try {
      const data = await this.get('/command');
      return this.asArray(data);
    } catch (_) {
      return [];
    }
  }

  async listSkills(): Promise<Object[]> {
    if (this.isLocal) return localRuntimeClient.listSkills();
    if (this.mode === 'api-v2') {
      const data = await this.get('/api/skill');
      return this.extractArray(data, 'data');
    }
    try {
      const data = await this.get('/skill');
      return this.asArray(data);
    } catch (_) {
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════
  //  Abort
  // ══════════════════════════════════════════════════════════
  async abortSession(sessionId: string): Promise<boolean> {
    if (this.isLocal) return localRuntimeClient.abortSession(sessionId);
    try {
      if (this.mode === 'api-v2') {
        await this.post(`/api/session/${sessionId}/abort`, {});
      } else {
        await this.post(`/session/${sessionId}/abort`, {});
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════
  //  Tools (local-embedded only)
  // ══════════════════════════════════════════════════════════
  async readFile(filePath: string): Promise<Record<string, Object>> {
    if (this.isLocal) return localRuntimeClient.readFile(filePath);
    // Remote: use file API
    try {
      const data = await this.get(`/file/content?path=${encodeURIComponent(filePath)}`);
      return data;
    } catch (e) {
      return { ok: false, content: '', error: errStr(e) };
    }
  }

  async listDirectory(dirPath: string): Promise<Object[]> {
    if (this.isLocal) return localRuntimeClient.listDirectory(dirPath);
    try {
      const data = await this.get(`/file?path=${encodeURIComponent(dirPath)}`);
      return this.asArray(data);
    } catch (_) {
      return [];
    }
  }

  async searchText(query: string, dirPath: string = ''): Promise<Object[]> {
    if (this.isLocal) return localRuntimeClient.searchText(query, dirPath);
    return []; // Remote search not yet implemented
  }

  // ══════════════════════════════════════════════════════════
  //  Event Stream URL
  // ══════════════════════════════════════════════════════════
  getEventUrl(): string {
    if (this.isLocal) return localRuntimeClient.getEventUrl();
    if (this.mode === 'api-v2') return `${this.baseUrl}/api/event`;
    return `${this.baseUrl}/event`;
  }

  // ══════════════════════════════════════════════════════════
  //  HTTP helpers
  // ══════════════════════════════════════════════════════════
  private async get(path: string): Promise<Record<string, Object>> {
    return this.request(path, http.RequestMethod.GET);
  }

  private async post(path: string, body?: Record<string, Object>): Promise<Record<string, Object>> {
    return this.request(path, http.RequestMethod.POST, body);
  }

  private async patch(path: string, body?: Record<string, Object>): Promise<Record<string, Object>> {
    const headers: Record<string, string> = {};
    headers['X-HTTP-Method-Override'] = 'PATCH';
    return this.request(path, http.RequestMethod.POST, body, headers);
  }

  private async delete(path: string): Promise<Record<string, Object>> {
    return this.request(path, http.RequestMethod.DELETE);
  }

  private async request(path: string, method: http.RequestMethod, body?: Record<string, Object>, extraHeaders?: Record<string, string>): Promise<Record<string, Object>> {
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
        return this.parseResult(response.result);
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
    if (this.authHeader.length > 0) {
      headers['Authorization'] = this.authHeader;
    }
    if (extra !== undefined) {
      const keys = Object.keys(extra);
      for (let i = 0; i < keys.length; i++) {
        headers[keys[i]] = extra[keys[i]];
      }
    }
    return headers;
  }

  private parseResult(result: Object | string | ArrayBuffer | undefined | null): Record<string, Object> {
    if (result === undefined || result === null) return {};
    if (typeof result === 'string') {
      if (result.length === 0) return {};
      try { return JSON.parse(result) as Record<string, Object>; } catch (e) { return {}; }
    }
    return result as Record<string, Object>;
  }

  // ══════════════════════════════════════════════════════════
  //  Normalization
  // ══════════════════════════════════════════════════════════
  private normalizeSessions(raw: Object[]): SessionInfo[] {
    const result: SessionInfo[] = [];
    for (let i = 0; i < raw.length; i++) {
      result.push(this.normalizeSession(raw[i] as Record<string, Object>));
    }
    return result;
  }

  private normalizeSession(item: Record<string, Object>): SessionInfo {
    const s = new SessionInfo();
    s.id = (item['id'] as string) ?? (item['sessionId'] as string) ?? '';
    s.name = (item['name'] as string) ?? (item['title'] as string) ?? 'New Session';
    s.createdAt = (item['createdAt'] as string) ?? (item['created_at'] as string) ?? '';
    s.updatedAt = (item['updatedAt'] as string) ?? (item['updated_at'] as string) ?? '';
    s.model = (item['model'] as string) ?? '';
    s.agent = (item['agent'] as string) ?? '';
    return s;
  }

  // ══════════════════════════════════════════════════════════
  //  Helpers
  // ══════════════════════════════════════════════════════════
  private extractArray(data: Record<string, Object>, key: string): Object[] {
    const val = data[key];
    if (Array.isArray(val)) return val as Object[];
    return [];
  }

  private extractObj(data: Record<string, Object>, key: string): Record<string, Object> {
    const val = data[key];
    if (val !== undefined && val !== null && typeof val === 'object') return val as Record<string, Object>;
    return {};
  }

  private asArray(data: Record<string, Object>): Object[] {
    if (Array.isArray(data)) return data as Object[];
    // Try common keys
    const keys = ['data', 'items', 'sessions', 'messages', 'providers', 'models'];
    for (let i = 0; i < keys.length; i++) {
      const val = data[keys[i]];
      if (Array.isArray(val)) return val as Object[];
    }
    return [];
  }
}
