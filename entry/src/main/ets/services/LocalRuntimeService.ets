/**
 * LocalRuntimeService — in-process runtime for HarmonyOS.
 * Implements the OpenCode Server API subset needed by the app.
 * No external process, no HTTP server, no Linux binary dependency.
 */

import { Logger } from '../utils/Logger';
import { errStr } from '../utils/ErrorUtil';
import { storageService } from './StorageService';
import { providerRegistry } from './ProviderRegistry';
import { CNProvider, CNModel } from '../models/Provider';
import { http } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
import {
  RuntimeMode, LocalRuntimeConfig, RuntimeHealth,
  LocalProviderConfig, LocalModelConfig,
  LocalSession, LocalMessage, LocalPromptInput, LocalPromptResult,
  LocalProviderList, LocalModelRef, RuntimeEvent, LocalPermissionRequest
} from './LocalRuntimeTypes';

// Result classes for ArkTS (no inline object literal types)
class ProviderCallResult {
  ok: boolean = false;
  content: string = '';
  error: string = '';
}

class ReadFileResult {
  ok: boolean = false;
  content: string = '';
  error: string = '';
}

class ListDirResult {
  ok: boolean = false;
  entries: Record<string, Object>[] = [];
  error: string = '';
}

class SearchResult {
  ok: boolean = false;
  matches: Record<string, Object>[] = [];
  error: string = '';
}

class WriteFileResult {
  ok: boolean = false;
  error: string = '';
}

// Event listener type
type EventListener = (event: RuntimeEvent) => void;

export class LocalRuntimeService {
  private started: boolean = false;
  private config: LocalRuntimeConfig = new LocalRuntimeConfig();
  private providers: LocalProviderConfig[] = [];
  private sessions: LocalSession[] = [];
  private messages: Map<string, LocalMessage[]> = new Map();
  private listeners: EventListener[] = [];
  private startTime: number = 0;
  private generatingSessions: string[] = [];

  // ══════════ Lifecycle ══════════

  async start(config?: LocalRuntimeConfig): Promise<RuntimeHealth> {
    if (config !== undefined) {
      this.config = config;
    }
    this.startTime = Date.now();

    // Load persisted data
    await this.loadProviders();
    await this.syncFromProviderRegistry();
    await this.loadSessions();

    this.started = true;
    Logger.info(`LocalRuntimeService started (mode=${this.config.mode})`);

    return this.health();
  }

  async stop(): Promise<void> {
    this.started = false;
    this.generatingSessions = [];
    Logger.info('LocalRuntimeService stopped');
  }

  // ══════════ Health ══════════

  health(): RuntimeHealth {
    const h = new RuntimeHealth();
    h.ok = this.started;
    h.mode = this.config.mode;
    h.version = '0.1.0-local';
    h.message = this.started ? 'Local runtime running' : 'Local runtime not started';
    h.uptime = this.started ? Date.now() - this.startTime : 0;
    return h;
  }

  // ══════════ Config ══════════

  getConfig(): Record<string, Object> {
    const result: Record<string, Object> = {};
    result['mode'] = this.config.mode;
    result['workspace'] = this.config.workspace;
    result['defaultProviderID'] = this.config.defaultProviderID;
    result['defaultModelID'] = this.config.defaultModelID;
    result['providerCount'] = this.providers.length;
    result['sessionCount'] = this.sessions.length;
    return result;
  }

  updateConfig(patch: Record<string, Object>): Record<string, Object> {
    if (typeof patch['workspace'] === 'string') {
      this.config.workspace = patch['workspace'] as string;
    }
    if (typeof patch['defaultProviderID'] === 'string') {
      this.config.defaultProviderID = patch['defaultProviderID'] as string;
    }
    if (typeof patch['defaultModelID'] === 'string') {
      this.config.defaultModelID = patch['defaultModelID'] as string;
    }
    return this.getConfig();
  }

  // ══════════ Providers ══════════

  listProviders(): LocalProviderList {
    const list = new LocalProviderList();
    list.all = this.providers;
    list.connected = this.providers
      .filter(p => p.enabled && p.apiKey.length > 0)
      .map(p => p.id);
    if (this.config.defaultProviderID.length > 0) {
      list.defaults[this.config.defaultProviderID] = this.config.defaultModelID;
    }
    return list;
  }

