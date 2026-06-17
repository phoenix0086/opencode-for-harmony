/**
 * LocalRuntimeClient — wraps LocalRuntimeService to expose a unified API
 * that OpenCodeApiAdapter can route to in local-embedded mode.
 */

import { Logger } from '../utils/Logger';
import { errStr } from '../utils/ErrorUtil';
import { localRuntimeService } from './LocalRuntimeService';
import { LocalSession, LocalMessage, LocalPromptInput, LocalModelRef } from './LocalRuntimeTypes';

class LocalSessionInfo {
  id: string = '';
  name: string = '';
  createdAt: string = '';
  updatedAt: string = '';
  model: string = '';
  agent: string = '';
}

class LocalPromptResult {
  ok: boolean = false;
  error: string = '';
}

export class LocalRuntimeClient {

  async start(): Promise<Record<string, Object>> {
    const h = await localRuntimeService.start();
    const r: Record<string, Object> = {};
    r['ok'] = h.ok; r['version'] = h.version; r['mode'] = h.mode; r['message'] = h.message;
    return r;
  }

  async stop(): Promise<void> { await localRuntimeService.stop(); }

  // ══════════ Health ══════════
  health(): Record<string, Object> {
    const h = localRuntimeService.health();
    const r: Record<string, Object> = {};
    r['healthy'] = h.ok; r['version'] = h.version; r['mode'] = h.mode; r['message'] = h.message;
    return r;
  }

  // ══════════ Config ══════════
  getConfig(): Record<string, Object> { return localRuntimeService.getConfig(); }
  patchConfig(body: Record<string, Object>): void { localRuntimeService.updateConfig(body); }

  // ══════════ Providers ══════════
  listProviders(): Record<string, Object> {
    const list = localRuntimeService.listProviders();
    const r: Record<string, Object> = {};
    r['all'] = list.all as Object;
    r['connected'] = list.connected as Object;
    r['defaults'] = list.defaults as Object;
    return r;
  }
  listModels(): Object[] {
    const providers = localRuntimeService.listProviders();
    const out: Object[] = [];
    for (let i = 0; i < providers.all.length; i++) {
      const p = providers.all[i];
      for (let j = 0; j < p.models.length; j++) {
        const m = p.models[j];
        const obj: Record<string, Object> = {};
        obj['id'] = m.id;
        obj['name'] = m.name;
        obj['providerID'] = p.id;
        obj['contextLength'] = m.contextLength;
        obj['maxOutputTokens'] = m.maxOutputTokens;
        out.push(obj);
      }
    }
    return out;
  }

  // ══════════ Sessions ══════════
  listSessions(): LocalSessionInfo[] {
    const sessions = localRuntimeService.listSessions();
    const out: LocalSessionInfo[] = [];
    for (let i = 0; i < sessions.length; i++) {
      out.push(this.toSessionInfo(sessions[i]));
    }
    return out;
  }

  async createSession(input?: Record<string, Object>): Promise<LocalSessionInfo> {
    const s = await localRuntimeService.createSession(input);
    return this.toSessionInfo(s);
  }

  getSession(sessionId: string): LocalSessionInfo {
    const sessions = localRuntimeService.listSessions();
    for (let i = 0; i < sessions.length; i++) {
      if (sessions[i].id === sessionId) return this.toSessionInfo(sessions[i]);
    }
    return new LocalSessionInfo();
  }

  deleteSession(sessionId: string): boolean { return localRuntimeService.deleteSession(sessionId); }

  // ══════════ Messages ══════════
  listMessages(sessionId: string): Object[] {
    const msgs = localRuntimeService.listMessages(sessionId);
    const out: Object[] = [];
    for (let i = 0; i < msgs.length; i++) { out.push(this.toApiMessage(msgs[i])); }
    return out;
  }

  // ══════════ Prompt ══════════
  async sendPrompt(sessionId: string, text: string, model: string = '', agent: string = 'build'): Promise<LocalPromptResult> {
    const result = new LocalPromptResult();
    let providerID = '';
    let modelID = model;
    if (model.includes('/')) {
      const parts = model.split('/');
      providerID = parts[0];
      modelID = parts.length > 1 ? parts[1] : model;
    }
    const modelRef = new LocalModelRef();
    modelRef.providerID = providerID;
    modelRef.id = modelID;
    modelRef.variant = '';
    const localInput = new LocalPromptInput();
    localInput.text = text;
    localInput.model = modelRef;
    localInput.agent = agent;
    const r = await localRuntimeService.sendPrompt(sessionId, localInput);
    result.ok = r.ok;
    result.error = r.error;
    return result;
  }

