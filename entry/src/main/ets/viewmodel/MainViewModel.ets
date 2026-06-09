import { HttpService } from '../service/HttpService';
import { WebSocketService } from '../service/WebSocketService';
import { StorageService } from '../service/StorageService';
import { ServerInfo } from '../model/ServerInfo';
import { ChatMessage, MessageRole, MessageStatus } from '../model/ChatMessage';
import { ConnectionStatus, SessionInfo, ProviderInfo } from '../model/AppState';
import { Constants } from '../utils/Constants';
import { Logger } from '../utils/Logger';

/**
 * Main view model coordinating server communication, session management,
 * and chat message lifecycle. Drives the UI via @Observed state fields.
 */
export class MainViewModel {
  // Services
  httpService: HttpService = new HttpService();
  wsService: WebSocketService = new WebSocketService();
  storageService: StorageService | null = null;

  // Observable state
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

    // Load saved server config
    const savedUrl = await storage.getString(Constants.KEY_SERVER_URL, Constants.DEFAULT_SERVER_URL);
    const savedUsername = await storage.getString(Constants.KEY_AUTH_USERNAME, '');
    const savedPassword = await storage.getString(Constants.KEY_AUTH_PASSWORD, '');
    const savedModel = await storage.getString(Constants.KEY_MODEL, Constants.DEFAULT_MODEL);

    this.serverInfo.url = savedUrl;
    this.serverInfo.username = savedUsername;
    this.serverInfo.password = savedPassword;
    this.selectedModel = savedModel;

    this.httpService.setServer(this.serverInfo);
    this.wsService.setServer(this.serverInfo);

    this.wsService.setMessageHandler(this.onWsMessage.bind(this));
    this.wsService.setStatusHandler(this.onWsStatus.bind(this));

