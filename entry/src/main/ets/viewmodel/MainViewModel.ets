import { HttpService } from '../service/HttpService';
import { WebSocketService } from '../service/WebSocketService';
import { StorageService } from '../service/StorageService';
import { ServerInfo } from '../model/ServerInfo';
import { ChatMessage, MessageRole, MessageStatus, ToolCall } from '../model/ChatMessage';
import { ConnectionStatus, SessionInfo, ProviderInfo } from '../model/AppState';
import { EmptyRequest, TextPromptPart, PromptAsyncRequest, ConfigModelPatch, ExecutionPollResult } from '../model/OpenCodeApiTypes';
import { Constants } from '../utils/Constants';
import { Logger } from '../utils/Logger';
import { localOpenCodeServerManager, LocalServerStatus } from '../services/LocalOpenCodeServerManager';

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
  serverStatusMessage: string = '';
  serverLogs: string[] = [];
  private healthTimer: number = -1;

  async init(storage: StorageService): Promise<void> {
    this.storageService = storage;
    this.serverInfo.url = await storage.getString(Constants.KEY_SERVER_URL, Constants.DEFAULT_SERVER_URL);
    if (this.serverInfo.url.length === 0) this.serverInfo.url = Constants.DEFAULT_SERVER_URL;
    this.serverInfo.username = await storage.getString(Constants.KEY_AUTH_USERNAME, '');
    this.serverInfo.password = await storage.getString(Constants.KEY_AUTH_PASSWORD, '');
    this.serverInfo.displayName = 'Local OpenCode Runtime';
    this.serverInfo.type = 'local';
    this.selectedModel = await storage.getString(Constants.KEY_MODEL, Constants.DEFAULT_MODEL);
    this.currentSessionId = await storage.getString(Constants.KEY_SESSION_ID, '');
    this.httpService.setServer(this.serverInfo);
    this.wsService.setServer(this.serverInfo);
    this.wsService.setMessageHandler((data: string) => this.onWsMessage(data));
    this.wsService.setStatusHandler((connected: boolean) => this.onWsStatus(connected));
    Logger.info(`MainViewModel initialized: ${this.serverInfo.url}`);
  }

  async connect(): Promise<void> {
    this.connectionStatus = ConnectionStatus.Connecting;
    this.errorMessage = '';
    try {
      this.httpService.setServer(this.serverInfo);
      const healthy = await this.httpService.checkHealth();
      if (!healthy) { this.connectionStatus = ConnectionStatus.Error; this.errorMessage = '本地 Runtime 健康检查失败。'; return; }
      this.connectionStatus = ConnectionStatus.Connected;
      this.serverInfo.connected = true; this.serverInfo.healthOk = true;
      try { this.wsService.setServer(this.serverInfo); this.wsService.connect(); } catch (e) { Logger.warn(`Optional WS failed: ${String(e)}`); }
      await this.loadSessions(); await this.loadProviders();
      await this.autoSelectModel();
      // Sync selected model to Runtime after connection
      if (this.selectedModel.length > 0) {
        try {
          await this.syncModelToRuntime()
          Logger.info(`Model synced to Runtime on connect: ${this.selectedModel}`)
        } catch (e) {
          Logger.warn(`Failed to sync model on connect: ${MainViewModel.errStr(e)}`)
        }
      }
      if (this.currentSessionId.length > 0) await this.loadMessages(this.currentSessionId);
      this.startHealthCheck();
    } catch (err) { this.connectionStatus = ConnectionStatus.Error; this.errorMessage = MainViewModel.errStr(err); Logger.error(`Connection failed: ${MainViewModel.errStr(err)}`); }
  }
  disconnect(): void { this.wsService.disconnect(); this.stopHealthCheck(); this.connectionStatus = ConnectionStatus.Disconnected; this.serverInfo.connected = false; }

  /**
   * Auto-start the built-in OpenCode server and connect.
   * Called automatically on app launch for HarmonyOS computer deployment.
   * Flow: check health → start process if needed → poll until healthy → connect.
   */
  async autoStartAndConnect(): Promise<void> {
    this.connectionStatus = ConnectionStatus.AutoStarting;
    this.serverStatusMessage = '正在启动内置 Runtime...';
    this.serverLogs = [];
    this.errorMessage = '';
    Logger.info('Auto-start: beginning built-in server startup');

    // Pre-populate workspace from storage if not set in server config
    if (this.storageService) {
      try {
        const workspace = await this.storageService.getString(Constants.KEY_WORKSPACE_PATH, '')
        if (workspace.length > 0) {
          const savedConfig = await localOpenCodeServerManager.loadLastConfig()
          if (savedConfig.workspace.length === 0) {
            savedConfig.workspace = workspace
            await localOpenCodeServerManager.saveLastConfig(savedConfig)
            Logger.info(`Auto-start: set workspace to ${workspace}`)
          }
        }
      } catch (e) {
        Logger.warn(`Auto-start: failed to pre-populate workspace: ${String(e)}`)
      }
    }

    let result: LocalServerStatus
    try {
      result = await localOpenCodeServerManager.autoStart(
        (status: LocalServerStatus) => {
          this.serverStatusMessage = status.message;
          this.serverLogs = status.logs;
          Logger.info(`Auto-start progress: ${status.status} - ${status.message}`);
        }
      );
    } catch (e) {
      // 外层兜底: 任何 autoStart 内部抛出的异常(包括 TypeError: processStart of undefined,
      // 老的 HAP 没有 dev-pc 短路)都被这里接住
      const msg = `autoStart 抛出异常: ${MainViewModel.errStr(e)}`
      Logger.error(msg)
      this.serverStatusMessage = msg
      this.errorMessage = msg
      this.serverLogs = [`[fatal] ${MainViewModel.errStr(e)}`]

      // 异常时也试一次 health check,因为 Runtime 可能是 manual 启动的
      try {
        const healthy: boolean = await this.httpService.checkHealth()
        if (healthy) {
          Logger.info('autoStart crashed but Runtime is healthy, connecting anyway...')
          this.serverStatusMessage = '检测到手动启动的 Runtime, 正在连接...'
          await this.connect()
          if ((this.connectionStatus as string) === (ConnectionStatus.Connected as string)) {
            this.serverStatusMessage = '手动启动 Runtime 已连接 (autoStart 异常后恢复)'
          }
          return
        }
      } catch (_) {}

      this.connectionStatus = ConnectionStatus.StartFailed
      return
    }

    if (result.status === 'running') {
      // Server is healthy and activated, now connect
      this.serverStatusMessage = 'Runtime 已就绪，正在连接...';
      this.serverLogs = result.logs;

      // 同步实际启动成功的 Runtime 地址
      // 因为本机模式可能返回 127.0.0.1，dev-pc 模式可能返回局域网 IP
      // 启动成功的 baseUrl 才是真正可用的，httpService/wsService 要重新指向
      this.serverInfo.url = result.baseUrl;
      this.httpService.setServer(this.serverInfo);
      this.wsService.setServer(this.serverInfo);

      Logger.info(`Auto-start: server running at ${result.baseUrl}, connecting...`);
      await this.connect();

      const finalStatus: string = this.connectionStatus as string;
      if (finalStatus === (ConnectionStatus.Connected as string)) {
        this.serverStatusMessage = `内置 Runtime 已连接 (v${result.version})`;
      }
    } else {
      // Server start failed (or manual_required)
      this.serverStatusMessage = result.message;
      this.serverLogs = result.logs;
      this.errorMessage = result.message;
      Logger.warn(`Auto-start: ${result.status} - ${result.message}`);

      if (result.status === 'manual_required') {
        // dev-pc / remote 模式需要用户在开发电脑启动 server
        // 不要标 StartFailed (那是真出错),用 Disconnected 让卡片显示 "Runtime 未连接"
        this.connectionStatus = ConnectionStatus.Disconnected;
      } else {
        this.connectionStatus = ConnectionStatus.StartFailed;
        Logger.error(`Auto-start failed: ${result.message}`);
      }

      // fallback：如果用户已经手动启动了 opencode serve，则尝试直接连接
      // 比如终端跑了 `opencode serve --port 4096 --hostname 0.0.0.0`
      // health check 通了就当 Connected 走，不要卡死在 StartFailed
      try {
        const healthy: boolean = await this.httpService.checkHealth();
        if (healthy) {
          Logger.info('Auto-start failed, but manual Runtime is healthy. Connecting...');
          this.serverStatusMessage = '手动检测健康通过，正在连接...';
          await this.connect();

          const finalStatus: string = this.connectionStatus as string;
          if (finalStatus === (ConnectionStatus.Connected as string)) {
            this.serverStatusMessage = '手动启动 Runtime 已连接';
          } else {
            this.serverStatusMessage = '检测健康通过，但连接失败';
          }
        }
      } catch (e) {
        Logger.warn(`Manual Runtime fallback failed: ${String(e)}`);
      }
    }
  }

  /**
   * Gracefully shut down the built-in server.
   * Should be called when the app is closing.
   */
  shutdown(): void {
    const result = localOpenCodeServerManager.shutdown();
    Logger.info(`Shutdown: ${result.message}`);
    this.serverStatusMessage = result.message;
    this.stopHealthCheck();
    this.connectionStatus = ConnectionStatus.Disconnected;
    this.serverInfo.connected = false;
  }

  async loadSessions(): Promise<void> {
    try { const r = await this.httpService.get<Object>(Constants.API_SESSION); this.sessions = this.extractArray(r, 'sessions', 'data').map((x: Object) => SessionInfo.fromJson(x as Record<string, Object>)); }
    catch (err) { Logger.error(`loadSessions failed: ${String(err)}`); }
  }
  async loadProviders(): Promise<void> {
    try {
      const result = await this.httpService.get<Record<string, Object>>(Constants.API_PROVIDER)
      const connectedIds = this.extractConnectedProviderIds(result['connected'])
      const next: ProviderInfo[] = []

      const all = result['all']
      if (Array.isArray(all)) {
        const arr = all as Object[]
        for (const item of arr) {
          next.push(ProviderInfo.fromJson(item as Record<string, Object>, connectedIds))
        }
      } else if (all && typeof all === 'object') {
        const map = all as Record<string, Object>
        for (const id of Object.keys(map)) {
          next.push(ProviderInfo.fromRuntimeMapEntry(id, map[id], connectedIds))
        }
      } else {
        for (const id of Object.keys(result)) {
          if (id === 'connected' || id === 'default' || id === 'model') continue
          const value = result[id]
          if (value && typeof value === 'object') {
            next.push(ProviderInfo.fromRuntimeMapEntry(id, value, connectedIds))
          }
        }
      }

      this.providers = next
      Logger.info(`providers.loaded count=${next.length}`)
    } catch (err) {
      Logger.error(`loadProviders failed: ${String(err)}`)
      this.providers = []
    }
  }
  async createSession(): Promise<string> {
    try { const r = await this.httpService.post<Record<string, Object>>(Constants.API_SESSION, new EmptyRequest()); const id = (r['id'] as string) ?? ''; if (id.length > 0) { this.currentSessionId = id; await this.storageService?.setString(Constants.KEY_SESSION_ID, id); await this.loadSessions(); } return id; }
    catch (err) { this.errorMessage = String(err); Logger.error(`createSession failed: ${String(err)}`); return ''; }
  }
  async selectSession(sessionId: string): Promise<void> { this.currentSessionId = sessionId; await this.storageService?.setString(Constants.KEY_SESSION_ID, sessionId); await this.loadMessages(sessionId); }
  async loadMessages(sessionId: string = this.currentSessionId): Promise<void> { if (sessionId.length === 0) return; try { const raw = await this.httpService.get<Object>(this.sessionMessagesPath(sessionId)); this.messages = this.normalizeOpenCodeMessages(this.extractArray(raw, 'messages', 'data'), sessionId); } catch (err) { Logger.error(`loadMessages failed: ${String(err)}`); } }

  async sendMessage(content: string): Promise<void> {
    const text = content.trim(); if (text.length === 0 || this.isGenerating) return;
    if (this.connectionStatus !== ConnectionStatus.Connected) { this.messages = [...this.messages, ChatMessage.createErrorMessage('本地 Runtime 未连接。')]; return; }

    // Pre-check: selectedModel must be set
    if (this.selectedModel.length === 0) {
      const err = ChatMessage.createErrorMessage('未设置模型。请先到 Models 页面选择 providerId/modelId。');
      this.messages = [...this.messages, err];
      this.errorMessage = '未设置模型';
      return;
    }

    let sessionId = this.currentSessionId; if (sessionId.length === 0) { sessionId = await this.createSession(); if (sessionId.length === 0) { this.messages = [...this.messages, ChatMessage.createErrorMessage('创建 session 失败。')]; return; } }
    const userMsg = ChatMessage.createUserMessage(text); userMsg.sessionId = sessionId;
    const assistantMsg = ChatMessage.createAssistantMessage('等待 Runtime 响应...'); assistantMsg.sessionId = sessionId;
    this.messages = [...this.messages, userMsg, assistantMsg]; this.isGenerating = true; this.errorMessage = '';
    try {
      // Sync model to Runtime — must not fail silently
      try {
        await this.syncModelToRuntime();
        Logger.info(`Runtime model synced: ${this.selectedModel}`);
      } catch (syncErr) {
        const msg = `同步 Runtime model 失败：${MainViewModel.errStr(syncErr)}`
        assistantMsg.setError(msg)
        this.messages = [...this.messages]
        this.errorMessage = msg
        return
      }

      // Check if the provider for the selected model is connected
      if (this.selectedModel.length > 0 && this.selectedModel.includes('/')) {
        const providerId = this.selectedModel.split('/')[0]
        try {
          const providerData = await this.httpService.get<Record<string, Object>>(Constants.API_PROVIDER);
          const connectedList = this.extractConnectedProviderIds(providerData['connected'])
          if (connectedList.length > 0 && !connectedList.includes(providerId)) {
            // Check if provider is disabled
            let isDisabled = false
            try {
              const config = await this.httpService.get<Record<string, Object>>(Constants.API_CONFIG);
              const disabled = config['disabled_providers']
              isDisabled = Array.isArray(disabled) && (disabled as Object[]).some((d: Object) => {
                return (typeof d === 'string' && d === providerId) ||
                  (d && typeof d === 'object' && (d as Record<string, Object>)['id'] === providerId)
              })
            } catch (_) {}
            const hint = isDisabled
              ? `Provider "${providerId}" 已被禁用。请在 OpenCode 配置中启用该 provider，或切换到已连接的 provider 的模型。`
              : `Provider "${providerId}" 未连接。当前已连接：${connectedList.join(', ')}。请连接该 provider 或切换模型。`
            assistantMsg.setError(`模型 ${this.selectedModel} 的 provider 不可用。\n${hint}`)
            this.messages = [...this.messages]
            this.errorMessage = `Provider ${providerId} not connected`
            return
          }
        } catch (providerErr) {
          Logger.warn(`Failed to check provider status: ${MainViewModel.errStr(providerErr)}`)
        }
      }

      const before = await this.getRawMessages(sessionId); const beforeCount = before.length;
      const req = new PromptAsyncRequest(); const part = new TextPromptPart(); part.text = text; req.parts = [part];
      let promptSent = false
      let promptError = ''
      try {
        await this.httpService.post<Object>(this.sessionPromptAsyncPath(sessionId), req);
        promptSent = true
        Logger.info(`prompt_async sent session=${sessionId}`)
      } catch (promptErr) {
        promptError = MainViewModel.errStr(promptErr)
        Logger.error(`prompt_async failed: ${promptError}`)
      }
      if (!promptSent) {
        assistantMsg.setError(`prompt_async 发送失败：${promptError}`)
        this.messages = [...this.messages]
        this.errorMessage = promptError
        return
      }
      await this.loadMessages(sessionId);
      const poll = await this.waitForExecution(sessionId, beforeCount); await this.loadMessages(sessionId);
      if (!poll.ok) { const e = ChatMessage.createErrorMessage(poll.message); e.sessionId = sessionId; this.messages = [...this.messages, e]; this.errorMessage = poll.message; }
      await this.loadSessions();
    } catch (err) { assistantMsg.setError(MainViewModel.errStr(err)); this.errorMessage = MainViewModel.errStr(err); this.messages = [...this.messages]; Logger.error(`sendMessage failed: ${MainViewModel.errStr(err)}`); }
    finally { this.isGenerating = false; this.finalizeLastStreamingAssistant(); }
  }
  async stopGeneration(): Promise<void> { if (!this.isGenerating || this.currentSessionId.length === 0) return; try { await this.httpService.post<Object>(this.sessionAbortPath(this.currentSessionId), new EmptyRequest()); } catch (err) { Logger.error(`stopGeneration failed: ${String(err)}`); } finally { this.isGenerating = false; this.finalizeLastStreamingAssistant(); } }
  async saveServerConfig(): Promise<void> { if (!this.storageService) return; await this.storageService.setString(Constants.KEY_SERVER_URL, this.serverInfo.url); await this.storageService.setString(Constants.KEY_AUTH_USERNAME, this.serverInfo.username); await this.storageService.setString(Constants.KEY_AUTH_PASSWORD, this.serverInfo.password); await this.storageService.setString(Constants.KEY_MODEL, this.selectedModel); }

  /**
   * Auto-select a model from a connected provider.
   * Called after connection is established to ensure selectedModel is usable.
   */
  async autoSelectModel(): Promise<void> {
    try {
      if (this.selectedModel.length > 0 && this.selectedModel.includes('/')) {
        const currentProvider = this.selectedModel.split('/')[0]
        const providerData = await this.httpService.get<Record<string, Object>>(Constants.API_PROVIDER)
        const connectedList = this.extractConnectedProviderIds(providerData['connected'])

        if (connectedList.includes(currentProvider)) {
          Logger.info(`autoSelectModel: current provider "${currentProvider}" is connected, keeping ${this.selectedModel}`)
          return
        }

        Logger.warn(`autoSelectModel: current provider "${currentProvider}" not connected, searching for alternative`)

        const all = providerData['all']
        let fallbackModel = ''
        if (Array.isArray(all)) {
          const allArr = all as Object[]
          for (let idx = 0; idx < allArr.length; idx++) {
            const prov = allArr[idx] as Record<string, Object>
            const provId = (prov['id'] as string) || ''
            if (connectedList.includes(provId)) {
              const models = prov['models']
              if (Array.isArray(models) && models.length > 0) {
                const modelsArr = models as Object[]
                const firstModel = modelsArr[0] as Record<string, Object>
                const modelId = typeof modelsArr[0] === 'string' ? (modelsArr[0] as string) : ((firstModel['id'] as string) || '')
                if (modelId.length > 0) {
                  fallbackModel = `${provId}/${modelId}`
                  break
                }
              } else if (models && typeof models === 'object') {
                const keys = Object.keys(models as Record<string, Object>)
                if (keys.length > 0) {
                  fallbackModel = `${provId}/${keys[0]}`
                  break
                }
              }
            }
          }
        }

        if (fallbackModel.length > 0) {
          this.selectedModel = fallbackModel
          Logger.info(`autoSelectModel: switched to ${fallbackModel}`)
          await this.saveServerConfig()
          try {
            await this.syncModelToRuntime()
          } catch (syncErr) {
            Logger.error(`autoSelectModel: syncModelToRuntime failed: ${MainViewModel.errStr(syncErr)}`)
          }
        } else {
          Logger.warn('autoSelectModel: no connected provider with models found')
        }
      }
    } catch (e) {
      Logger.warn(`autoSelectModel failed: ${MainViewModel.errStr(e)}`)
    }
  }

  async diagnoseRuntime(): Promise<string> {
    const out: string[] = []
    out.push(`=== Runtime 诊断 ===`)
    out.push(`App selectedModel: ${this.selectedModel}`)
    out.push(`App serverUrl: ${this.serverInfo.url}`)
    out.push(`Connection: ${this.connectionStatus}`)
    out.push('')

    try {
      const health = await this.httpService.get<Record<string, Object>>(Constants.API_HEALTH);
      out.push(`[health] ${JSON.stringify(health)}`)
    } catch (e) {
      out.push(`[health error] ${MainViewModel.errStr(e)}`)
    }

    try {
      const config = await this.httpService.get<Record<string, Object>>(Constants.API_CONFIG);
      out.push(`[config.model] ${config['model']}`)
      const disabled = config['disabled_providers']
      if (disabled) out.push(`[config.disabled_providers] ${JSON.stringify(disabled)}`)
      const providers = config['provider']
      if (providers) out.push(`[config.provider keys] ${Object.keys(providers as Record<string, Object>)}`)
    } catch (e) {
      out.push(`[config error] ${MainViewModel.errStr(e)}`)
    }

    try {
      const provider = await this.httpService.get<Record<string, Object>>(Constants.API_PROVIDER);
      const connected = provider['connected']
      out.push(`[provider.connected] ${JSON.stringify(connected)}`)
      const all = provider['all']
      if (Array.isArray(all)) {
        const ids = (all as Object[]).map((p: Object) => (p as Record<string, Object>)['id'] as string)
        out.push(`[provider.all ids] ${JSON.stringify(ids)}`)
      }
    } catch (e) {
      out.push(`[provider error] ${MainViewModel.errStr(e)}`)
    }

    try {
      const sessions = await this.httpService.get<Object>(Constants.API_SESSION);
      const arr = this.extractArray(sessions, 'sessions', 'data')
      out.push(`[sessions count] ${arr.length}`)
    } catch (e) {
      out.push(`[session error] ${MainViewModel.errStr(e)}`)
    }

    return out.join('\n')
  }
  async testModel(): Promise<string> { if (this.selectedModel.length === 0) return '未设置模型。'; const old = this.currentSessionId; try { const sid = await this.createSession(); if (sid.length === 0) return '创建测试 session 失败。'; await this.syncModelToRuntime(); const before = await this.getRawMessages(sid); const req = new PromptAsyncRequest(); const p = new TextPromptPart(); p.text = 'Say OK.'; req.parts = [p]; await this.httpService.post<Object>(this.sessionPromptAsyncPath(sid), req); const poll = await this.waitForExecution(sid, before.length, 30, 1000); await this.loadMessages(sid); return poll.ok ? `模型测试成功：${this.selectedModel}` : `模型测试失败：${poll.message}`; } catch (err) { return `模型测试失败：${String(err)}`; } finally { if (old.length > 0) this.currentSessionId = old; } }

  async syncModelToRuntime(): Promise<void> { if (this.selectedModel.length === 0) { Logger.warn('No selected model configured.'); return; } const patch = new ConfigModelPatch(); patch.model = this.selectedModel; await this.httpService.patch<Object>(Constants.API_CONFIG, patch); await this.storageService?.setString(Constants.KEY_MODEL, this.selectedModel); }
  private async getRawMessages(sessionId: string): Promise<Object[]> { const raw = await this.httpService.get<Object>(this.sessionMessagesPath(sessionId)); return this.extractArray(raw, 'messages', 'data'); }
  private async waitForExecution(sessionId: string, beforeCount: number, maxAttempts: number = Constants.POLL_MAX_ATTEMPTS, intervalMs: number = Constants.POLL_INTERVAL_MS): Promise<ExecutionPollResult> {
    const r = new ExecutionPollResult();
    for (let i=0;i<maxAttempts;i++){
      await this.delay(intervalMs);
      try {
        const raw=await this.getRawMessages(sessionId);
        r.messageCount=raw.length;

        // Condition 1: new messages appeared
        if(raw.length>beforeCount){
          const s=this.inspectMessages(raw,beforeCount);
          r.hasAssistant=s.hasAssistant; r.hasTool=s.hasTool; r.hasError=s.hasError; r.hasPermission=s.hasPermission;
          if(s.hasError){r.ok=false; r.message=s.errorText.length>0?s.errorText:'Runtime 返回错误。'; return r;}
          if(s.hasPermission){r.ok=true; r.message='Runtime 正在等待权限确认。'; return r;}
          if(s.hasTool){r.ok=true; r.message='Runtime 已开始工具调用。'; return r;}
          if(s.hasAssistant){r.ok=true; r.message='assistant response received'; return r;}
        }

        // Condition 2: existing assistant message got content (agent updating in-place)
        // ONLY check messages at or after beforeCount to avoid matching stale responses
        for (let j=beforeCount;j<raw.length;j++){
          const item=raw[j] as Record<string,Object>;
          const info=item['info'] as Record<string,Object>;
          const role=info?(info['role'] as string):'';
          if(role==='assistant'){
            const parts=item['parts'] as Object[];
            if(parts&&parts.length>0){
              r.hasAssistant=true; r.ok=true; r.message='assistant response received (in-place update)'; return r;
            }
          }
        }

        // Condition 3: any new part appeared (tool, step, reasoning, etc.)
        // ONLY check messages at or after beforeCount
        if(raw.length>beforeCount){
          const s=this.inspectMessages(raw,beforeCount);
          if(s.hasTool||s.hasPermission||s.hasError){
            r.hasTool=s.hasTool; r.hasPermission=s.hasPermission; r.hasError=s.hasError;
            if(s.hasError){r.ok=false; r.message=s.errorText.length>0?s.errorText:'Runtime 返回错误。'; return r;}
            if(s.hasPermission){r.ok=true; r.message='Runtime 正在等待权限确认。'; return r;}
            if(s.hasTool){r.ok=true; r.message='Runtime 已开始工具调用。'; return r;}
          }
        }
      } catch(err){
        r.ok=false; r.message=`轮询消息失败：${MainViewModel.errStr(err)}`; return r;
      }
    }
    r.timedOut=true;
    // On timeout, include raw messages preview for debugging
    let rawText = '';
    try {
      const raw = await this.getRawMessages(sessionId);
      rawText = JSON.stringify(raw).slice(0, 2000);
    } catch (e) {
      rawText = `读取 raw messages 失败：${MainViewModel.errStr(e)}`;
    }
    r.message = `等待 assistant/tool/error/permission 超时。\n当前模型：${this.selectedModel}\nmessageCount=${r.messageCount}\n\nRaw messages preview:\n${rawText}`;
    return r;
  }
  private inspectMessages(raw: Object[], beforeCount: number): ExecutionPollResult { const r = new ExecutionPollResult(); for(let i=beforeCount;i<raw.length;i++){ const item=raw[i] as Record<string,Object>; const info=item['info'] as Record<string,Object>; const role=info?(info['role'] as string):''; if(role==='assistant') r.hasAssistant=true; const parts=item['parts'] as Object[]; if(!parts) continue; for(const pa of parts){ const part=pa as Record<string,Object>; const type=(part['type'] as string)??''; const text=this.extractPartText(part); if(this.isToolType(type)) r.hasTool=true; if(this.isPermissionType(type)) r.hasPermission=true; if(this.isErrorType(type)){r.hasError=true; if(r.errorText.length===0) r.errorText=text.length>0?text:`Runtime error part: ${type}`;} }} return r; }
  private normalizeOpenCodeMessages(raw: Object[], sessionId: string): ChatMessage[] {
    const out: ChatMessage[] = []
    for (let i = 0; i < raw.length; i++) {
      const item = raw[i] as Record<string, Object>
      const info = item['info'] as Record<string, Object>

      // Support role from info or item level
      let roleStr = ''
      if (info) roleStr = (info['role'] as string) ?? ''
      if (roleStr.length === 0) roleStr = (item['role'] as string) ?? ''

      const id = info ? ((info['id'] as string) ?? '') : ''
      const parts = (item['parts'] as Object[]) ?? []

      const msg = new ChatMessage()
      msg.id = id.length > 0 ? id : `msg_${Date.now()}_${i}`
      msg.sessionId = sessionId
      msg.role = roleStr === 'assistant' ? MessageRole.Assistant : MessageRole.User
      msg.timestamp = Date.now()
      msg.status = MessageStatus.Complete
      msg.isStreaming = false

      const textParts: string[] = []

      // Extract from parts
      for (const pa of parts) {
        const part = pa as Record<string, Object>
        const type = (part['type'] as string) ?? ''
        const text = this.extractPartText(part)

        if (type === 'text' && text.length > 0) {
          textParts.push(text)
        } else if (this.isErrorType(type)) {
          msg.isError = true
          msg.status = MessageStatus.Error
          textParts.push(text.length > 0 ? text : `Runtime error: ${type}`)
        } else if (this.isToolType(type)) {
          const tool = new ToolCall()
          tool.id = ((part['id'] as string) ?? (part['callID'] as string) ?? '')
          tool.name = ((part['tool'] as string) ?? (part['name'] as string) ?? type)
          tool.arguments = JSON.stringify(part['input'] ?? part['args'] ?? part['state'] ?? '')
          tool.result = text
          tool.status = type.includes('error') ? 'error' : 'complete'
          msg.toolCalls.push(tool)
        } else if (text.length > 0) {
          textParts.push(text)
        }
      }

      // Support direct content/error at item level
      const directContent = item['content']
      if (typeof directContent === 'string' && directContent.length > 0) {
        textParts.push(directContent)
      }
      const directError = item['error']
      if (typeof directError === 'string' && directError.length > 0) {
        msg.isError = true
        msg.status = MessageStatus.Error
        textParts.push(directError)
      }

      msg.content = textParts.join('\n\n')
      if (msg.content.length === 0 && msg.toolCalls.length > 0) {
        msg.content = `[${msg.toolCalls.length} tool call(s)]`
      }
      if (msg.content.length > 0 || msg.toolCalls.length > 0) {
        out.push(msg)
      }
    }
    return out
  }
  private extractArray(value:Object, key1:string, key2:string): Object[] { if(Array.isArray(value)) return value as Object[]; if(!value||typeof value!=='object') return []; const rec=value as Record<string,Object>; const c1=rec[key1]; if(Array.isArray(c1)) return c1 as Object[]; const c2=rec[key2]; if(Array.isArray(c2)) return c2 as Object[]; return []; }
  private extractStringArray(value:Object|undefined): string[] { if(!value||!Array.isArray(value)) return []; return value as string[]; }
  private extractConnectedProviderIds(value: Object | undefined): string[] {
    const out: string[] = []
    if (!value) return out
    if (Array.isArray(value)) {
      const arr = value as Object[]
      for (const item of arr) {
        if (typeof item === 'string') {
          out.push(item)
        } else if (item && typeof item === 'object') {
          const rec = item as Record<string, Object>
          const id = (rec['id'] as string) ?? ''
          if (id.length > 0) out.push(id)
        }
      }
      return out
    }
    if (typeof value === 'object') {
      const map = value as Record<string, Object>
      for (const id of Object.keys(map)) {
        out.push(id)
      }
    }
    return out
  }
  private isToolType(type:string): boolean { return type==='tool-invocation'||type==='tool'||type==='step-start'||type==='step-finish'||type==='tool-call'||type==='tool-result'; }
  private isPermissionType(type:string): boolean { return type==='permission'||type==='permission-request'||type==='tool-permission'; }
  private isErrorType(type:string): boolean { return type==='error'||type==='tool-error'||type==='provider-error'; }
  private extractPartText(part: Record<string,Object>): string {
    // Check direct string fields
    const keys = ['text', 'content', 'message', 'error', 'output', 'result']
    for (const key of keys) {
      const value = part[key]
      if (typeof value === 'string' && value.length > 0) return value
    }
    // Check nested state object
    const state = part['state'] as Record<string,Object>
    if (state) {
      for (const key of keys) {
        const value = state[key]
        if (typeof value === 'string' && value.length > 0) return value
      }
    }
    return ''
  }
  private sessionMessagesPath(sessionId:string): string { return `/session/${sessionId}/message`; }
  private sessionPromptAsyncPath(sessionId:string): string { return `/session/${sessionId}/prompt_async`; }
  private sessionAbortPath(sessionId:string): string { return `/session/${sessionId}/abort`; }
  private finalizeLastStreamingAssistant(): void { if(this.messages.length===0) return; const last=this.messages[this.messages.length-1]; if(last.role===MessageRole.Assistant&&last.isStreaming){ last.finalize(); this.messages=[...this.messages]; } }
  private async delay(ms:number): Promise<void> { return new Promise<void>((resolve)=>{ setTimeout(()=>resolve(), ms); }); }
  private onWsMessage(data:string): void { try { const parsed=JSON.parse(data) as Record<string,Object>; Logger.info(`Runtime ws event: ${(parsed['type'] as string)??'unknown'}`); } catch(err){ Logger.error(`onWsMessage parse error: ${String(err)}`); } }
  private onWsStatus(connected:boolean): void { Logger.info(`WebSocket status: ${connected?'connected':'disconnected'}`); }
  private startHealthCheck(): void { this.stopHealthCheck(); this.healthTimer=setInterval(()=>{ this.httpService.checkHealth().then((ok:boolean)=>{ this.serverInfo.healthOk=ok; if(!ok&&this.connectionStatus===ConnectionStatus.Connected){ this.connectionStatus=ConnectionStatus.Error; this.errorMessage='Runtime 健康检查失败，连接已断开。'; Logger.warn('Health check failed, marking disconnected'); } }); }, Constants.HEALTH_CHECK_INTERVAL_MS) as number; }
  private stopHealthCheck(): void { if(this.healthTimer>=0){ clearInterval(this.healthTimer); this.healthTimer=-1; } }

  /** Safe error-to-string for ArkTS (String(e) returns "[object Object]" for Error objects) */
  private static errStr(e: Object): string {
    if (typeof e === 'string') return e
    const rec = e as Record<string, Object>
    if (typeof rec['message'] === 'string') return rec['message'] as string
    try { return JSON.stringify(e) } catch (_) { return String(e) }
  }
}
