import { HttpService } from '../service/HttpService';
import { WebSocketService } from '../service/WebSocketService';
import { StorageService } from '../service/StorageService';
import { ServerInfo } from '../model/ServerInfo';
import { ChatMessage, MessageRole, MessageStatus, ToolCall } from '../model/ChatMessage';
import { ConnectionStatus, SessionInfo, ProviderInfo } from '../model/AppState';
import { EmptyRequest, TextPromptPart, PromptAsyncRequest, ConfigModelPatch, ExecutionPollResult } from '../model/OpenCodeApiTypes';
import { Constants } from '../utils/Constants';
import { Logger } from '../utils/Logger';
import { errStr } from '../utils/ErrorUtil';
import { localOpenCodeServerManager, LocalServerStatus } from '../services/LocalOpenCodeServerManager';
import { RuntimeMode, toRuntimeMode, needsServerUrl } from '../services/RuntimeMode';
import { localRuntimeClient } from '../services/LocalRuntimeClient';
import { localRuntimeService } from '../services/LocalRuntimeService';
import { OpenCodeApiAdapter, PromptInput } from '../services/OpenCodeApiAdapter';
import { ServerMode } from '../services/OpenCodeCapabilities';

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
  serverMode: ServerMode = 'unknown';
  runtimeMode: RuntimeMode = 'dev-pc';
  pendingPermissions: PendingPermission[] = [] // 待审批的权限请求
  pendingQuestions: PendingQuestion[] = [] // 待回答的问题
  private healthTimer: number = -1;
  private sendLock: boolean = false; // 防止用户在轮询完成前发送第二条消息
  private activeTurnId: string = '' // 当前轮次 ID，防止上一轮迟到的 assistant 被当成本轮回复
  private apiAdapter: OpenCodeApiAdapter = new OpenCodeApiAdapter();

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
      // Set runtime mode on adapter
      this.apiAdapter.setRuntimeMode(this.runtimeMode);

      // local-embedded: start in-process runtime, no HTTP needed
      if (this.runtimeMode === 'local-embedded') {
        Logger.info('[Connect] local-embedded mode: starting LocalRuntimeService');
        const health = await localRuntimeClient.start();
        if (!health.ok) {
          this.connectionStatus = ConnectionStatus.Error;
          this.errorMessage = '本机 Runtime 启动失败。';
          return;
        }
        this.serverMode = 'api-v2'; // local-embedded pretends to be api-v2
        this.connectionStatus = ConnectionStatus.Connected;
        this.serverInfo.connected = true;
        this.serverInfo.healthOk = true;
        this.serverInfo.displayName = 'Local Runtime (Embedded)';
        this.serverInfo.type = 'local-embedded';

        await this.loadSessions();
        await this.loadProviders();
        await this.autoSelectModel();
        if (this.currentSessionId.length > 0) await this.loadMessages(this.currentSessionId);
        Logger.info('[Connect] local-embedded runtime ready');
        return;
      }

      // dev-pc / remote: connect to external opencode server
      this.httpService.setServer(this.serverInfo);
      this.apiAdapter.setBaseUrl(this.serverInfo.url, this.serverInfo.getAuthHeader());

      const caps = await this.apiAdapter.detectCapabilities();
      this.serverMode = caps.mode;
      Logger.info(`Server mode detected: ${this.serverMode}`);

      const healthResult = await this.apiAdapter.health();
      if (healthResult['healthy'] !== true) {
        this.connectionStatus = ConnectionStatus.Error
        this.errorMessage = `健康检查失败 (mode=${this.serverMode})。`
        this.serverInfo.connected = false
        this.serverInfo.healthOk = false
        return
      }
      this.connectionStatus = ConnectionStatus.Connected;
      this.serverInfo.connected = true; this.serverInfo.healthOk = true;
      try { this.wsService.setServer(this.serverInfo); this.wsService.connect(); } catch (e) { Logger.warn(`Optional WS failed: ${errStr(e)}`); }
      await this.loadSessions(); await this.loadProviders();
      await this.autoSelectModel();
      if (this.selectedModel.length > 0) {
        try {
          await this.syncModelToRuntime()
          Logger.info(`Model synced to Runtime on connect: ${this.selectedModel}`)
        } catch (e) {
          Logger.warn(`Failed to sync model on connect: ${errStr(e)}`)
        }
      }
      if (this.currentSessionId.length > 0) await this.loadMessages(this.currentSessionId);
      this.startHealthCheck();
    } catch (err) {
      this.connectionStatus = ConnectionStatus.Error
      this.errorMessage = errStr(err)
      this.serverInfo.connected = false
      this.serverInfo.healthOk = false
      Logger.error(`Connection failed: ${errStr(err)}`)
    }
  }
  disconnect(): void {
    this.wsService.disconnect();
    this.stopHealthCheck();
    if (this.runtimeMode === 'local-embedded') {
      localRuntimeClient.stop();
    }
    this.connectionStatus = ConnectionStatus.Disconnected;
    this.serverInfo.connected = false;
  }

  /**
   * Auto-start the built-in OpenCode server and connect.
   * For local-embedded mode: start in-process LocalRuntimeService.
   * For dev-pc/remote: delegate to old sidecar or connect to external server.
   */
  async autoStartAndConnect(): Promise<void> {
    this.connectionStatus = ConnectionStatus.AutoStarting;
    this.serverStatusMessage = '正在启动本机 Runtime...';
    this.serverLogs = [];
    this.errorMessage = '';
    Logger.info('Auto-start: beginning runtime startup');

    // Pre-populate workspace from storage
    if (this.storageService) {
      try {
        const workspace = await this.storageService.getString(Constants.KEY_WORKSPACE_PATH, '')
        if (workspace.length > 0) {
          this.serverInfo.projectPath = workspace
        }
      } catch (e) {
        Logger.warn(`Auto-start: failed to read workspace: ${errStr(e)}`)
      }
    }

    // Default: local-embedded mode (in-process runtime, no Linux binary)
    this.runtimeMode = 'local-embedded';
    this.serverStatusMessage = '正在启动本机 Runtime (Embedded)...';
    Logger.info('[Auto-start] using local-embedded mode');

    try {
      await this.connect();

      const status1: string = this.connectionStatus;
      if (status1 === ConnectionStatus.Connected) {
        this.serverStatusMessage = '本机 Runtime 已启动';
        Logger.info('[Auto-start] local-embedded runtime connected');
        return;
      }
    } catch (e) {
      Logger.warn(`Auto-start local-embedded failed: ${errStr(e)}`)
    }

    // If local-embedded failed, try dev-pc mode (external server)
    Logger.info('[Auto-start] local-embedded failed, trying dev-pc fallback');
    this.runtimeMode = 'dev-pc';
    this.serverStatusMessage = '本机 Runtime 启动失败，尝试连接外部服务器...';

    try {
      await this.connect();
      const status2: string = this.connectionStatus;
      if (status2 === ConnectionStatus.Connected) {
        this.serverStatusMessage = '已连接外部 Runtime';
        return;
      }
    } catch (e) {
      Logger.warn(`Auto-start dev-pc fallback failed: ${errStr(e)}`)
    }

    // All attempts failed
    this.connectionStatus = ConnectionStatus.StartFailed;
    this.serverStatusMessage = 'Runtime 启动失败。请检查配置或手动启动。';
    this.errorMessage = this.serverStatusMessage;
  }
  /**
   * Gracefully shut down the built-in server.
   * Should be called when the app is closing.
   */
  shutdown(): void {
    if (this.runtimeMode === 'local-embedded') {
      localRuntimeClient.stop();
      this.serverStatusMessage = '本机 Runtime 已停止';
    } else {
      const result = localOpenCodeServerManager.shutdown();
      Logger.info(`Shutdown: ${result.message}`);
      this.serverStatusMessage = result.message;
    }
    this.stopHealthCheck();
    this.connectionStatus = ConnectionStatus.Disconnected;
    this.serverInfo.connected = false;
  }

  async loadSessions(): Promise<void> {
    try {
      const sessions = await this.apiAdapter.listSessions();
      const mapped: SessionInfo[] = [];
      for (let i = 0; i < sessions.length; i++) {
        const s = sessions[i];
        const rec: Record<string, Object> = {};
        rec['id'] = s.id;
        rec['name'] = s.name;
        rec['createdAt'] = s.createdAt;
        rec['updatedAt'] = s.updatedAt;
        rec['model'] = s.model;
        rec['agent'] = s.agent;
        mapped.push(SessionInfo.fromJson(rec));
      }
      this.sessions = mapped;
    } catch (err) { Logger.error(`loadSessions failed: ${errStr(err)}`); }
  }
  async loadProviders(): Promise<void> {
    try {
      const result = await this.apiAdapter.listProviders()
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
      Logger.error(`loadProviders failed: ${errStr(err)}`)
      this.providers = []
    }
  }
  async createSession(): Promise<string> {
    try {
      const body: Record<string, Object> = {};
      // P0-4: api-v2 needs { model: { id, providerID } }, legacy needs string
      if (this.serverMode === 'api-v2' && this.selectedModel.includes('/')) {
        const parts = this.selectedModel.split('/');
        const modelObj: Record<string, Object> = {};
        modelObj['providerID'] = parts[0];
        modelObj['id'] = parts[1];
        body['model'] = modelObj;
      } else {
        body['model'] = this.selectedModel;
      }
      const session = await this.apiAdapter.createSession(body);
      if (session.id.length > 0) {
        this.currentSessionId = session.id;
        await this.storageService?.setString(Constants.KEY_SESSION_ID, session.id);
        await this.loadSessions();
      }
      return session.id;
    } catch (err) {
      this.errorMessage = errStr(err);
      Logger.error(`createSession failed: ${errStr(err)}`);
      return '';
    }
  }
  async selectSession(sessionId: string): Promise<void> { this.currentSessionId = sessionId; await this.storageService?.setString(Constants.KEY_SESSION_ID, sessionId); await this.loadMessages(sessionId); }
  async loadMessages(sessionId: string = this.currentSessionId): Promise<void> {
    if (sessionId.length === 0) return;
    try {
      const raw = await this.apiAdapter.listMessages(sessionId);
      this.messages = this.normalizeOpenCodeMessages(raw, sessionId);
    } catch (err) { Logger.error(`loadMessages failed: ${errStr(err)}`); }
  }

  async sendMessage(content: string): Promise<void> {
    const text = content.trim()
    if (text.length === 0 || this.isGenerating || this.sendLock) {
      if (this.isGenerating || this.sendLock) {
        const warn = ChatMessage.createSystemMessage('上一条消息还在生成中，请等待完成或点击 Stop。')
        this.messages = [...this.messages, warn]
      }
      return
    }

    if (this.connectionStatus !== ConnectionStatus.Connected) {
      this.messages = [...this.messages, ChatMessage.createErrorMessage('本地 Runtime 未连接。')]
      return
    }

    if (this.selectedModel.length === 0) {
      const err = ChatMessage.createErrorMessage('未设置模型。请先到 Models 页面选择 providerId/modelId。')
      this.messages = [...this.messages, err]
      this.errorMessage = '未设置模型'
      return
    }

    let sessionId = this.currentSessionId
    if (sessionId.length === 0) {
      sessionId = await this.createSession()
      if (sessionId.length === 0) {
        this.messages = [...this.messages, ChatMessage.createErrorMessage('创建 session 失败。')]
        return
      }
    }

    // 生成新 turnId，发送前中止上一轮 stale run
    const turnId = this.newTurnId()
    this.activeTurnId = turnId
    this.sendLock = true
    this.isGenerating = true
    this.errorMessage = ''

    const userMsg = ChatMessage.createUserMessage(text)
    userMsg.sessionId = sessionId
    this.messages = [...this.messages, userMsg]

    try {
      // 关键修复：发送前强制把 ProviderRegistry 最新 apiKey 推到 LocalRuntimeService，
      // 避免"设置页保存成功但 Chat 仍报 no API key"的问题。
      if (this.runtimeMode === 'local-embedded') {
        try {
          await localRuntimeService.syncFromProviderRegistry()
        } catch (syncErr) {
          Logger.warn(`sendMessage: resync ProviderRegistry failed: ${errStr(syncErr)}`)
        }
      }
      try {
        await this.syncModelToRuntime()
        Logger.info(`Runtime model synced: ${this.selectedModel}`)
      } catch (syncErr) {
        const msg = `同步 Runtime model 失败：${errStr(syncErr)}`
        this.messages = [...this.messages, ChatMessage.createErrorMessage(msg)]
        this.errorMessage = msg
        return
      }

      if (this.selectedModel.length > 0 && this.selectedModel.includes('/')) {
        const providerId = this.selectedModel.split('/')[0]
        try {
          const providerData = await this.apiAdapter.listProviders()
          const connectedList = this.extractConnectedProviderIds(providerData['connected'])
          if (connectedList.length > 0 && !connectedList.includes(providerId)) {
            let isDisabled = false
            try {
              const config = await this.apiAdapter.getConfig();
              const disabled = config['disabled_providers']
              isDisabled = Array.isArray(disabled) && (disabled as Object[]).some((d: Object) => {
                return (typeof d === 'string' && d === providerId) ||
                  (d && typeof d === 'object' && (d as Record<string, Object>)['id'] === providerId)
              })
            } catch (_) {}
            const hint = isDisabled
              ? `Provider "${providerId}" 已被禁用。请在 OpenCode 配置中启用该 provider，或切换到已连接的 provider 的模型。`
              : `Provider "${providerId}" 未连接。当前已连接：${connectedList.join(', ')}。请连接该 provider 或切换模型。`
            this.messages = [...this.messages, ChatMessage.createErrorMessage(
              `模型 ${this.selectedModel} 的 provider 不可用。\n${hint}`
            )]
            this.errorMessage = `Provider ${providerId} not connected`
            return
          }
        } catch (providerErr) {
          Logger.warn(`Failed to check provider status: ${errStr(providerErr)}`)
        }
      }

      const before = await this.getRawMessages(sessionId)
      const beforeCount = before.length

      const req = new PromptAsyncRequest()
      const part = new TextPromptPart()
      part.text = text
      req.parts = [part]

      // Send prompt via adapter (v2: /api/session/:id/prompt, legacy: /session/:id/prompt_async)
      const promptInput = new PromptInput();
      promptInput.text = text;
      promptInput.model = this.selectedModel;
      promptInput.agent = 'build';
      const promptResult = await this.apiAdapter.sendPrompt(sessionId, promptInput);
      if (!promptResult.ok) {
        this.messages = [...this.messages, ChatMessage.createErrorMessage(`prompt 发送失败：${promptResult.error}`)]
        this.errorMessage = promptResult.error ?? 'unknown'
        return
      }
      Logger.info(`prompt sent session=${sessionId} turn=${turnId} mode=${this.serverMode}`)

      // v2: call wait endpoint
      if (this.serverMode === 'api-v2') {
        try {
          await this.apiAdapter.waitSession(sessionId)
          Logger.info(`wait completed for session=${sessionId}`)
        } catch (waitErr) {
          Logger.warn(`wait failed: ${errStr(waitErr)}`)
        }
      }

      // 等待 user message 出现在 raw messages 中，定位 userIndex
      let userIndex = -1
      for (let i = 0; i < 10; i++) {
        await this.delay(300)
        const raw = await this.getRawMessages(sessionId)
        userIndex = this.findLastUserIndex(raw, text)
        if (userIndex >= 0) break
      }
      if (userIndex < 0) {
        userIndex = beforeCount - 1
        Logger.warn(`sendMessage: could not find user message, fallback userIndex=${userIndex}`)
      }

      await this.loadMessages(sessionId)
      const poll = await this.waitForExecutionAfterIndex(sessionId, userIndex, turnId)
      await this.loadMessages(sessionId)

      if (!poll.ok) {
        const e = ChatMessage.createErrorMessage(
          `Runtime 没有返回当前问题的 assistant。${poll.message}\n\n` +
          `session=${sessionId}\n` +
          `turn=${turnId}\n` +
          `model=${this.selectedModel}\n` +
          `messageCount=${poll.messageCount}`
        )
        e.sessionId = sessionId
        this.messages = [...this.messages, e]
        this.errorMessage = e.content
      }

      // Check for pending permission requests
      if (poll.hasPermission || poll.ok) {
        await this.checkAndLoadPermissions()
      }

      await this.loadSessions()
    } catch (err) {
      this.messages = [...this.messages, ChatMessage.createErrorMessage(errStr(err))]
      this.errorMessage = errStr(err)
      Logger.error(`sendMessage failed: ${errStr(err)}`)
    } finally {
      this.isGenerating = false
      this.sendLock = false
      this.finalizeLastStreamingAssistant()
    }
  }
  async stopGeneration(): Promise<void> {
    if (!this.isGenerating || this.currentSessionId.length === 0) return;
    try {
      await this.apiAdapter.abortSession(this.currentSessionId);
    } catch (err) {
      Logger.error(`stopGeneration failed: ${errStr(err)}`);
    } finally {
      this.isGenerating = false;
      this.sendLock = false;
      this.finalizeLastStreamingAssistant();
    }
  }
  async saveServerConfig(): Promise<void> { if (!this.storageService) return; await this.storageService.setString(Constants.KEY_SERVER_URL, this.serverInfo.url); await this.storageService.setString(Constants.KEY_AUTH_USERNAME, this.serverInfo.username); await this.storageService.setString(Constants.KEY_AUTH_PASSWORD, this.serverInfo.password); await this.storageService.setString(Constants.KEY_MODEL, this.selectedModel); }

  /**
   * Auto-select a model from a connected provider.
   * Called after connection is established to ensure selectedModel is usable.
   *
   * 修复：在 selectedModel 为空时（如首次启动、清数据）自动从 Runtime 的
   * default 字段读取默认模型，避免 Chat 页面一直显示「未设置模型」。
   */
  async autoSelectModel(): Promise<void> {
    try {
      const providerData = await this.apiAdapter.listProviders()
      const connectedList = this.extractConnectedProviderIds(providerData['connected'])

      // Path A: selectedModel 为空 → 用 server 的 default 字段 (Runtime 端
      //         /config 同步出来的默认 provider/model)
      if (this.selectedModel.length === 0 || !this.selectedModel.includes('/')) {
        const chosen = this.pickModelFromServerDefaults(providerData, connectedList)
        if (chosen.length > 0) {
          this.selectedModel = chosen
          Logger.info(`autoSelectModel: initial pick from server defaults = ${chosen}`)
          await this.saveServerConfig()
          try { await this.syncModelToRuntime() }
          catch (syncErr) { Logger.error(`autoSelectModel: syncModelToRuntime failed: ${errStr(syncErr)}`) }
        } else {
          Logger.warn('autoSelectModel: no model found from server defaults')
        }
        return
      }

      // Path B: selectedModel 有值 → 检查 provider 是否仍 connected
      const currentProvider = this.selectedModel.split('/')[0]
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
          Logger.error(`autoSelectModel: syncModelToRuntime failed: ${errStr(syncErr)}`)
        }
      } else {
        Logger.warn('autoSelectModel: no connected provider with models found')
      }
    } catch (e) {
      Logger.warn(`autoSelectModel failed: ${errStr(e)}`)
    }
  }

  /**
   * 从 /provider 端点响应里挑选一个可用的 model ref (providerId/modelId).
   *
   * 优先级:
   *  1. server `default` 字段里 + 在 connected 列表里的 provider
   *  2. 第一个 connected provider 的第一个 model
   *  3. 第一个非空 model
   *
   * 找不到返回空字符串。
   */
  private pickModelFromServerDefaults(providerData: Record<string, Object>, connectedList: string[]): string {
    // 关键修复：服务端 listProviders 写的是 `defaults`，旧版可能写 `default`，两个都要兼容。
    let defaults: Object | undefined = providerData['defaults']
    if (defaults === undefined) {
      defaults = providerData['default']
    }
    if (defaults && typeof defaults === 'object') {
      const map = defaults as Record<string, Object>
      for (const provId of Object.keys(map)) {
        if (connectedList.length > 0 && !connectedList.includes(provId)) continue
        const modelId = (map[provId] as string) ?? ''
        if (provId.length > 0 && modelId.length > 0) {
          return `${provId}/${modelId}`
        }
      }
    }
    // 2. 第一个 connected provider 的第一个 model
    const all = providerData['all']
    if (Array.isArray(all)) {
      for (const raw of all as Object[]) {
        const prov = raw as Record<string, Object>
        const provId = (prov['id'] as string) ?? ''
        if (connectedList.length > 0 && !connectedList.includes(provId)) continue
        const models = prov['models']
        if (models && typeof models === 'object' && !Array.isArray(models)) {
          const keys = Object.keys(models as Record<string, Object>)
          if (keys.length > 0) return `${provId}/${keys[0]}`
        } else if (Array.isArray(models) && (models as Object[]).length > 0) {
          const first = (models as Object[])[0]
          const modelId = typeof first === 'string' ? first : ((first as Record<string, Object>)['id'] as string) ?? ''
          if (modelId.length > 0) return `${provId}/${modelId}`
        }
      }
    }
    // 3. 兜底：所有 provider 的第一个 model
    if (Array.isArray(all)) {
      for (const raw of all as Object[]) {
        const prov = raw as Record<string, Object>
        const provId = (prov['id'] as string) ?? ''
        const models = prov['models']
        if (models && typeof models === 'object' && !Array.isArray(models)) {
          const keys = Object.keys(models as Record<string, Object>)
          if (keys.length > 0) return `${provId}/${keys[0]}`
        } else if (Array.isArray(models) && (models as Object[]).length > 0) {
          const first = (models as Object[])[0]
          const modelId = typeof first === 'string' ? first : ((first as Record<string, Object>)['id'] as string) ?? ''
          if (modelId.length > 0) return `${provId}/${modelId}`
        }
      }
    }
    return ''
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
      out.push(`[health error] ${errStr(e)}`)
    }

    try {
      const config = await this.httpService.get<Record<string, Object>>(Constants.API_CONFIG);
      out.push(`[config.model] ${config['model']}`)
      const disabled = config['disabled_providers']
      if (disabled) out.push(`[config.disabled_providers] ${JSON.stringify(disabled)}`)
      const providers = config['provider']
      if (providers) out.push(`[config.provider keys] ${Object.keys(providers as Record<string, Object>)}`)
    } catch (e) {
      out.push(`[config error] ${errStr(e)}`)
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
      out.push(`[provider error] ${errStr(e)}`)
    }

    try {
      const sessions = await this.httpService.get<Object>(Constants.API_SESSION);
      const arr = this.extractArray(sessions, 'sessions', 'data')
      out.push(`[sessions count] ${arr.length}`)
    } catch (e) {
      out.push(`[session error] ${errStr(e)}`)
    }

    return out.join('\n')
  }
  /**
   * 关键修复：旧版本 testModel() 用 `httpService.post('/session/:id/prompt_async')` 直接打 HTTP server，
   * 在 local-embedded 模式下没有 HTTP server，会直接失败或导致 split-brain。
   * 改为全 adapter 路径：createSession → sendPrompt → waitSession → listMessages，
   * 这样 local 走 localRuntimeClient,远端走 api-v2,行为统一。
   */
  async testModel(): Promise<string> {
    if (this.selectedModel.length === 0) return '未设置模型。'
    const oldSid = this.currentSessionId
    const oldMsgs = this.messages
    try {
      // 1. 同步默认模型到 runtime
      await this.syncModelToRuntime()
      // 2. 走 adapter 创建 session(本地/localRuntimeClient;远端/api-v2)
      const sess = await this.apiAdapter.createSession()
      const sid = sess.id
      if (sid.length === 0) return '创建测试 session 失败。'
      // 3. 走 adapter 发送 prompt
      const input = new PromptInput()
      input.text = 'Say OK.'
      input.model = this.selectedModel
      const sendRes = await this.apiAdapter.sendPrompt(sid, input)
      if (!sendRes.ok) return `模型测试失败：${sendRes.error}`
      // 4. 走 adapter 等 session 结束(localRuntimeClient 内部轮询;远端 /wait)
      await this.apiAdapter.waitSession(sid)
      // 5. 走 adapter 拉 messages 来判断是否真有回复
      const msgs = await this.apiAdapter.listMessages(sid)
      const hasAssistantText = msgs.some((m: Object) => {
        const item = m as Record<string, Object>
        const info = item['info'] as Record<string, Object>
        const role = (info?.['role'] as string) || (item['role'] as string) || ''
        if (role !== 'assistant') return false
        const parts = (item['parts'] as Object[]) || []
        for (const raw of parts) {
          const part = raw as Record<string, Object>
          const type = (part['type'] as string) || ''
          if (type === 'text' || type === 'reasoning') {
            const t = (part['text'] as string) || ''
            if (t.length > 0) return true
          }
          if (type === 'tool') return true
        }
        return false
      })
      if (!hasAssistantText) return `模型测试失败：空回复（provider 返回 completed 但无文本）`
      return `模型测试成功：${this.selectedModel}`
    } catch (err) {
      return `模型测试失败：${errStr(err)}`
    } finally {
      if (oldSid.length > 0) {
        this.currentSessionId = oldSid
        this.messages = oldMsgs
      }
    }
  }

  async syncModelToRuntime(): Promise<void> {
    if (this.selectedModel.length === 0) { Logger.warn('No selected model configured.'); return; }
    await this.storageService?.setString(Constants.KEY_MODEL, this.selectedModel);

    if (this.runtimeMode === 'local-embedded') {
      // Update local runtime's default model config
      const parts = this.selectedModel.split('/');
      const patchBody: Record<string, Object> = {};
      if (parts.length >= 2) {
        patchBody['defaultProviderID'] = parts[0];
        patchBody['defaultModelID'] = parts[1];
      } else {
        patchBody['defaultModelID'] = this.selectedModel;
      }
      await this.apiAdapter.patchConfig(patchBody);
      Logger.info(`syncModelToRuntime (local): ${this.selectedModel}`);
      return;
    }

    // dev-pc / remote: PATCH /config with model string
    if (this.serverMode === 'api-v2') {
      Logger.info(`syncModelToRuntime: skipped for api-v2 (model=${this.selectedModel})`);
      return;
    }
    const patchBody: Record<string, Object> = {};
    patchBody['model'] = this.selectedModel;
    await this.apiAdapter.patchConfig(patchBody);
    Logger.info(`syncModelToRuntime (remote): ${this.selectedModel}`);
  }
  private async getRawMessages(sessionId: string): Promise<Object[]> {
    return this.apiAdapter.listMessages(sessionId);
  }
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
        r.ok=false; r.message=`轮询消息失败：${errStr(err)}`; return r;
      }
    }
    r.timedOut=true;
    // On timeout, include raw messages preview for debugging
    let rawText = '';
    try {
      const raw = await this.getRawMessages(sessionId);
      rawText = JSON.stringify(raw).slice(0, 2000);
    } catch (e) {
      rawText = `读取 raw messages 失败：${errStr(e)}`;
    }
    r.message = `等待 assistant/tool/error/permission 超时。\n当前模型：${this.selectedModel}\nmessageCount=${r.messageCount}\n\nRaw messages preview:\n${rawText}`;
    return r;
  }
  private inspectMessages(raw: Object[], beforeCount: number): ExecutionPollResult {
    const r = new ExecutionPollResult()
    for (let i = beforeCount; i < raw.length; i++) {
      const item = raw[i] as Record<string, Object>
      const info = item['info'] as Record<string, Object>
      let role = info ? ((info['role'] as string) ?? '') : ''
      if (role.length === 0) role = (item['role'] as string) ?? ''
      const status = info ? ((info['status'] as string) ?? '') : ((item['status'] as string) ?? '')
      const parts = (item['parts'] as Object[]) ?? []
      let assistantHasContent = false

      for (const pa of parts) {
        const part = pa as Record<string, Object>
        const type = (part['type'] as string) ?? ''
        const text = this.extractPartText(part)
        if (text.length > 0) assistantHasContent = true
        if (this.isToolType(type)) r.hasTool = true
        if (this.isPermissionType(type)) r.hasPermission = true
        if (this.isErrorType(type)) {
          r.hasError = true
          if (r.errorText.length === 0) r.errorText = text.length > 0 ? text : `Runtime error part: ${type}`
        }
      }

      const directContent = item['content']
      if (typeof directContent === 'string' && directContent.length > 0) assistantHasContent = true

      if (role === 'assistant') {
        if (assistantHasContent) {
          r.hasAssistant = true
        } else if (status === 'completed' || status === 'complete') {
          r.hasError = true
          if (r.errorText.length === 0) r.errorText = 'Runtime 返回了空 assistant 回复。'
        }
      }
    }
    return r
  }
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
  private newTurnId(): string { return `turn_${Date.now()}_${Math.floor(Math.random() * 100000)}` }

  private findLastUserIndex(raw: Object[], text: string): number {
    for (let i = raw.length - 1; i >= 0; i--) {
      const item = raw[i] as Record<string, Object>
      const info = item['info'] as Record<string, Object>
      const role = info ? ((info['role'] as string) ?? '') : ''
      if (role !== 'user') continue
      const parts = (item['parts'] as Object[]) ?? []
      for (const pa of parts) {
        const part = pa as Record<string, Object>
        const t = this.extractPartText(part)
        if (t === text) return i
      }
    }
    return -1
  }

  private async waitForExecutionAfterIndex(
    sessionId: string,
    userIndex: number,
    turnId: string,
    maxAttempts: number = Constants.POLL_MAX_ATTEMPTS,
    intervalMs: number = Constants.POLL_INTERVAL_MS
  ): Promise<ExecutionPollResult> {
    const r = new ExecutionPollResult()
    for (let i = 0; i < maxAttempts; i++) {
      await this.delay(intervalMs)

      // stale poll 检查：如果 turnId 已变，说明用户发了新问题，本轮 poll 应丢弃
      if (this.activeTurnId !== turnId) {
        Logger.warn(`stale poll ignored: ${turnId}`)
        r.ok = false
        r.message = '轮询被新消息中断'
        return r
      }

      try {
        const raw = await this.getRawMessages(sessionId)
        r.messageCount = raw.length

        if (raw.length <= userIndex + 1) continue

        const s = this.inspectMessages(raw, userIndex + 1)
        r.hasAssistant = s.hasAssistant
        r.hasTool = s.hasTool
        r.hasError = s.hasError
        r.hasPermission = s.hasPermission

        if (s.hasError) {
          r.ok = false
          r.message = s.errorText.length > 0 ? s.errorText : 'Runtime 返回错误。'
          return r
        }

        if (s.hasPermission) {
          r.ok = true
          r.message = 'Runtime 正在等待权限确认。'
          return r
        }

        if (s.hasAssistant) {
          r.ok = true
          r.message = 'assistant response received'
          return r
        }

        if (s.hasTool) {
          r.message = 'Runtime 已开始工具调用，继续等待 assistant...'
        }
      } catch (err) {
        r.ok = false
        r.message = `轮询消息失败：${errStr(err)}`
        return r
      }
    }
    r.ok = false
    r.timedOut = true
    r.message = `等待 assistant 超时。userIndex=${userIndex}`
    return r
  }
  private onWsMessage(data:string): void { try { const parsed=JSON.parse(data) as Record<string,Object>; Logger.info(`Runtime ws event: ${(parsed['type'] as string)??'unknown'}`); } catch(err){ Logger.error(`onWsMessage parse error: ${errStr(err)}`); } }
  private onWsStatus(connected:boolean): void { Logger.info(`WebSocket status: ${connected?'connected':'disconnected'}`); }
  private startHealthCheck(): void { this.stopHealthCheck(); this.healthTimer=setInterval(()=>{ this.httpService.checkHealth().then((ok:boolean)=>{ this.serverInfo.healthOk=ok; if(!ok&&this.connectionStatus===ConnectionStatus.Connected){ this.connectionStatus=ConnectionStatus.Error; this.errorMessage='Runtime 健康检查失败，连接已断开。'; Logger.warn('Health check failed, marking disconnected'); } }); }, Constants.HEALTH_CHECK_INTERVAL_MS) as number; }
  private stopHealthCheck(): void { if(this.healthTimer>=0){ clearInterval(this.healthTimer); this.healthTimer=-1; } }

  // Safe error-to-string is provided by the imported errStr() from utils/ErrorUtil

  // ══════════ Permission Handling ══════════

  /**
   * Load pending permission requests from the server.
   * Call this after sendMessage detects a permission block.
   */
  async loadPendingPermissions(): Promise<void> {
    try {
      const raw = await this.apiAdapter.listPermissionRequests()
      this.pendingPermissions = raw.map((item: Object) => {
        const r = item as Record<string, Object>
        const p = new PendingPermission()
        p.id = (r['id'] as string) || ''
        p.sessionID = (r['sessionID'] as string) || this.currentSessionId
        p.type = (r['type'] as string) || ''
        p.title = (r['title'] as string) || (r['description'] as string) || 'Permission Request'
        p.description = (r['description'] as string) || ''
        p.riskLevel = (r['riskLevel'] as string) || ''
        return p
      })
    } catch (e) {
      Logger.warn(`loadPendingPermissions failed: ${errStr(e)}`)
    }
  }

  /**
   * Approve a permission request (once or always).
   */
  async approvePermission(requestId: string, always: boolean = false): Promise<void> {
    const reply = always ? 'always' : 'once'
    const sessionId = this.currentSessionId
    try {
      await this.apiAdapter.replyPermission(sessionId, requestId, reply)
      // Remove from pending list
      this.pendingPermissions = this.pendingPermissions.filter(p => p.id !== requestId)
      // Add system message
      this.messages = [...this.messages, ChatMessage.createSystemMessage(
        `权限已${always ? '永久' : '一次性'}批准`
      )]
      // Reload messages to get the agent's continued response
      await this.loadMessages(sessionId)
    } catch (e) {
      Logger.error(`approvePermission failed: ${errStr(e)}`)
      this.messages = [...this.messages, ChatMessage.createErrorMessage(
        `权限批准失败：${errStr(e)}`
      )]
    }
  }

  /**
   * Reject a permission request.
   */
  async rejectPermission(requestId: string): Promise<void> {
    const sessionId = this.currentSessionId
    try {
      await this.apiAdapter.replyPermission(sessionId, requestId, 'deny')
      this.pendingPermissions = this.pendingPermissions.filter(p => p.id !== requestId)
      this.messages = [...this.messages, ChatMessage.createSystemMessage('权限已拒绝')]
      await this.loadMessages(sessionId)
    } catch (e) {
      Logger.error(`rejectPermission failed: ${errStr(e)}`)
    }
  }

  /**
   * Auto-check for pending permissions after sendMessage detects one.
   */
  private async checkAndLoadPermissions(): Promise<void> {
    await this.loadPendingPermissions()
    await this.loadPendingQuestions()
    if (this.pendingPermissions.length > 0) {
      Logger.info(`Found ${this.pendingPermissions.length} pending permission(s)`)
    }
    if (this.pendingQuestions.length > 0) {
      Logger.info(`Found ${this.pendingQuestions.length} pending question(s)`)
    }
  }

  // ══════════ Question Handling ══════════

  async loadPendingQuestions(): Promise<void> {
    try {
      const raw = await this.apiAdapter.listQuestions(this.currentSessionId)
      this.pendingQuestions = raw.map((item: Object) => {
        const r = item as Record<string, Object>
        const q = new PendingQuestion()
        q.id = (r['id'] as string) || ''
        q.sessionID = (r['sessionID'] as string) || this.currentSessionId
        q.header = (r['header'] as string) || ''
        q.question = (r['question'] as string) || ''
        q.multiSelect = r['multiSelect'] === true
        q.status = (r['status'] as string) || ''
        const opts = r['options'] as Object[] | undefined
        if (opts) {
          for (const o of opts) {
            const opt = o as Record<string, Object>
            q.options.push({
              id: (opt['id'] as string) || '',
              label: (opt['label'] as string) || '',
              description: (opt['description'] as string) || ''
            })
          }
        }
        return q
      })
    } catch (e) {
      Logger.warn(`loadPendingQuestions failed: ${errStr(e)}`)
    }
  }

  async replyQuestion(requestId: string, optionIDs: string[]): Promise<void> {
    try {
      await this.apiAdapter.replyQuestion(this.currentSessionId, requestId, optionIDs)
      this.pendingQuestions = this.pendingQuestions.filter(q => q.id !== requestId)
      this.messages = [...this.messages, ChatMessage.createSystemMessage('问题已回答')]
      await this.loadMessages(this.currentSessionId)
    } catch (e) {
      Logger.error(`replyQuestion failed: ${errStr(e)}`)
      this.messages = [...this.messages, ChatMessage.createErrorMessage(`回答失败：${errStr(e)}`)]
    }
  }

  async rejectQuestion(requestId: string): Promise<void> {
    try {
      await this.apiAdapter.rejectQuestion(this.currentSessionId, requestId)
      this.pendingQuestions = this.pendingQuestions.filter(q => q.id !== requestId)
      this.messages = [...this.messages, ChatMessage.createSystemMessage('问题已拒绝')]
      await this.loadMessages(this.currentSessionId)
    } catch (e) {
      Logger.error(`rejectQuestion failed: ${errStr(e)}`)
    }
  }

  // ══════════ MCP / Command / Skill Loading ══════════

  async loadCommands(): Promise<Object[]> {
    try {
      return await this.apiAdapter.listCommands()
    } catch (e) {
      Logger.error(`loadCommands failed: ${errStr(e)}`)
      return []
    }
  }

  async loadSkills(): Promise<Object[]> {
    try {
      return await this.apiAdapter.listSkills()
    } catch (e) {
      Logger.error(`loadSkills failed: ${errStr(e)}`)
      return []
    }
  }

  // ══════════ Abort ══════════

  async abortSession(): Promise<void> {
    if (this.currentSessionId.length === 0) return
    try {
      await this.apiAdapter.abortSession(this.currentSessionId)
      this.isGenerating = false
      this.sendLock = false
      this.messages = [...this.messages, ChatMessage.createSystemMessage('已中止')]
    } catch (e) {
      Logger.error(`abortSession failed: ${errStr(e)}`)
    }
  }
}

/** Pending permission request model */
export class PendingPermission {
  id: string = ''
  sessionID: string = ''
  type: string = ''
  title: string = ''
  description: string = ''
  riskLevel: string = ''
}

/** Pending question model */
export class PendingQuestion {
  id: string = ''
  sessionID: string = ''
  header: string = ''
  question: string = ''
  multiSelect: boolean = false
  status: string = ''
  options: QuestionOption[] = []
}

export class QuestionOption {
  id: string = ''
  label: string = ''
  description: string = ''
}