  // ══════════ Wait / Context ══════════
  waitSession(_sessionId: string): Record<string, Object> { return {}; }
  getSessionContext(_sessionId: string): Record<string, Object> { return {}; }

  // ══════════ Abort ══════════
  abortSession(sessionId: string): boolean { return localRuntimeService.abortSession(sessionId); }

  // ══════════ Permissions ══════════
  listPermissionRequests(): Object[] { return localRuntimeService.listPendingPermissions() as Object[]; }
  listSavedPermissions(): Object[] { return []; }
  deleteSavedPermission(_id: string): boolean { return false; }
  listSessionPermissions(_sessionId: string): Object[] { return []; }
  replyPermission(_sessionId: string, requestId: string, reply: string): boolean {
    if (reply === 'deny') return localRuntimeService.denyPermission(requestId);
    return localRuntimeService.approvePermission(requestId);
  }

  // ══════════ Questions ══════════
  listQuestions(_sessionId: string): Object[] { return []; }
  replyQuestion(_sessionId: string, _requestId: string, _optionIDs: string[]): boolean { return false; }
  rejectQuestion(_sessionId: string, _requestId: string): boolean { return false; }

  // ══════════ Commands / Skills ══════════
  listCommands(): Object[] { return []; }
  listSkills(): Object[] { return []; }

  // ══════════ Files ══════════
  listFiles(path: string): Object[] {
    // Synchronous wrapper — returns empty, actual calls go through readFile/listDirectory
    return [];
  }
  findFiles(_query: string): Object[] { return []; }
  async readFile(filePath: string): Promise<Record<string, Object>> {
    const r = await localRuntimeService.readFile(filePath);
    const out: Record<string, Object> = {};
    out['ok'] = r.ok; out['content'] = r.content; out['error'] = r.error;
    return out;
  }
  async listDirectory(dirPath: string): Promise<Object[]> {
    const r = await localRuntimeService.listDirectory(dirPath);
    return r.entries;
  }
  async searchText(query: string, dirPath: string = ''): Promise<Object[]> {
    const r = await localRuntimeService.searchText(query, dirPath);
    return r.matches;
  }

  // ══════════ Events ══════════
  getEventUrl(): string { return ''; }

  // ══════════ Model Management ══════════
  getDefaultModelRef(): Record<string, Object> {
    const ref = localRuntimeService.getDefaultModelRef();
    const r: Record<string, Object> = {};
    r['providerID'] = ref.providerID; r['id'] = ref.id;
    return r;
  }
  setDefaultModel(providerID: string, modelID: string): void {
    localRuntimeService.setDefaultModel(providerID, modelID);
  }

  // ══════════ Converters ══════════
  private toSessionInfo(s: LocalSession): LocalSessionInfo {
    const info = new LocalSessionInfo();
    info.id = s.id || '';
    info.name = s.title || '';
    info.createdAt = String(s.createdAt || 0);
    info.updatedAt = String(s.updatedAt || 0);
    info.model = s.modelID || '';
    info.agent = 'build';
    return info;
  }

  private toApiMessage(m: LocalMessage): Record<string, Object> {
    const r: Record<string, Object> = {};
    const info: Record<string, Object> = {};
    info['id'] = m.id || '';
    info['role'] = m.role || 'user';
    info['sessionID'] = m.sessionID || '';
    info['agent'] = m.agent || 'build';
    const model: Record<string, Object> = {};
    model['id'] = m.modelID || '';
    model['providerID'] = m.providerID || '';
    info['model'] = model;
    const time: Record<string, Object> = {};
    time['created'] = m.createdAt || 0;
    info['time'] = time;
    info['status'] = m.status || 'completed';
    r['info'] = info;

    const parts: Object[] = [];
    const content = m.content || '';
    if (content.length > 0) {
      const part: Record<string, Object> = {};
      part['type'] = 'text'; part['text'] = content; part['id'] = `prt_${info['id']}_text`;
      parts.push(part);
    }
    const error = m.error || '';
    if (error.length > 0) {
      const part: Record<string, Object> = {};
      part['type'] = 'error'; part['text'] = error; part['id'] = `prt_${info['id']}_error`;
      parts.push(part);
    }
    r['parts'] = parts;
    return r;
  }
}

export const localRuntimeClient = new LocalRuntimeClient();
