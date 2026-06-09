import { HttpService } from '../service/HttpService';
import { WebSocketService } from '../service/WebSocketService';
import { StorageService } from '../service/StorageService';
import { ServerInfo } from '../model/ServerInfo';
import { ChatMessage, MessageRole, MessageStatus, ToolCall } from '../model/ChatMessage';
import { ConnectionStatus, SessionInfo, ProviderInfo } from '../model/AppState';
import { Constants } from '../utils/Constants';
import { Logger } from '../utils/Logger';

export class MainViewModel {
  httpService: HttpService = new HttpService();
  wsService: WebSocketService = new WebSocketService();
  storageService: StorageService | null = null;

  connectionStatus: ConnectionStatus = ConnectionStatus.Disconnected;
  serverInfo: ServerInfo = new ServerInfo();
  messages: ChatMessage[] = [];
  sessions: SessionInfo[] = [];
  currentSessionId: string = '';
  providers: ProviderInfo[] = [];
  selectedModel: string = Constants.DEFAULT_MODEL;
  isGenerating: boolean = false;
  errorMessage: string = '';

  private healthTimer: number = -1;

  async init(storage: StorageService): Promise<void> {
    this.storageService = storage;
    const savedUrl = await storage.getString(Constants.KEY_SERVER_URL, Constants.DEFAULT_SERVER_URL);
    const savedUsername = await storage.getString(Constants.KEY_AUTH_USERNAME, '');
    const savedPassword = await storage.getString(Constants.KEY_AUTH_PASSWORD, '');
    const savedModel = await storage.getString(Constants.KEY_MODEL, Constants.DEFAULT_MODEL);
    const savedSessionId = await storage.getString(Constants.KEY_SESSION_ID, '');

    this.serverInfo.url = savedUrl.length > 0 ? savedUrl : Constants.DEFAULT_SERVER_URL;
    this.serverInfo.username = savedUsername;
    this.serverInfo.password = savedPassword;
    this.serverInfo.displayName = 'Local OpenCode Runtime';
    this.serverInfo.type = 'local';
    this.selectedModel = savedModel;
    this.currentSessionId = savedSessionId;

    this.httpService.setServer(this.serverInfo);
    this.wsService.setServer(this.serverInfo);
    this.wsService.setMessageHandler(this.onWsMessage.bind(this));
    this.wsService.setStatusHandler(this.onWsStatus.bind(this));
    Logger.info('MainViewModel initialized with Runtime: %{public}s', this.serverInfo.url);
  }

  async connect(): Promise<void> {
    this.connectionStatus = ConnectionStatus.Connecting;
    this.errorMessage = '';
    try {
      this.httpService.setServer(this.serverInfo);
      const healthy = await this.httpService.checkHealth();
      if (!healthy) {
        this.connectionStatus = ConnectionStatus.Error;
        this.errorMessage = '本地 Runtime 健康检查失败。请确认 opencode serve 已启动。';
        return;
      }
      this.connectionStatus = ConnectionStatus.Connected;
      this.serverInfo.connected = true;
      this.serverInfo.healthOk = true;
      try {
        this.wsService.setServer(this.serverInfo);
        this.wsService.connect();
      } catch (e) {
        Logger.warn('Optional WebSocket connect skipped/failed: %{public}s', String(e));
      }
      await this.loadSessions();
      await this.loadProviders();
      if (this.currentSessionId.length > 0) await this.loadMessages(this.currentSessionId);
      this.startHealthCheck();
      Logger.info('Connected to Runtime: %{public}s', this.serverInfo.url);
    } catch (err) {
      this.connectionStatus = ConnectionStatus.Error;
      this.errorMessage = String(err);
      Logger.error('Connection failed: %{public}s', String(err));
    }
  }

  disconnect(): void {
    this.wsService.disconnect();
    this.stopHealthCheck();
    this.connectionStatus = ConnectionStatus.Disconnected;
    this.serverInfo.connected = false;
    Logger.info('Disconnected from Runtime');
  }

  async loadSessions(): Promise<void> {
    try {
      const result = await this.httpService.get<Object>(Constants.API_SESSION);
      const rawSessions: Object[] = this.extractArray(result, ['sessions', 'data']);
      const next: SessionInfo[] = [];
      for (const item of rawSessions) next.push(SessionInfo.fromJson(item as Record<string, Object>));
      this.sessions = next;
    } catch (err) {
      Logger.error('loadSessions failed: %{public}s', String(err));
    }
  }

  async loadProviders(): Promise<void> {
    try {
      const result = await this.httpService.get<Record<string, Object>>(Constants.API_PROVIDER);
      const connected = this.extractStringArray(result['connected']);
      const all = this.extractArray(result['all'], ['providers', 'data']);
      const next: ProviderInfo[] = [];
      for (const item of all) next.push(ProviderInfo.fromJson(item as Record<string, Object>, connected));
      this.providers = next;
    } catch (err) {
      Logger.error('loadProviders failed: %{public}s', String(err));
    }
  }

