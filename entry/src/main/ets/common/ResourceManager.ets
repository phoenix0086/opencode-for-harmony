import { Logger } from '../utils/Logger';
import { errStr } from '../utils/ErrorUtil';

/**
 * Utility for accessing app resources at runtime.
 * Provides helpers for reading rawfile content and managing resource references.
 */
export class ResourceManager {
  private context: Context;

  constructor(context: Context) {
    this.context = context;
  }

  async readRawFile(fileName: string): Promise<string> {
    try {
      const mgr = this.context.resourceManager;
      const rawFile = await mgr.getRawFileContent(fileName);
      const decoder = new util.TextDecoder('utf-8');
      return decoder.decode(rawFile);
    } catch (err) {
      Logger.error('ResourceManager readRawFile error: ' + errStr(err));
      throw new Error(errStr(err));
    }
  }

  async getRawFileUri(fileName: string): Promise<string> {
    try {
      return 'resource://rawfile/' + fileName;
    } catch (err) {
      Logger.error('ResourceManager getRawFileUri error: ' + errStr(err));
      throw new Error(errStr(err));
    }
  }

  async rawFileExists(fileName: string): Promise<boolean> {
    try {
      const mgr = this.context.resourceManager;
      await mgr.getRawFileContent(fileName);
      return true;
    } catch {
      return false;
    }
  }

  getString(resId: number): string {
    try {
      return this.context.resourceManager.getStringSync(resId);
    } catch (err) {
      Logger.error('ResourceManager getString error: ' + errStr(err));
      return '';
    }
  }
}

import util from '@ohos.util';