  async setProviderAuth(providerID: string, apiKey: string): Promise<boolean> {
    const p = this.findProvider(providerID);
    if (p === null) return false;
    p.apiKey = apiKey;
    p.enabled = true;
    await this.saveProviders();
    this.emit({ type: 'provider.updated', sessionID: '', messageID: '', error: '', data: {} });
    return true;
  }

  async removeProviderAuth(providerID: string): Promise<boolean> {
    const p = this.findProvider(providerID);
    if (p === null) return false;
    p.apiKey = '';
    await this.saveProviders();
    return true;
  }

  async addProvider(provider: LocalProviderConfig): Promise<boolean> {
    // Check for duplicate
    const existing = this.findProvider(provider.id);
    if (existing !== null) {
      // Update existing
      existing.name = provider.name;
      existing.protocol = provider.protocol;
      existing.baseURL = provider.baseURL;
      existing.apiKey = provider.apiKey;
      existing.models = provider.models;
      existing.enabled = provider.enabled;
    } else {
      this.providers.push(provider);
    }
    await this.saveProviders();
    return true;
  }

  async removeProvider(providerID: string): Promise<boolean> {
    this.providers = this.providers.filter(p => p.id !== providerID);
    await this.saveProviders();
    return true;
  }

  private findProvider(id: string): LocalProviderConfig | null {
    for (const p of this.providers) {
      if (p.id === id) return p;
    }
    return null;
  }

  // ══════════ Sessions ══════════

  listSessions(): LocalSession[] {
    return this.sessions.sort((a, b) => b.updatedAt - a.updatedAt);
  }

  createSession(input?: Record<string, Object>): LocalSession {
    const s = new LocalSession();
    s.id = `ses_${Date.now()}_${Math.floor(Math.random() * 999999)}`;
    s.title = (input?.['title'] as string) || `Session ${new Date().toLocaleString()}`;
    s.workspace = this.config.workspace;
    s.createdAt = Date.now();
    s.updatedAt = Date.now();

    // Extract model info
    const model = input?.['model'];
    if (model !== undefined && model !== null) {
      if (typeof model === 'string') {
        const parts = (model as string).split('/');
        if (parts.length >= 2) {
          s.providerID = parts[0];
          s.modelID = parts[1];
        }
      } else if (typeof model === 'object') {
        const modelObj = model as Record<string, Object>;
        s.providerID = (modelObj['providerID'] as string) || '';
        s.modelID = (modelObj['id'] as string) || '';
      }
    }

    // Fallback to config defaults
    if (s.providerID.length === 0) s.providerID = this.config.defaultProviderID;
    if (s.modelID.length === 0) s.modelID = this.config.defaultModelID;

    this.sessions.push(s);
    this.messages.set(s.id, []);
    this.saveSessions();

    this.emit({ type: 'session.created', sessionID: s.id, messageID: '', error: '', data: {} });
    return s;
  }

  deleteSession(sessionID: string): boolean {
    const before = this.sessions.length;
    this.sessions = this.sessions.filter(s => s.id !== sessionID);
    this.messages.delete(sessionID);
    if (this.sessions.length < before) {
      this.saveSessions();
      return true;
    }
    return false;
  }

  // ══════════ Messages ══════════

  listMessages(sessionID: string): LocalMessage[] {
    return this.messages.get(sessionID) || [];
  }

  // ══════════ Prompt ══════════