  async createSession(): Promise<string> {
    try {
      const result = await this.httpService.post<Record<string, Object>>(Constants.API_SESSION, {});
      const id = (result['id'] as string) ?? '';
      if (id.length > 0) {
        this.currentSessionId = id;
        await this.storageService?.setString(Constants.KEY_SESSION_ID, id);
        await this.loadSessions();
      }
      return id;
    } catch (err) {
      Logger.error('createSession failed: %{public}s', String(err));
      this.errorMessage = String(err);
      return '';
    }
  }

  async selectSession(sessionId: string): Promise<void> {
    this.currentSessionId = sessionId;
    await this.storageService?.setString(Constants.KEY_SESSION_ID, sessionId);
    await this.loadMessages(sessionId);
  }

  async loadMessages(sessionId: string = this.currentSessionId): Promise<void> {
    if (sessionId.length === 0) return;
    try {
      const raw = await this.httpService.get<Object>(Constants.sessionMessages(sessionId));
      const arr = this.extractArray(raw, ['messages', 'data']);
      this.messages = this.normalizeOpenCodeMessages(arr, sessionId);
    } catch (err) {
      Logger.error('loadMessages failed: %{public}s', String(err));
    }
  }

  async sendMessage(content: string): Promise<void> {
    const text = content.trim();
    if (text.length === 0 || this.isGenerating) return;
    if (this.connectionStatus !== ConnectionStatus.Connected) {
      this.messages = [...this.messages, ChatMessage.createErrorMessage('本地 Runtime 未连接。请先连接或启动本地 OpenCode Runtime。')];
      return;
    }
    let sessionId = this.currentSessionId;
    if (sessionId.length === 0) {
      sessionId = await this.createSession();
      if (sessionId.length === 0) {
        this.messages = [...this.messages, ChatMessage.createErrorMessage('创建 session 失败，无法发送消息。')];
        return;
      }
    }
    const userMsg = ChatMessage.createUserMessage(text);
    userMsg.sessionId = sessionId;
    this.messages = [...this.messages, userMsg];
    const assistantMsg = ChatMessage.createAssistantMessage('等待 Runtime 响应...');
    assistantMsg.sessionId = sessionId;
    this.messages = [...this.messages, assistantMsg];
    this.isGenerating = true;
    this.errorMessage = '';
    try {
      await this.syncModelToRuntime();
      const beforeRaw = await this.getRawMessages(sessionId);
      const beforeCount = beforeRaw.length;
      Logger.info('prompt_async beforeCount=%{public}d model=%{public}s', beforeCount, this.selectedModel);
      const body: Record<string, Object> = {};
      body['agent'] = 'build';
      body['parts'] = [{ 'type': 'text', 'text': text }];
      await this.httpService.post<Object>(Constants.sessionPromptAsync(sessionId), body);
      Logger.info('prompt_async sent session=%{public}s', sessionId);
      await this.loadMessages(sessionId);
      const poll = await this.waitForExecution(sessionId, beforeCount);
      await this.loadMessages(sessionId);
      if (!poll.ok) {
        const err = ChatMessage.createErrorMessage(poll.message);
        err.sessionId = sessionId;
        this.messages = [...this.messages, err];
        this.errorMessage = poll.message;
      }
      await this.loadSessions();
    } catch (err) {
      const msg = String(err);
      assistantMsg.setError(msg);
      this.errorMessage = msg;
      this.messages = [...this.messages];
      Logger.error('sendMessage failed: %{public}s', msg);
    } finally {
      this.isGenerating = false;
      const last = this.messages.length > 0 ? this.messages[this.messages.length - 1] : null;
      if (last && last.role === MessageRole.Assistant && last.isStreaming) {
        last.finalize();
        this.messages = [...this.messages];
      }
    }
  }

  async stopGeneration(): Promise<void> {
    if (!this.isGenerating || this.currentSessionId.length === 0) return;
    try { await this.httpService.post<Object>(Constants.sessionAbort(this.currentSessionId), {}); }
    catch (err) { Logger.error('stopGeneration failed: %{public}s', String(err)); }
    finally { this.isGenerating = false; }
  }

  async saveServerConfig(): Promise<void> {
    if (!this.storageService) return;
    await this.storageService.setString(Constants.KEY_SERVER_URL, this.serverInfo.url);
    await this.storageService.setString(Constants.KEY_AUTH_USERNAME, this.serverInfo.username);
    await this.storageService.setString(Constants.KEY_AUTH_PASSWORD, this.serverInfo.password);
    await this.storageService.setString(Constants.KEY_MODEL, this.selectedModel);
  }