    Logger.info('MainViewModel initialized with server: %{public}s', savedUrl);
  }

  async connect(): Promise<void> {
    this.connectionStatus = ConnectionStatus.Connecting;
    this.errorMessage = '';

    try {
      this.httpService.setServer(this.serverInfo);
      const healthy = await this.httpService.checkHealth();
      if (healthy) {
        this.connectionStatus = ConnectionStatus.Connected;
        this.serverInfo.connected = true;
        this.serverInfo.healthOk = true;

        // Start WebSocket
        this.wsService.setServer(this.serverInfo);
        this.wsService.connect();

        // Load sessions
        await this.loadSessions();
        await this.loadProviders();

        this.startHealthCheck();
        Logger.info('Connected to server: %{public}s', this.serverInfo.url);
      } else {
        this.connectionStatus = ConnectionStatus.Error;
        this.errorMessage = 'Server health check failed';
      }
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
    Logger.info('Disconnected from server');
  }

  async loadSessions(): Promise<void> {
    try {
      const result = await this.httpService.get<Record<string, Object[]>>(Constants.API_SESSION);
      const sessionsArr = result['sessions'] ?? result['data'] ?? [];
      this.sessions = [];
      for (const item of sessionsArr) {
        this.sessions.push(SessionInfo.fromJson(item as Record<string, Object>));
      }
    } catch (err) {
      Logger.error('loadSessions failed: %{public}s', String(err));
    }
  }

  async loadProviders(): Promise<void> {
    try {
      const result = await this.httpService.get<Record<string, Object[]>>(Constants.API_PROVIDER);
      const providersArr = result['providers'] ?? result['data'] ?? [];
      this.providers = [];
      for (const item of providersArr) {
        this.providers.push(ProviderInfo.fromJson(item as Record<string, Object>));
      }
    } catch (err) {
      Logger.error('loadProviders failed: %{public}s', String(err));
    }
  }

  async createSession(): Promise<string> {
    try {
      const result = await this.httpService.post<Record<string, string>>(Constants.API_SESSION, {});
      const id = result['id'] ?? '';
      if (id.length > 0) {
        this.currentSessionId = id;
        await this.loadSessions();
      }
      return id;
    } catch (err) {
      Logger.error('createSession failed: %{public}s', String(err));
      return '';
    }
  }

  async sendMessage(content: string): Promise<void> {
    if (content.length === 0 || this.isGenerating) return;

    let sessionId = this.currentSessionId;
    if (sessionId.length === 0) {
      sessionId = await this.createSession();
      if (sessionId.length === 0) return;
    }

    // Add user message to local list
    const userMsg = ChatMessage.createUserMessage(content);
    userMsg.sessionId = sessionId;
    this.messages = [...this.messages, userMsg];

    // Create streaming assistant message placeholder
    const assistantMsg = ChatMessage.createAssistantMessage();
    assistantMsg.sessionId = sessionId;
    this.messages = [...this.messages, assistantMsg];
    this.isGenerating = true;

    try {
      // Send via HTTP POST (the server handles LLM streaming internally)
      await this.httpService.post(Constants.API_MESSAGE, {
        'sessionID': sessionId,
        'content': content,
        'model': this.selectedModel
      });
    } catch (err) {
      assistantMsg.setError(String(err));
      Logger.error('sendMessage failed: %{public}s', String(err));
    }
  }

  async stopGeneration(): Promise<void> {
    if (!this.isGenerating || this.currentSessionId.length === 0) return;
    try {
      await this.httpService.post('/session/' + this.currentSessionId + '/abort', {});
      this.isGenerating = false;
    } catch (err) {
      Logger.error('stopGeneration failed: %{public}s', String(err));
    }
  }

  private onWsMessage(data: string): void {
    try {
      const parsed = JSON.parse(data) as Record<string, Object>;
      const type = parsed['type'] as string;

      if (type === 'message.delta') {
        // Streaming content delta
        const content = parsed['content'] as string ?? '';
        const sessionId = parsed['sessionID'] as string ?? '';
        if (sessionId === this.currentSessionId && this.messages.length > 0) {
          const lastMsg = this.messages[this.messages.length - 1];
          if (lastMsg.role === MessageRole.Assistant && lastMsg.isStreaming) {
            lastMsg.appendContent(content);
            // Trigger re-render
            this.messages = [...this.messages];
          }
        }
      } else if (type === 'message.complete') {
        const sessionId = parsed['sessionID'] as string ?? '';
        if (sessionId === this.currentSessionId && this.messages.length > 0) {
          const lastMsg = this.messages[this.messages.length - 1];
          if (lastMsg.role === MessageRole.Assistant) {
            lastMsg.finalize();
            this.isGenerating = false;
            this.messages = [...this.messages];
          }
        }
      } else if (type === 'tool.call') {
        // Handle tool call events
        Logger.info('Tool call: %{public}s', data);
      }
    } catch (err) {
      Logger.error('onWsMessage parse error: %{public}s', String(err));
    }
  }

  private onWsStatus(connected: boolean): void {
    Logger.info('WebSocket status: %{public}s', connected ? 'connected' : 'disconnected');
  }

  private startHealthCheck(): void {
    this.stopHealthCheck();
    this.healthTimer = setInterval(() => {
      this.httpService.checkHealth().then((ok) => {
        this.serverInfo.healthOk = ok;
        if (!ok && this.connectionStatus === ConnectionStatus.Connected) {
          Logger.warn('Health check failed, server may be down');
        }
      });
    }, Constants.HEALTH_CHECK_INTERVAL_MS) as unknown as number;
  }

  private stopHealthCheck(): void {
    if (this.healthTimer >= 0) {
      clearInterval(this.healthTimer);
      this.healthTimer = -1;
    }
  }

  async saveServerConfig(): Promise<void> {
    if (!this.storageService) return;
    await this.storageService.setString(Constants.KEY_SERVER_URL, this.serverInfo.url);
    await this.storageService.setString(Constants.KEY_AUTH_USERNAME, this.serverInfo.username);
    await this.storageService.setString(Constants.KEY_AUTH_PASSWORD, this.serverInfo.password);
    await this.storageService.setString(Constants.KEY_MODEL, this.selectedModel);
  }
}
