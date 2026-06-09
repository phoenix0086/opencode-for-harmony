import { HttpService } from '../service/HttpService';
import { WebSocketService } from '../service/WebSocketService';
import { StorageService } from '../service/StorageService';
import { ServerInfo } from '../model/ServerInfo';
import { ChatMessage, MessageRole, MessageStatus, ToolCall } from '../model/ChatMessage';
import { ConnectionStatus, SessionInfo, ProviderInfo } from '../model/AppState';
import { EmptyRequest, TextPromptPart, PromptAsyncRequest, ConfigModelPatch, ExecutionPollResult } from '../model/OpenCodeApiTypes';
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
    this.wsService.setMessageHandler(this.onWsMessage.bind(this));
    this.wsService.setStatusHandler(this.onWsStatus.bind(this));
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
      if (this.currentSessionId.length > 0) await this.loadMessages(this.currentSessionId);
      this.startHealthCheck();
    } catch (err) { this.connectionStatus = ConnectionStatus.Error; this.errorMessage = String(err); Logger.error(`Connection failed: ${String(err)}`); }
  }
  disconnect(): void { this.wsService.disconnect(); this.stopHealthCheck(); this.connectionStatus = ConnectionStatus.Disconnected; this.serverInfo.connected = false; }

  async loadSessions(): Promise<void> {
    try { const r = await this.httpService.get<Object>(Constants.API_SESSION); this.sessions = this.extractArray(r, 'sessions', 'data').map((x: Object) => SessionInfo.fromJson(x as Record<string, Object>)); }
    catch (err) { Logger.error(`loadSessions failed: ${String(err)}`); }
  }
  async loadProviders(): Promise<void> {
    try { const r = await this.httpService.get<Record<string, Object>>(Constants.API_PROVIDER); const connected = this.extractStringArray(r['connected']); const all = this.extractArray(r['all'] as Object, 'providers', 'data'); this.providers = all.map((x: Object) => ProviderInfo.fromJson(x as Record<string, Object>, connected)); }
    catch (err) { Logger.error(`loadProviders failed: ${String(err)}`); }
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
    let sessionId = this.currentSessionId; if (sessionId.length === 0) { sessionId = await this.createSession(); if (sessionId.length === 0) { this.messages = [...this.messages, ChatMessage.createErrorMessage('创建 session 失败。')]; return; } }
    const userMsg = ChatMessage.createUserMessage(text); userMsg.sessionId = sessionId;
    const assistantMsg = ChatMessage.createAssistantMessage('等待 Runtime 响应...'); assistantMsg.sessionId = sessionId;
    this.messages = [...this.messages, userMsg, assistantMsg]; this.isGenerating = true; this.errorMessage = '';
    try {
      await this.syncModelToRuntime();
      const before = await this.getRawMessages(sessionId); const beforeCount = before.length;
      const req = new PromptAsyncRequest(); const part = new TextPromptPart(); part.text = text; req.parts = [part];
      await this.httpService.post<Object>(this.sessionPromptAsyncPath(sessionId), req);
      await this.loadMessages(sessionId);
      const poll = await this.waitForExecution(sessionId, beforeCount); await this.loadMessages(sessionId);
      if (!poll.ok) { const e = ChatMessage.createErrorMessage(poll.message); e.sessionId = sessionId; this.messages = [...this.messages, e]; this.errorMessage = poll.message; }
      await this.loadSessions();
    } catch (err) { assistantMsg.setError(String(err)); this.errorMessage = String(err); this.messages = [...this.messages]; Logger.error(`sendMessage failed: ${String(err)}`); }
    finally { this.isGenerating = false; this.finalizeLastStreamingAssistant(); }
  }
  async stopGeneration(): Promise<void> { if (!this.isGenerating || this.currentSessionId.length === 0) return; try { await this.httpService.post<Object>(this.sessionAbortPath(this.currentSessionId), new EmptyRequest()); } catch (err) { Logger.error(`stopGeneration failed: ${String(err)}`); } finally { this.isGenerating = false; this.finalizeLastStreamingAssistant(); } }
  async saveServerConfig(): Promise<void> { if (!this.storageService) return; await this.storageService.setString(Constants.KEY_SERVER_URL, this.serverInfo.url); await this.storageService.setString(Constants.KEY_AUTH_USERNAME, this.serverInfo.username); await this.storageService.setString(Constants.KEY_AUTH_PASSWORD, this.serverInfo.password); await this.storageService.setString(Constants.KEY_MODEL, this.selectedModel); }
  async testModel(): Promise<string> { if (this.selectedModel.length === 0) return '未设置模型。'; const old = this.currentSessionId; try { const sid = await this.createSession(); if (sid.length === 0) return '创建测试 session 失败。'; await this.syncModelToRuntime(); const before = await this.getRawMessages(sid); const req = new PromptAsyncRequest(); const p = new TextPromptPart(); p.text = 'Say OK.'; req.parts = [p]; await this.httpService.post<Object>(this.sessionPromptAsyncPath(sid), req); const poll = await this.waitForExecution(sid, before.length, 30, 1000); await this.loadMessages(sid); return poll.ok ? `模型测试成功：${this.selectedModel}` : `模型测试失败：${poll.message}`; } catch (err) { return `模型测试失败：${String(err)}`; } finally { if (old.length > 0) this.currentSessionId = old; } }

  private async syncModelToRuntime(): Promise<void> { if (this.selectedModel.length === 0) { Logger.warn('No selected model configured.'); return; } const patch = new ConfigModelPatch(); patch.model = this.selectedModel; await this.httpService.patch<Object>(Constants.API_CONFIG, patch); await this.storageService?.setString(Constants.KEY_MODEL, this.selectedModel); }
  private async getRawMessages(sessionId: string): Promise<Object[]> { const raw = await this.httpService.get<Object>(this.sessionMessagesPath(sessionId)); return this.extractArray(raw, 'messages', 'data'); }
  private async waitForExecution(sessionId: string, beforeCount: number, maxAttempts: number = Constants.POLL_MAX_ATTEMPTS, intervalMs: number = Constants.POLL_INTERVAL_MS): Promise<ExecutionPollResult> { const r = new ExecutionPollResult(); for (let i=0;i<maxAttempts;i++){ await this.delay(intervalMs); try { const raw=await this.getRawMessages(sessionId); r.messageCount=raw.length; if(raw.length>beforeCount){ const s=this.inspectMessages(raw,beforeCount); r.hasAssistant=s.hasAssistant; r.hasTool=s.hasTool; r.hasError=s.hasError; r.hasPermission=s.hasPermission; if(s.hasError){r.ok=false; r.message=s.errorText.length>0?s.errorText:'Runtime 返回错误。'; return r;} if(s.hasPermission){r.ok=true; r.message='Runtime 正在等待权限确认。'; return r;} if(s.hasTool){r.ok=true; r.message='Runtime 已开始工具调用。'; return r;} if(s.hasAssistant){r.ok=true; r.message='assistant response received'; return r;} } } catch(err){ r.ok=false; r.message=`轮询消息失败：${String(err)}`; return r; }} r.timedOut=true; r.message='等待 assistant/tool/error/permission 超时。'; return r; }
  private inspectMessages(raw: Object[], beforeCount: number): ExecutionPollResult { const r = new ExecutionPollResult(); for(let i=beforeCount;i<raw.length;i++){ const item=raw[i] as Record<string,Object>; const info=item['info'] as Record<string,Object>; const role=info?(info['role'] as string):''; if(role==='assistant') r.hasAssistant=true; const parts=item['parts'] as Object[]; if(!parts) continue; for(const pa of parts){ const part=pa as Record<string,Object>; const type=(part['type'] as string)??''; const text=this.extractPartText(part); if(this.isToolType(type)) r.hasTool=true; if(this.isPermissionType(type)) r.hasPermission=true; if(this.isErrorType(type)||this.looksLikeError(text)){r.hasError=true; if(r.errorText.length===0) r.errorText=text.length>0?text:`Runtime error part: ${type}`;} }} return r; }
  private normalizeOpenCodeMessages(raw: Object[], sessionId: string): ChatMessage[] { const out: ChatMessage[]=[]; for(let i=0;i<raw.length;i++){ const item=raw[i] as Record<string,Object>; const info=item['info'] as Record<string,Object>; const roleStr=info?((info['role'] as string)??''):''; const id=info?((info['id'] as string)??''):''; const parts=(item['parts'] as Object[])??[]; const msg=new ChatMessage(); msg.id=id.length>0?id:`msg_${Date.now()}_${i}`; msg.sessionId=sessionId; msg.role=roleStr==='assistant'?MessageRole.Assistant:MessageRole.User; msg.timestamp=Date.now(); msg.status=MessageStatus.Complete; msg.isStreaming=false; const textParts:string[]=[]; for(const pa of parts){ const part=pa as Record<string,Object>; const type=(part['type'] as string)??''; const text=this.extractPartText(part); if(type==='text'&&text.length>0) textParts.push(text); else if(this.isErrorType(type)||this.looksLikeError(text)){ msg.isError=true; msg.status=MessageStatus.Error; textParts.push(text.length>0?text:`Runtime error: ${type}`); } else if(this.isToolType(type)){ const tool=new ToolCall(); tool.id=((part['id'] as string)??(part['callID'] as string)??''); tool.name=((part['tool'] as string)??(part['name'] as string)??type); tool.arguments=JSON.stringify(part['input']??part['args']??part['state']??''); tool.result=text; tool.status=type.includes('error')?'error':'complete'; msg.toolCalls.push(tool);} else if(text.length>0) textParts.push(text);} msg.content=textParts.join('\n\n'); if(msg.content.length===0&&msg.toolCalls.length>0) msg.content=`[${msg.toolCalls.length} tool call(s)]`; if(msg.content.length>0||msg.toolCalls.length>0) out.push(msg);} return out; }
  private extractArray(value:Object, key1:string, key2:string): Object[] { if(Array.isArray(value)) return value as Object[]; if(!value||typeof value!=='object') return []; const rec=value as Record<string,Object>; const c1=rec[key1]; if(Array.isArray(c1)) return c1 as Object[]; const c2=rec[key2]; if(Array.isArray(c2)) return c2 as Object[]; return []; }
  private extractStringArray(value:Object|undefined): string[] { if(!value||!Array.isArray(value)) return []; return value as string[]; }
  private isToolType(type:string): boolean { return type==='tool-invocation'||type==='tool'||type==='step-start'||type==='step-finish'||type==='tool-call'||type==='tool-result'; }
  private isPermissionType(type:string): boolean { return type==='permission'||type==='permission-request'||type==='tool-permission'; }
  private isErrorType(type:string): boolean { return type==='error'||type==='tool-error'||type==='provider-error'; }
  private extractPartText(part: Record<string,Object>): string { const direct=part['text']; if(typeof direct==='string'&&direct.length>0) return direct; const content=part['content']; if(typeof content==='string'&&content.length>0) return content; const state=part['state'] as Record<string,Object>; if(state){ const m=state['message']; if(typeof m==='string'&&m.length>0) return m; const e=state['error']; if(typeof e==='string'&&e.length>0) return e; const o=state['output']; if(typeof o==='string'&&o.length>0) return o; const rr=state['result']; if(typeof rr==='string'&&rr.length>0) return rr;} return ''; }
  private looksLikeError(text:string): boolean { if(text.length===0) return false; const t=text.toLowerCase(); return t.includes('error')||t.includes('exception')||t.includes('api key')||t.includes('auth')||t.includes('unauthorized')||t.includes('provider')||t.includes('model not found')||t.includes('invalid model'); }
  private sessionMessagesPath(sessionId:string): string { return `/session/${sessionId}/message`; }
  private sessionPromptAsyncPath(sessionId:string): string { return `/session/${sessionId}/prompt_async`; }
  private sessionAbortPath(sessionId:string): string { return `/session/${sessionId}/abort`; }
  private finalizeLastStreamingAssistant(): void { if(this.messages.length===0) return; const last=this.messages[this.messages.length-1]; if(last.role===MessageRole.Assistant&&last.isStreaming){ last.finalize(); this.messages=[...this.messages]; } }
  private async delay(ms:number): Promise<void> { return new Promise<void>((resolve)=>{ setTimeout(()=>resolve(), ms); }); }
  private onWsMessage(data:string): void { try { const parsed=JSON.parse(data) as Record<string,Object>; Logger.info(`Runtime ws event: ${(parsed['type'] as string)??'unknown'}`); } catch(err){ Logger.error(`onWsMessage parse error: ${String(err)}`); } }
  private onWsStatus(connected:boolean): void { Logger.info(`WebSocket status: ${connected?'connected':'disconnected'}`); }
  private startHealthCheck(): void { this.stopHealthCheck(); this.healthTimer=setInterval(()=>{ this.httpService.checkHealth().then((ok:boolean)=>{ this.serverInfo.healthOk=ok; if(!ok&&this.connectionStatus===ConnectionStatus.Connected) Logger.warn('Health check failed, Runtime may be down'); }); }, Constants.HEALTH_CHECK_INTERVAL_MS) as number; }
  private stopHealthCheck(): void { if(this.healthTimer>=0){ clearInterval(this.healthTimer); this.healthTimer=-1; } }
}