  async testModel(): Promise<string> {
    if (this.selectedModel.length === 0) return '未设置模型。请先填写 providerId/modelId。';
    const oldSession = this.currentSessionId;
    try {
      const sessionId = await this.createSession();
      if (sessionId.length === 0) return '创建测试 session 失败。';
      await this.syncModelToRuntime();
      const before = await this.getRawMessages(sessionId);
      const body: Record<string, Object> = {};
      body['agent'] = 'build';
      body['parts'] = [{ 'type': 'text', 'text': 'Say OK.' }];
      await this.httpService.post<Object>(Constants.sessionPromptAsync(sessionId), body);
      const poll = await this.waitForExecution(sessionId, before.length, 30, 1000);
      await this.loadMessages(sessionId);
      if (poll.ok) return `模型测试成功：${this.selectedModel}`;
      return `模型测试失败：${poll.message}`;
    } catch (err) {
      return `模型测试失败：${String(err)}`;
    } finally {
      if (oldSession.length > 0) this.currentSessionId = oldSession;
    }
  }

  private async syncModelToRuntime(): Promise<void> {
    if (this.selectedModel.length === 0) {
      Logger.warn('No selected model configured. Runtime will use current config.model.');
      return;
    }
    const patch: Record<string, Object> = {};
    patch['model'] = this.selectedModel;
    await this.httpService.patch<Object>(Constants.API_CONFIG, patch);
    await this.storageService?.setString(Constants.KEY_MODEL, this.selectedModel);
    Logger.info('Runtime model synced: %{public}s', this.selectedModel);
  }

  private async getRawMessages(sessionId: string): Promise<Object[]> {
    const raw = await this.httpService.get<Object>(Constants.sessionMessages(sessionId));
    return this.extractArray(raw, ['messages', 'data']);
  }

  private async waitForExecution(sessionId: string, beforeCount: number, maxAttempts: number = Constants.POLL_MAX_ATTEMPTS, intervalMs: number = Constants.POLL_INTERVAL_MS): Promise<ExecutionPollResult> {
    const result = new ExecutionPollResult();
    for (let i = 0; i < maxAttempts; i++) {
      await this.delay(intervalMs);
      try {
        const raw = await this.getRawMessages(sessionId);
        result.messageCount = raw.length;
        if (raw.length > beforeCount) {
          const status = this.inspectMessages(raw, beforeCount);
          result.hasAssistant = status.hasAssistant;
          result.hasTool = status.hasTool;
          result.hasError = status.hasError;
          result.hasPermission = status.hasPermission;
          if (status.hasError) { result.ok = false; result.message = status.errorText.length > 0 ? status.errorText : 'Runtime 返回错误。'; return result; }
          if (status.hasPermission) { result.ok = true; result.message = 'Runtime 正在等待权限确认。'; return result; }
          if (status.hasTool) { result.ok = true; result.message = 'Runtime 已开始工具调用。'; return result; }
          if (status.hasAssistant) { result.ok = true; result.message = 'assistant response received'; return result; }
        }
      } catch (err) {
        result.ok = false; result.message = `轮询消息失败：${String(err)}`; return result;
      }
    }
    result.ok = false; result.timedOut = true; result.message = '等待 assistant/tool/error/permission 超时。消息可能已发出，但 Runtime 没有完成执行。';
    return result;
  }

  private inspectMessages(raw: Object[], beforeCount: number): ExecutionPollResult {
    const result = new ExecutionPollResult();
    for (let i = beforeCount; i < raw.length; i++) {
      const item = raw[i] as Record<string, Object>;
      const info = item['info'] as Record<string, Object>;
      const role = info ? (info['role'] as string) : '';
      if (role === 'assistant') result.hasAssistant = true;
      const parts = item['parts'] as Object[];
      if (!parts) continue;
      for (const partAny of parts) {
        const part = partAny as Record<string, Object>;
        const type = (part['type'] as string) ?? '';
        const text = this.extractPartText(part);
        if (this.isToolType(type)) result.hasTool = true;
        if (this.isPermissionType(type)) result.hasPermission = true;
        if (this.isErrorType(type) || this.looksLikeError(text)) {
          result.hasError = true;
          if (result.errorText.length === 0) result.errorText = text.length > 0 ? text : `Runtime error part: ${type}`;
        }
      }
    }
    return result;
  }