  async sendPrompt(sessionID: string, input: LocalPromptInput): Promise<LocalPromptResult> {
    const result = new LocalPromptResult();

    // Find session
    const session = this.findSession(sessionID);
    if (session === null) {
      result.error = `Session not found: ${sessionID}`;
      return result;
    }

    // Determine provider and model
    let providerID = input.model.providerID;
    let modelID = input.model.id;
    if (providerID.length === 0) providerID = session.providerID;
    if (modelID.length === 0) modelID = session.modelID;

    // Find provider
    const provider = this.findProvider(providerID);
    if (provider === null) {
      result.error = `Provider not found: ${providerID}`;
      return result;
    }
    if (provider.apiKey.length === 0) {
      result.error = `Provider ${providerID} has no API key configured`;
      return result;
    }
    if (!provider.enabled) {
      result.error = `Provider ${providerID} is disabled`;
      return result;
    }

    // Find model
    let model: LocalModelConfig | null = null;
    for (const m of provider.models) {
      if (m.id === modelID) { model = m; break; }
    }
    if (model === null) {
      result.error = `Model not found: ${providerID}/${modelID}`;
      return result;
    }

    // Create user message
    const userMsg = new LocalMessage();
    userMsg.id = `msg_${Date.now()}_user`;
    userMsg.sessionID = sessionID;
    userMsg.role = 'user';
    userMsg.content = input.text;
    userMsg.status = 'completed';
    userMsg.createdAt = Date.now();
    userMsg.updatedAt = Date.now();
    this.addMessage(sessionID, userMsg);

    // Create assistant message (pending)
    const assistantMsg = new LocalMessage();
    assistantMsg.id = `msg_${Date.now()}_assistant`;
    assistantMsg.sessionID = sessionID;
    assistantMsg.role = 'assistant';
    assistantMsg.content = '';
    assistantMsg.status = 'streaming';
    assistantMsg.createdAt = Date.now();
    assistantMsg.updatedAt = Date.now();
    assistantMsg.providerID = providerID;
    assistantMsg.modelID = modelID;
    this.addMessage(sessionID, assistantMsg);

    result.ok = true;
    result.messageID = assistantMsg.id;

    // Update session
    session.updatedAt = Date.now();
    session.messageCount += 2;
    this.saveSessions();

    // Execute prompt asynchronously
    this.executePrompt(session, assistantMsg, provider, model).catch((e: Object) => {
      Logger.error(`executePrompt failed: ${errStr(e)}`);
    });

    return result;
  }

  private async executePrompt(
    session: LocalSession,
    assistantMsg: LocalMessage,
    provider: LocalProviderConfig,
    model: LocalModelConfig
  ): Promise<void> {
    if (!this.generatingSessions.includes(session.id)) {
      this.generatingSessions.push(session.id);
    }

    try {
      // Build messages array for the API
      const history = this.listMessages(session.id);
      const apiMessages: Record<string, Object>[] = [];
      for (const msg of history) {
        if (msg.id === assistantMsg.id) continue; // Skip the pending assistant message
        if (msg.role === 'user' || msg.role === 'assistant' || msg.role === 'system') {
          const m: Record<string, Object> = {};
          m['role'] = msg.role;
          m['content'] = msg.content;
          apiMessages.push(m);
        }
      }

      // Check if aborted before calling API
      if (!this.generatingSessions.includes(session.id)) {
        assistantMsg.status = 'aborted';
        assistantMsg.updatedAt = Date.now();
        return;
      }

      // Call the provider API
      const response = await this.callProviderAPI(provider, model, apiMessages, session.id);

      // Check if aborted during API call
      if (!this.generatingSessions.includes(session.id)) {
        assistantMsg.status = 'aborted';
        assistantMsg.updatedAt = Date.now();
        return;
      }

      if (response.ok) {
        assistantMsg.content = response.content;
        assistantMsg.status = 'completed';
        assistantMsg.updatedAt = Date.now();
        this.emit({ type: 'message.completed', sessionID: session.id, messageID: assistantMsg.id, error: '', data: {} });
      } else {
        assistantMsg.error = response.error;
        assistantMsg.status = 'error';
        assistantMsg.updatedAt = Date.now();
        this.emit({ type: 'message.error', sessionID: session.id, messageID: assistantMsg.id, error: response.error, data: {} });
      }
    } catch (e) {
      assistantMsg.error = errStr(e);
      assistantMsg.status = 'error';
      assistantMsg.updatedAt = Date.now();
      this.emit({ type: 'message.error', sessionID: session.id, messageID: assistantMsg.id, error: errStr(e), data: {} });
    } finally {
      this.generatingSessions = this.generatingSessions.filter(s => s !== session.id);
      this.saveMessages(session.id);
    }
  }

