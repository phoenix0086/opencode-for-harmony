import { fileIo } from '@kit.CoreFileKit';
import util from '@ohos.util';
import { Logger } from '../utils/Logger';

/**
 * File system operations for reading/writing project files.
 */
export class FileService {

  async readFile(path: string): Promise<string> {
    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(path);
      const buffer = new ArrayBuffer(stat.size);
      const bytesRead = fileIo.readSync(file.fd, buffer);
      fileIo.closeSync(file);
      const decoder = new util.TextDecoder('utf-8');
      return decoder.decode(new Uint8Array(buffer, 0, bytesRead));
    } catch (err) {
      Logger.error('FileService readFile error: ' + String(String(err)));
      throw new Error(String(err));
    }
  }

  async writeFile(path: string, content: string): Promise<void> {
    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      const encoder = new util.TextEncoder();
      const buffer = encoder.encodeInto(content);
      fileIo.writeSync(file.fd, buffer);
      fileIo.closeSync(file);
    } catch (err) {
      Logger.error('FileService writeFile error: ' + String(String(err)));
      throw new Error(String(err));
    }
  }

  async listDirectory(path: string): Promise<string[]> {
    try {
      return fileIo.listFileSync(path);
    } catch (err) {
      Logger.error('FileService listDirectory error: ' + String(String(err)));
      throw new Error(String(err));
    }
  }

  async exists(path: string): Promise<boolean> {
    try {
      fileIo.statSync(path);
      return true;
    } catch {
      return false;
    }
  }

  async mkdir(path: string): Promise<void> {
    try {
      fileIo.mkdirSync(path);
    } catch (err) {
      Logger.error('FileService mkdir error: ' + String(String(err)));
      throw new Error(String(err));
    }
  }

  async remove(path: string): Promise<void> {
    try {
      const stat = fileIo.statSync(path);
      if (stat.isDirectory()) {
        fileIo.rmdirSync(path);
      } else {
        fileIo.unlinkSync(path);
      }
    } catch (err) {
      Logger.error('FileService remove error: ' + String(String(err)));
      throw new Error(String(err));
    }
  }

  getFileName(path: string): string {
    const parts = path.split('/');
    return parts.length > 0 ? parts[parts.length - 1] : path;
  }

  getExtension(path: string): string {
    const name = this.getFileName(path);
    const dotIdx = name.lastIndexOf('.');
    return dotIdx > 0 ? name.substring(dotIdx + 1) : '';
  }

  isTextFile(extension: string): boolean {
    const textExts: string[] = [
      'ts', 'tsx', 'js', 'jsx', 'json', 'json5', 'jsonc',
      'md', 'txt', 'html', 'css', 'scss', 'less',
      'py', 'rb', 'go', 'rs', 'java', 'kt', 'swift',
      'c', 'cpp', 'h', 'hpp', 'cs',
      'yaml', 'yml', 'toml', 'xml', 'svg',
      'sh', 'bash', 'zsh', 'fish',
      'ets', 'hap'
    ];
    return textExts.includes(extension.toLowerCase());
  }
}