  private normalizeOpenCodeMessages(raw: Object[], sessionId: string): ChatMessage[] {
    const out: ChatMessage[] = [];
    for (const itemAny of raw) {
      const item = itemAny as Record<string, Object>;
      const info = item['info'] as Record<string, Object>;
      const roleStr = info ? ((info['role'] as string) ?? '') : '';
      const id = info ? ((info['id'] as string) ?? '') : '';
      const parts = (item['parts'] as Object[]) ?? [];
      const msg = new ChatMessage();
      msg.id = id.length > 0 ? id : 'msg_' + Date.now().toString() + '_' + out.length.toString();
      msg.sessionId = sessionId;
      msg.role = roleStr === 'assistant' ? MessageRole.Assistant : MessageRole.User;
      msg.timestamp = Date.now();
      msg.status = MessageStatus.Complete;
      msg.isStreaming = false;
      const textParts: string[] = [];
      for (const partAny of parts) {
        const part = partAny as Record<string, Object>;
        const type = (part['type'] as string) ?? '';
        const text = this.extractPartText(part);
        if (type === 'text' && text.length > 0) textParts.push(text);
        else if (this.isErrorType(type) || this.looksLikeError(text)) { msg.isError = true; msg.status = MessageStatus.Error; textParts.push(text.length > 0 ? text : `Runtime error: ${type}`); }
        else if (this.isToolType(type)) {
          const tool = new ToolCall();
          tool.id = ((part['id'] as string) ?? (part['callID'] as string) ?? '');
          tool.name = ((part['tool'] as string) ?? (part['name'] as string) ?? type);
          tool.arguments = JSON.stringify(part['input'] ?? part['args'] ?? part['state'] ?? {});
          tool.result = text;
          tool.status = type.includes('error') ? 'error' : 'complete';
          msg.toolCalls.push(tool);
        } else if (text.length > 0) textParts.push(text);
      }
      msg.content = textParts.join('\n\n');
      if (msg.content.length === 0 && msg.toolCalls.length > 0) msg.content = `[${msg.toolCalls.length} tool call(s)]`;
      if (msg.content.length > 0 || msg.toolCalls.length > 0) out.push(msg);
    }
    return out;
  }

  private extractArray(value: Object, keys: string[]): Object[] {
    if (Array.isArray(value)) return value as Object[];
    if (!value || typeof value !== 'object') return [];
    const rec = value as Record<string, Object>;
    for (const key of keys) { const candidate = rec[key]; if (Array.isArray(candidate)) return candidate as Object[]; }
    return [];
  }

  private extractStringArray(value: Object | undefined): string[] { if (!value || !Array.isArray(value)) return []; return value as string[]; }
  private isToolType(type: string): boolean { return type === 'tool-invocation' || type === 'tool' || type === 'step-start' || type === 'step-finish' || type === 'tool-call' || type === 'tool-result'; }
  private isPermissionType(type: string): boolean { return type === 'permission' || type === 'permission-request' || type === 'tool-permission'; }
  private isErrorType(type: string): boolean { return type === 'error' || type === 'tool-error' || type === 'provider-error'; }
  private extractPartText(part: Record<string, Object>): string {
    const direct = part['text']; if (typeof direct === 'string' && direct.length > 0) return direct;
    const content = part['content']; if (typeof content === 'string' && content.length > 0) return content;
    const state = part['state'] as Record<string, Object>;
    if (state) { for (const key of ['message','error','output','result','text']) { const v = state[key]; if (typeof v === 'string' && v.length > 0) return v; } }
    return '';
  }
  private looksLikeError(text: string): boolean { if (text.length === 0) return false; const t = text.toLowerCase(); return t.includes('error') || t.includes('exception') || t.includes('api key') || t.includes('auth') || t.includes('unauthorized') || t.includes('provider') || t.includes('model not found') || t.includes('invalid model'); }
  private async delay(ms: number): Promise<void> { return new Promise<void>((resolve) => { setTimeout(() => resolve(), ms); }); }
  private onWsMessage(data: string): void { try { const parsed = JSON.parse(data) as Record<string, Object>; Logger.info('Runtime ws event: %{public}s', (parsed['type'] as string) ?? 'unknown'); } catch (err) { Logger.error('onWsMessage parse error: %{public}s', String(err)); } }
  private onWsStatus(connected: boolean): void { Logger.info('WebSocket status: %{public}s', connected ? 'connected' : 'disconnected'); }
  private startHealthCheck(): void { this.stopHealthCheck(); this.healthTimer = setInterval(() => { this.httpService.checkHealth().then((ok) => { this.serverInfo.healthOk = ok; if (!ok && this.connectionStatus === ConnectionStatus.Connected) Logger.warn('Health check failed, Runtime may be down'); }); }, Constants.HEALTH_CHECK_INTERVAL_MS) as unknown as number; }
  private stopHealthCheck(): void { if (this.healthTimer >= 0) { clearInterval(this.healthTimer); this.healthTimer = -1; } }
}
class ExecutionPollResult { ok: boolean = false; timedOut: boolean = false; hasAssistant: boolean = false; hasTool: boolean = false; hasError: boolean = false; hasPermission: boolean = false; message: string = ''; errorText: string = ''; messageCount: number = 0; }
