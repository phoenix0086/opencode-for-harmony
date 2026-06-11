import { http } from '@kit.NetworkKit';
import { Logger } from '../utils/Logger';
import { errStr } from '../utils/ErrorUtil';

/**
 * Server capability detection for OpenCode Runtime.
 * Probes /api/health (v2) and /global/health (legacy) to determine server mode.
 */
export type ServerMode = 'api-v2' | 'legacy' | 'unknown';

export interface Capabilities {
  fs: boolean;
  sessionPrompt: boolean;
  sessionWait: boolean;
  sessionContext: boolean;
  permissionSaved: boolean;
  questionReject: boolean;
  connector: boolean;
  eventStream: boolean;
  command: boolean;
  skill: boolean;
  pty: boolean;
  mcp: boolean;
}

export interface CapabilityResult {
  mode: ServerMode;
  version: string;
  capabilities: Capabilities;
  raw: Record<string, Object>;
}

export class OpenCodeCapabilities {
  private baseUrl: string = '';

  setBaseUrl(url: string): void {
    this.baseUrl = url.replace(/\/+$/, '');
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

  private async probeHealth(path: string): Promise<{ ok: boolean; data: Record<string, Object> }> {
    try {
      const httpRequest = http.createHttp();
      try {
        const response = await httpRequest.request(this.baseUrl + path, {
          method: http.RequestMethod.GET,
          header: { 'Accept': 'application/json' },
          connectTimeout: 5000,
          readTimeout: 5000,
          expectDataType: http.HttpDataType.OBJECT
        });
        if (response.responseCode >= 200 && response.responseCode < 300) {
          const data = this.parseObject(response.result);
          return { ok: true, data };
        }
        return { ok: false, data: {} };
      } finally {
        httpRequest.destroy();
      }
    } catch (e) {
      Logger.debug(`Health probe ${path} failed: ${errStr(e)}`);
      return { ok: false, data: {} };
    }
  }

  private buildResult(mode: ServerMode, raw: Record<string, Object>): CapabilityResult {
    const caps: Capabilities = {
      fs: mode === 'api-v2',
      sessionPrompt: mode === 'api-v2',
      sessionWait: mode === 'api-v2',
      sessionContext: mode === 'api-v2',
      permissionSaved: mode === 'api-v2',
      questionReject: mode === 'api-v2',
      connector: mode === 'api-v2',
      eventStream: mode === 'api-v2',
      command: mode === 'api-v2',
      skill: mode === 'api-v2',
      pty: false,
      mcp: false,
    };

    // Legacy mode: basic chat only
    if (mode === 'legacy') {
      caps.sessionPrompt = true;
      caps.sessionWait = true;
    }

    const version = (raw['version'] as string) ?? (raw['v'] as string) ?? 'unknown';

    return { mode, version, capabilities: caps, raw };
  }

  private parseObject(result: Object | string | ArrayBuffer | undefined | null): Record<string, Object> {
    if (result === undefined || result === null) return {};
    if (typeof result === 'string') {
      try { return JSON.parse(result) as Record<string, Object>; } catch (_) { return {}; }
    }
    return result as Record<string, Object>;
  }
}