  private async callProviderAPI(
    provider: LocalProviderConfig,
    model: LocalModelConfig,
    messages: Record<string, Object>[],
    sessionID: string = ''
  ): Promise<ProviderCallResult> {
    // Only support OpenAI-compatible for now
    if (provider.protocol !== 'openai-compatible') {
      return { ok: false, content: '', error: `Unsupported protocol: ${provider.protocol}` };
    }

    const url = `${provider.baseURL}/chat/completions`;
    const body: Record<string, Object> = {};
    body['model'] = model.id;
    body['messages'] = messages;
    body['stream'] = false; // Non-streaming for v1

    const result = new ProviderCallResult();
    try {
      const req = http.createHttp();
      try {
        const headers: Record<string, string> = {};
        headers['Content-Type'] = 'application/json';
        headers['Authorization'] = `Bearer ${provider.apiKey}`;

        // Add custom headers
        const customKeys = Object.keys(provider.headers);
        for (let i = 0; i < customKeys.length; i++) {
          headers[customKeys[i]] = provider.headers[customKeys[i]];
        }

        const response = await req.request(url, {
          method: http.RequestMethod.POST,
          header: headers,
          connectTimeout: 30000,
          readTimeout: 120000,
          extraData: JSON.stringify(body),
          expectDataType: http.HttpDataType.STRING
        });

        if (response.responseCode >= 200 && response.responseCode < 300) {
          const rawStr = response.result as string;
          let data: Record<string, Object> = {};
          try {
            data = JSON.parse(rawStr) as Record<string, Object>;
          } catch (parseErr) {
            result.error = `JSON parse error: ${errStr(parseErr)}`;
            return result;
          }

          const choices = data['choices'] as Object[];
          if (choices !== undefined && choices !== null && choices.length > 0) {
            const choice = choices[0] as Record<string, Object>;
            const message = choice['message'] as Record<string, Object>;
            if (message !== undefined && message !== null) {
              const content = message['content'] as string;
              result.ok = true;
              result.content = content || '';
              return result;
            }
          }
          result.error = `No content in response: ${rawStr.substring(0, 200)}`;
          return result;
        } else {
          let errorMsg = `HTTP ${response.responseCode}`;
          try {
            const rawStr = response.result as string;
            const errData = JSON.parse(rawStr) as Record<string, Object>;
            const errObj = errData['error'] as Record<string, Object>;
            if (errObj !== undefined && errObj !== null) {
              errorMsg = (errObj['message'] as string) || errorMsg;
            }
          } catch (_) {}
          result.error = errorMsg;
          return result;
        }
      } finally {
        req.destroy();
      }
    } catch (e) {
      result.error = errStr(e);
      return result;
    }
  }

  // ══════════ Abort ══════════

  abortSession(sessionID: string): boolean {
    if (this.generatingSessions.includes(sessionID)) {
      this.generatingSessions = this.generatingSessions.filter(s => s !== sessionID);
      // Mark the last assistant message as aborted
      const msgs = this.messages.get(sessionID);
      if (msgs !== undefined) {
        for (let i = msgs.length - 1; i >= 0; i--) {
          if (msgs[i].role === 'assistant' && msgs[i].status === 'streaming') {
            msgs[i].status = 'aborted';
            msgs[i].updatedAt = Date.now();
            break;
          }
        }
      }
      return true;
    }
    return false;
  }

  // ══════════ Event Bus ══════════

  addEventListener(listener: EventListener): void {
    this.listeners.push(listener);
  }

  removeEventListener(listener: EventListener): void {
    this.listeners = this.listeners.filter(l => l !== listener);
  }

  private emit(event: RuntimeEvent): void {
    for (const listener of this.listeners) {
      try {
        listener(event);
      } catch (e) {
        Logger.warn(`Event listener error: ${errStr(e)}`);
      }
    }
  }

  // ══════════ Permission Engine (Step 7) ══════════

  private pendingPermissions: Map<string, LocalPermissionRequest> = new Map();

  /**
   * Request permission for a tool operation.
   * Returns a permission request that must be approved before execution.
   */
  requestPermission(sessionID: string, toolName: string, summary: string, payload: Record<string, Object>): LocalPermissionRequest {
    const req = new LocalPermissionRequest();
    req.id = `perm_${Date.now()}_${Math.floor(Math.random() * 999999)}`;
    req.sessionID = sessionID;
    req.toolName = toolName;
    req.summary = summary;
    req.payload = payload;
    req.status = 'pending';
    req.createdAt = Date.now();

    this.pendingPermissions.set(req.id, req);
    this.emit({ type: 'permission.requested', sessionID: sessionID, messageID: req.id, error: '', data: {} });

    return req;
  }

