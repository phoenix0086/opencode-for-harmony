import { http } from '@kit.NetworkKit';
import { Logger } from '../utils/Logger';
import { errStr } from '../utils/ErrorUtil';

/**
 * Server capability detection for OpenCode Runtime.
 * Probes /api/health (v2) and /global/health (legacy) to determine server mode.
 */
export type ServerMode = 'api-v2' | 'legacy' | 'unknown';

export class Capabilities {
  fs: boolean = false;
  sessionPrompt: boolean = false;
  sessionWait: boolean = false;
  sessionContext: boolean = false;
  permissionSaved: boolean = false;
  questionReject: boolean = false;
  connector: boolean = false;
  eventStream: boolean = false;
  command: boolean = false;
  skill: boolean = false;
  pty: boolean = false;
  mcp: boolean = false;
}

export class CapabilityResult {
  mode: ServerMode = 'unknown';
  version: string = '';
  capabilities: Capabilities = new Capabilities();
  raw: Record<string, Object> = {};
}

class ProbeResult {
  ok: boolean = false;
  data: Record<string, Object> = {};
}

export class OpenCodeCapabilities {
  private baseUrl: string = '';
  private authHeader: string = '';

  setBaseUrl(url: string): void {
    this.baseUrl = url.replace(/\/+$/, '');
  }

  setAuthHeader(header: string): void {
    this.authHeader = header;
  }

  async detect(): Promise<CapabilityResult> {
    // Try api-v2 first
    const v2 = await this.probeHealth('/api/health');
    if (v2.ok) {
      Logger.info('Capability detection: api-v2 server detected');
      return this.buildResult('api-v2', v2.data);
    }

    // Fallback to legacy
    const legacy = await this.probeHealth('/global/health');
    if (legacy.ok) {
      Logger.info('Capability detection: legacy server detected');
      return this.buildResult('legacy', legacy.data);
    }

    Logger.warn('Capability detection: unknown server mode');
    return this.buildResult('unknown', {});
  }

  private async probeHealth(path: string): Promise<ProbeResult> {
    const result = new ProbeResult();
    try {
      const httpRequest = http.createHttp();
      try {
        const hdrs: Record<string, string> = {};
        hdrs['Accept'] = 'application/json';
        if (this.authHeader.length > 0) { hdrs['Authorization'] = this.authHeader; }
        const response = await httpRequest.request(this.baseUrl + path, {
          method: http.RequestMethod.GET,
          header: hdrs,
          connectTimeout: 5000,
          readTimeout: 5000,
          expectDataType: http.HttpDataType.OBJECT
        });
        if (response.responseCode >= 200 && response.responseCode < 300) {
          result.ok = true;
          result.data = this.parseObject(response.result);
          return result;
        }
        return result;
      } finally {
        httpRequest.destroy();
      }
    } catch (e) {
      Logger.debug(`Health probe ${path} failed: ${errStr(e)}`);
      return result;
    }
  }

  private buildResult(mode: ServerMode, raw: Record<string, Object>): CapabilityResult {
    const caps = new Capabilities();
    caps.fs = mode === 'api-v2';
    caps.sessionPrompt = mode === 'api-v2';
    // OpenCode 1.18 exposes /api/session/:id/wait but returns 503
    // ("Session wait is not available yet"). The client uses message polling.
    caps.sessionWait = false;
    caps.sessionContext = mode === 'api-v2';
    caps.permissionSaved = mode === 'api-v2';
    caps.questionReject = mode === 'api-v2';
    caps.connector = mode === 'api-v2';
    caps.eventStream = mode === 'api-v2';
    caps.command = mode === 'api-v2';
    caps.skill = mode === 'api-v2';
    caps.pty = false;
    caps.mcp = false;

    // Legacy mode: basic chat only
    if (mode === 'legacy') {
      caps.sessionPrompt = true;
      caps.sessionWait = true;
    }

    const result = new CapabilityResult();
    result.mode = mode;
    result.version = (raw['version'] as string) ?? (raw['v'] as string) ?? 'unknown';
    result.capabilities = caps;
    result.raw = raw;
    return result;
  }

  private parseObject(result: Object | string | ArrayBuffer | undefined | null): Record<string, Object> {
    if (result === undefined || result === null) return {};
    if (typeof result === 'string') {
      try { return JSON.parse(result) as Record<string, Object>; } catch (_) { return {}; }
    }
    return result as Record<string, Object>;
  }
}
