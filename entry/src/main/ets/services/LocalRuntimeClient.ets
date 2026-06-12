/**
 * LocalRuntimeClient — wraps LocalRuntimeService to expose a unified API
 * that OpenCodeApiAdapter can route to in local-embedded mode.
 *
 * This is the "local backend" that replaces the remote HTTP calls
 * when the app runs in local-embedded mode.
 */

import { Logger } from '../utils/Logger';
import { errStr } from '../utils/ErrorUtil';
import { localRuntimeService } from './LocalRuntimeService';
import {
  RuntimeMode, RuntimeHealth, LocalProviderList,
  LocalSession, LocalMessage, LocalPromptInput, LocalPromptResult,
  LocalModelRef, RuntimeEvent
} from './LocalRuntimeTypes';

export class LocalRuntimeClient {

  // ══════════ Lifecycle ╂═════════

  async start(): Promise<RuntimeHealth> {
    return await localRuntimeService.start();
  }

  async stop(): Promise<void> {
    await localRuntimeService.stop();
  }

  // ══════════ Health ══════════

  health(): Record<string, Object> {
    const h = localRuntimeService.health();
    const result: Record<string, Object> = {};
    result['healthy'] = h.ok;
    result['version'] = h.version;
    result['mode'] = h.mode;
    result['message'] = h.message;
    result['uptime'] = h.uptime;
    return result;
  }

  // ══════════ Config ══════════

  getConfig(): Record<string, Object> {
    return localRuntimeService.getConfig();
  }

  updateConfig(patch: Record<string, Object>): Record<string, Object> {
    return localRuntimeService.updateConfig(patch);
  }

  // ══════════ Providers ══════════

  listProviders(): Record<string, Object> {
    const list = localRuntimeService.listProviders();
    const result: Record<string, Object> = {};
    result['all'] = list.all as Object;
    result['connected'] = list.connected as Object;
    result['defaults'] = list.defaults as Object;
    return result;
  }

  async setProviderAuth(providerID: string, apiKey: string): Promise<boolean> {
    return await localRuntimeService.setProviderAuth(providerID, apiKey);
  }

  async removeProviderAuth(providerID: string): Promise<boolean> {
    return await localRuntimeService.removeProviderAuth(providerID);
  }

  // ══════════ Sessions ══════════

  listSessions(): Object[] {
    const sessions = localRuntimeService.listSessions();
    const result: Object[] = [];
    for (let i = 0; i < sessions.length; i++) {
      result.push(this.sessionToApi(sessions[i]));
    }
    return result;
  }

  createSession(input?: Record<string, Object>): Record<string, Object> {
    const session = localRuntimeService.createSession(input);
    return this.sessionToApi(session);
  }

  deleteSession(sessionID: string): boolean {
    return localRuntimeService.deleteSession(sessionID);
  }

  // ══════════ Messages ══════════

  listMessages(sessionID: string): Object[] {
    const messages = localRuntimeService.listMessages(sessionID);
    const result: Object[] = [];
    for (let i = 0; i < messages.length; i++) {
      result.push(this.messageToApi(messages[i]));
    }
    return result;
  }

  // ══════════ Prompt ══════════

  async sendPrompt(sessionID: string, text: string, modelRef?: LocalModelRef): Promise<Record<string, Object>> {
    const input = new LocalPromptInput();
    input.text = text;
    if (modelRef !== undefined) {
      input.model = modelRef;
    }

    const result = await localRuntimeService.sendPrompt(sessionID, input);
    const response: Record<string, Object> = {};
    response['ok'] = result.ok;
    response['messageID'] = result.messageID;
    response['error'] = result.error;
    return response;
  }

  // ══════════ Abort ══════════

  abortSession(sessionID: string): boolean {
    return localRuntimeService.abortSession(sessionID);
  }

  // ══════════ Events ══════════

  addEventListener(listener: (event: RuntimeEvent) => void): void {
    localRuntimeService.addEventListener(listener);
  }

  removeEventListener(listener: (event: RuntimeEvent) => void): void {
    localRuntimeService.removeEventListener(listener);
  }

  // ══════════ Model Management ══════════

  getDefaultModelRef(): LocalModelRef {
    return localRuntimeService.getDefaultModelRef();
  }

  setDefaultModel(providerID: string, modelID: string): void {
    localRuntimeService.setDefaultModel(providerID, modelID);
  }

  // ══════════ Format Converters ══════════

  private sessionToApi(s: LocalSession): Record<string, Object> {
    const result: Record<string, Object> = {};
    result['id'] = s.id;
    result['title'] = s.title;
    result['name'] = s.title;
    result['directory'] = s.workspace;
    result['agent'] = 'build';
    result['cost'] = 0;

    const model: Record<string, Object> = {};
    model['id'] = s.modelID;
    model['providerID'] = s.providerID;
    model['variant'] = 'default';
    result['model'] = model;

    const time: Record<string, Object> = {};
    time['created'] = s.createdAt;
    time['updated'] = s.updatedAt;
    result['time'] = time;

    const tokens: Record<string, Object> = {};
    tokens['input'] = 0;
    tokens['output'] = 0;
    tokens['reasoning'] = 0;
    result['tokens'] = tokens;

    result['messageCount'] = s.messageCount;

    return result;
  }

  private messageToApi(m: LocalMessage): Record<string, Object> {
    const result: Record<string, Object> = {};

    const info: Record<string, Object> = {};
    info['id'] = m.id;
    info['role'] = m.role;
    info['sessionID'] = m.sessionID;
    info['agent'] = 'build';

    const model: Record<string, Object> = {};
    model['id'] = m.modelID;
    model['providerID'] = m.providerID;
    info['model'] = model;

    const time: Record<string, Object> = {};
    time['created'] = m.createdAt;
    info['time'] = time;

    result['info'] = info;

    const parts: Object[] = [];

    if (m.role === 'assistant' && m.status === 'streaming') {
      // Streaming indicator
      const part: Record<string, Object> = {};
      part['type'] = 'step-start';
      part['text'] = '';
      parts.push(part);
    }

    if (m.content.length > 0 || m.role === 'user') {
      const part: Record<string, Object> = {};
      part['type'] = 'text';
      part['text'] = m.content;
      part['id'] = `prt_${m.id}_text`;
      parts.push(part);
    }

    if (m.error.length > 0) {
      const part: Record<string, Object> = {};
      part['type'] = 'error';
      part['text'] = m.error;
      part['id'] = `prt_${m.id}_error`;
      parts.push(part);
    }

    result['parts'] = parts;

    return result;
  }
}

export const localRuntimeClient = new LocalRuntimeClient();