  /**
   * Approve a permission request.
   */
  approvePermission(permissionID: string): boolean {
    const req = this.pendingPermissions.get(permissionID);
    if (req === undefined) return false;
    req.status = 'approved';
    this.pendingPermissions.delete(permissionID);
    this.emit({ type: 'permission.approved', sessionID: req.sessionID, messageID: permissionID, error: '', data: {} });
    return true;
  }

  /**
   * Deny a permission request.
   */
  denyPermission(permissionID: string): boolean {
    const req = this.pendingPermissions.get(permissionID);
    if (req === undefined) return false;
    req.status = 'denied';
    this.pendingPermissions.delete(permissionID);
    this.emit({ type: 'permission.denied', sessionID: req.sessionID, messageID: permissionID, error: '', data: {} });
    return true;
  }

  /**
   * List pending permission requests.
   */
  listPendingPermissions(): LocalPermissionRequest[] {
    const result: LocalPermissionRequest[] = [];
    const keys: string[] = [];
    this.pendingPermissions.forEach((_value: LocalPermissionRequest, key: string) => { keys.push(key); });
    for (let i = 0; i < keys.length; i++) {
      const req = this.pendingPermissions.get(keys[i]);
      if (req !== undefined) {
        result.push(req);
      }
    }
    return result;
  }

  /**
   * Write file with permission check.
   */
  async writeFile(filePath: string, content: string, sessionID: string = ''): Promise<WriteFileResult> {
    const result = new WriteFileResult();
    // Request permission for write operations
    if (sessionID.length > 0) {
      const payload: Record<string, Object> = {};
      payload['path'] = filePath;
      payload['contentLength'] = content.length;
      const perm = this.requestPermission(sessionID, 'write_file', `Write to ${filePath}`, payload);

      // Wait for approval (up to 60 seconds)
      for (let i = 0; i < 60; i++) {
        await this.delay(1000);
        if (perm.status === 'approved') break;
        if (perm.status === 'denied') { result.error = 'Permission denied by user'; return result; }
        if (perm.status === 'expired') { result.error = 'Permission request expired'; return result; }
      }
      if (perm.status === 'pending') {
        perm.status = 'expired';
        result.error = 'Permission request timed out';
        return result;
      }
    }

    try {
      const fullPath = this.resolvePath(filePath);

      if (fullPath.includes('..')) {
        result.error = 'Path traversal not allowed';
        return result;
      }

      fileIo.writeTextSync(fullPath, content);
      result.ok = true;
      return result;
    } catch (e) {
      result.error = errStr(e);
      return result;
    }
  }

  // ══════════ Tools (Read-only, Step 6) ══════════

  /**
   * Read file content from the workspace.
   */
  async readFile(filePath: string): Promise<ReadFileResult> {
    const result = new ReadFileResult();
    try {
      const fullPath = this.resolvePath(filePath);

      if (fullPath.includes('..')) {
        result.error = 'Path traversal not allowed';
        return result;
      }

      const stat = fileIo.statSync(fullPath);
      if (!stat.isFile()) {
        result.error = 'Not a file';
        return result;
      }

      result.content = fileIo.readTextSync(fullPath);
      result.ok = true;
      return result;
    } catch (e) {
      result.error = errStr(e);
      return result;
    }
  }

  /**
   * List directory contents.
   */
  async listDirectory(dirPath: string): Promise<ListDirResult> {
    const result = new ListDirResult();
    try {
      const fullPath = this.resolvePath(dirPath);

      if (fullPath.includes('..')) {
        result.error = 'Path traversal not allowed';
        return result;
      }

      const entries: Record<string, Object>[] = [];
      const dir = fileIo.listFileSync(fullPath);

      for (let i = 0; i < dir.length; i++) {
        const name = dir[i] as string;
        const entryPath = `${fullPath}/${name}`;
        try {
          const stat = statSync(entryPath);
          const entry: Record<string, Object> = {};
          entry['name'] = name;
          entry['path'] = entryPath;
          entry['type'] = stat.isDirectory() ? 'directory' : 'file';
          entry['size'] = stat.size;
          entries.push(entry);
        } catch (_) {}
      }

      result.ok = true;
      result.entries = entries;
      return result;
    } catch (e) {
      result.error = errStr(e);
      return result;
    }
  }

  /**
   * Search for text in workspace files.
   */
  async searchText(query: string, dirPath: string = ''): Promise<SearchResult> {
    const result = new SearchResult();
    try {
      const searchDir = dirPath.length > 0 ? this.resolvePath(dirPath) : this.config.workspace;
      if (searchDir.length === 0) {
        result.error = 'No workspace configured';
        return result;
      }

      const matches: Record<string, Object>[] = [];
      this.searchInDirSync(searchDir, query, matches, 0, 50);

      result.ok = true;
      result.matches = matches;
      return result;
    } catch (e) {
      result.error = errStr(e);
      return result;
    }
  }

  private searchInDirSync(dirPath: string, query: string, matches: Record<string, Object>[], depth: number, maxResults: number): void {
    if (depth > 3 || matches.length >= maxResults) return;

    try {
      const entries = fileIo.listFileSync(dirPath);

      for (const name of entries) {
        if (matches.length >= maxResults) break;
        if (name.startsWith('.') || name === 'node_modules' || name === '.git') continue;

        const fullPath = `${dirPath}/${name}`;
        try {
          const stat = fileIo.statSync(fullPath);
          if (stat.isDirectory()) {
            this.searchInDirSync(fullPath, query, matches, depth + 1, maxResults);
          } else if (stat.isFile() && this.isTextFile(name)) {
            const content = fileIo.readTextSync(fullPath);
            const lines = content.split('\n');
            for (let i = 0; i < lines.length; i++) {
              if (lines[i].toLowerCase().includes(query.toLowerCase())) {
                const match: Record<string, Object> = {};
                match['file'] = fullPath;
                match['line'] = i + 1;
                match['content'] = lines[i].trim();
                matches.push(match);
                if (matches.length >= maxResults) break;
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  private isTextFile(name: string): boolean {
    const textExts = ['.ts', '.js', '.json', '.md', '.txt', '.py', '.go', '.rs', '.java', '.c', '.cpp', '.h', '.css', '.html', '.xml', '.yaml', '.yml', '.toml', '.ets', '.arkts'];
    const lower = name.toLowerCase();
    for (const ext of textExts) {
      if (lower.endsWith(ext)) return true;
    }
    return !lower.includes('.');
  }

  private resolvePath(path: string): string {
    if (path.startsWith('/')) return path;
    if (this.config.workspace.length > 0) return `${this.config.workspace}/${path}`;
    return path;
  }

  // ══════════ ProviderRegistry Sync ══════════

  /**
   * Sync providers from ProviderRegistry to LocalRuntimeService.
   * Called on startup to ensure local runtime has the latest provider configs.
   */
  async syncFromProviderRegistry(): Promise<void> {
    await providerRegistry.init();
    const cnProviders = providerRegistry.getEnabled();

    for (const cn of cnProviders) {
      const existing = this.findProvider(cn.id);
      const local = existing !== null ? existing : new LocalProviderConfig();

      local.id = cn.id;
      local.name = cn.name;
      local.enabled = cn.enabled;
      local.baseURL = cn.baseURL;
      local.apiKey = cn.apiKey;
      local.protocol = 'openai-compatible'; // All current providers are OpenAI-compatible

      // Sync models
      local.models = [];
      for (const m of cn.models) {
        if (m.enabled === false) continue;
        const mc = new LocalModelConfig();
        mc.id = m.id;
        mc.name = m.name;
        mc.contextLength = m.context || 128000;
        mc.maxOutputTokens = m.maxTokens || 8192;
        local.models.push(mc);
      }

      if (existing === null) {
        this.providers.push(local);
      }
    }

    // Remove providers that no longer exist in registry
    const registryIds = cnProviders.map(p => p.id);
    this.providers = this.providers.filter(p => registryIds.includes(p.id) || p.id.startsWith('custom-'));

    await this.saveProviders();
    Logger.info(`syncFromProviderRegistry: ${this.providers.length} providers synced`);
  }

  /**
   * Save API key back to ProviderRegistry.
   */
  async syncApiKeyToRegistry(providerID: string, apiKey: string): Promise<void> {
    try {
      await providerRegistry.setApiKey(providerID, apiKey, 'direct');
      // Also update local provider
      const p = this.findProvider(providerID);
      if (p !== null) {
        p.apiKey = apiKey;
        await this.saveProviders();
      }
    } catch (e) {
      Logger.warn(`syncApiKeyToRegistry failed: ${errStr(e)}`);
    }
  }

  // ══════════ Storage ══════════

  private async loadProviders(): Promise<void> {
    try {
      const raw = await storageService.getString('local_providers', '[]');
      const arr = JSON.parse(raw) as Object[];
      this.providers = [];
      for (const item of arr) {
        const r = item as Record<string, Object>;
        const p = new LocalProviderConfig();
        p.id = (r['id'] as string) || '';
        p.name = (r['name'] as string) || '';
        p.enabled = r['enabled'] !== false;
        p.protocol = (r['protocol'] as string) || 'openai-compatible';
        p.baseURL = (r['baseURL'] as string) || '';
        p.apiKey = (r['apiKey'] as string) || '';
        p.apiKeyEnv = (r['apiKeyEnv'] as string) || '';
        if (r['headers'] !== undefined && typeof r['headers'] === 'object') {
          p.headers = r['headers'] as Record<string, string>;
        }
        const modelsRaw = r['models'] as Object[];
        if (Array.isArray(modelsRaw)) {
          for (const m of modelsRaw) {
            const mr = m as Record<string, Object>;
            const mc = new LocalModelConfig();
            mc.id = (mr['id'] as string) || '';
            mc.name = (mr['name'] as string) || '';
            mc.contextLength = (mr['contextLength'] as number) || 128000;
            mc.maxOutputTokens = (mr['maxOutputTokens'] as number) || 8192;
            mc.supportsTools = mr['supportsTools'] === true;
            mc.supportsReasoning = mr['supportsReasoning'] === true;
            mc.supportsVision = mr['supportsVision'] === true;
            p.models.push(mc);
          }
        }
        if (p.id.length > 0) this.providers.push(p);
      }
    } catch (e) {
      Logger.warn(`loadProviders failed: ${errStr(e)}`);
    }

    // If no providers, load defaults
    if (this.providers.length === 0) {
      this.loadDefaultProviders();
    }
  }

  private loadDefaultProviders(): void {
    // DeepSeek
    const deepseek = new LocalProviderConfig();
    deepseek.id = 'deepseek';
    deepseek.name = 'DeepSeek';
    deepseek.protocol = 'openai-compatible';
    deepseek.baseURL = 'https://api.deepseek.com/v1';
    deepseek.models = [
      this.makeModel('deepseek-chat', 'DeepSeek V3', 128000, 8192, true, false, false),
      this.makeModel('deepseek-reasoner', 'DeepSeek R1', 128000, 8192, false, true, false),
    ];
    this.providers.push(deepseek);

    // OpenAI
    const openai = new LocalProviderConfig();
    openai.id = 'openai';
    openai.name = 'OpenAI';
    openai.protocol = 'openai-compatible';
    openai.baseURL = 'https://api.openai.com/v1';
    openai.models = [
      this.makeModel('gpt-4o', 'GPT-4o', 128000, 16384, true, false, true),
      this.makeModel('gpt-4o-mini', 'GPT-4o Mini', 128000, 16384, true, false, true),
      this.makeModel('o3-mini', 'o3-mini', 200000, 100000, true, true, false),
    ];
    this.providers.push(openai);

    // Xiaomi MiMo
    const mimo = new LocalProviderConfig();
    mimo.id = 'xiaomi-mimo';
    mimo.name = 'Xiaomi MiMo';
    mimo.protocol = 'openai-compatible';
    mimo.baseURL = 'https://token-plan-cn.xiaomimimo.com/v1';
    mimo.models = [
      this.makeModel('mimo-v2.5-pro', 'MiMo v2.5 Pro', 1000000, 16384, true, false, false),
      this.makeModel('mimo-v2.5', 'MiMo v2.5', 1000000, 16384, true, false, false),
    ];
    this.providers.push(mimo);
  }

  private makeModel(id: string, name: string, ctx: number, out: number, tools: boolean, reasoning: boolean, vision: boolean): LocalModelConfig {
    const m = new LocalModelConfig();
    m.id = id;
    m.name = name;
    m.contextLength = ctx;
    m.maxOutputTokens = out;
    m.supportsTools = tools;
    m.supportsReasoning = reasoning;
    m.supportsVision = vision;
    return m;
  }

  private async saveProviders(): Promise<void> {
    try {
      await storageService.setString('local_providers', JSON.stringify(this.providers));
    } catch (e) {
      Logger.warn(`saveProviders failed: ${errStr(e)}`);
    }
  }

  private async loadSessions(): Promise<void> {
    try {
      const raw = await storageService.getString('local_sessions', '[]');
      const arr = JSON.parse(raw) as Object[];
      this.sessions = [];
      for (const item of arr) {
        const r = item as Record<string, Object>;
        const s = new LocalSession();
        s.id = (r['id'] as string) || '';
        s.title = (r['title'] as string) || '';
        s.workspace = (r['workspace'] as string) || '';
        s.providerID = (r['providerID'] as string) || '';
        s.modelID = (r['modelID'] as string) || '';
        s.createdAt = (r['createdAt'] as number) || 0;
        s.updatedAt = (r['updatedAt'] as number) || 0;
        s.messageCount = (r['messageCount'] as number) || 0;
        if (s.id.length > 0) this.sessions.push(s);
      }

      // Load messages for each session
      for (const s of this.sessions) {
        await this.loadMessages(s.id);
      }
    } catch (e) {
      Logger.warn(`loadSessions failed: ${errStr(e)}`);
    }
  }

  private async saveSessions(): Promise<void> {
    try {
      await storageService.setString('local_sessions', JSON.stringify(this.sessions));
    } catch (e) {
      Logger.warn(`saveSessions failed: ${errStr(e)}`);
    }
  }

  private async loadMessages(sessionID: string): Promise<void> {
    try {
      const raw = await storageService.getString(`local_messages_${sessionID}`, '[]');
      const arr = JSON.parse(raw) as Object[];
      const msgs: LocalMessage[] = [];
      for (const item of arr) {
        const r = item as Record<string, Object>;
        const m = new LocalMessage();
        m.id = (r['id'] as string) || '';
        m.sessionID = (r['sessionID'] as string) || '';
        m.role = (r['role'] as string) || 'user';
        m.content = (r['content'] as string) || '';
        m.status = (r['status'] as string) || 'completed';
        m.createdAt = (r['createdAt'] as number) || 0;
        m.updatedAt = (r['updatedAt'] as number) || 0;
        m.error = (r['error'] as string) || '';
        m.providerID = (r['providerID'] as string) || '';
        m.modelID = (r['modelID'] as string) || '';
        if (m.id.length > 0) msgs.push(m);
      }
      this.messages.set(sessionID, msgs);
    } catch (e) {
      this.messages.set(sessionID, []);
    }
  }

  private async saveMessages(sessionID: string): Promise<void> {
    try {
      const msgs = this.messages.get(sessionID) || [];
      await storageService.setString(`local_messages_${sessionID}`, JSON.stringify(msgs));
    } catch (e) {
      Logger.warn(`saveMessages failed: ${errStr(e)}`);
    }
  }

  private addMessage(sessionID: string, msg: LocalMessage): void {
    const msgs = this.messages.get(sessionID);
    if (msgs !== undefined) {
      msgs.push(msg);
    } else {
      this.messages.set(sessionID, [msg]);
    }
    this.emit({
      type: msg.status === 'streaming' ? 'message.created' : 'message.updated',
      sessionID: sessionID,
      messageID: msg.id,
      error: '',
      data: {}
    });
  }

  private findSession(id: string): LocalSession | null {
    for (const s of this.sessions) {
      if (s.id === id) return s;
    }
    return null;
  }

  // ══════════ Default Model Ref ══════════

  getDefaultModelRef(): LocalModelRef {
    const ref = new LocalModelRef();
    ref.providerID = this.config.defaultProviderID;
    ref.id = this.config.defaultModelID;
    return ref;
  }

  setDefaultModel(providerID: string, modelID: string): void {
    this.config.defaultProviderID = providerID;
    this.config.defaultModelID = modelID;
  }
}

export const localRuntimeService = new LocalRuntimeService();
