import hilog from '@ohos.hilog';

const DOMAIN: number = 0xFF00;
const TAG: string = 'OpenCode';

export class Logger {
  static debug(msg: string, ...args: string[]): void {
    hilog.debug(DOMAIN, TAG, msg, args as object[]);
  }

  static info(msg: string, ...args: string[]): void {
    hilog.info(DOMAIN, TAG, msg, args as object[]);
  }

  static warn(msg: string, ...args: string[]): void {
    hilog.warn(DOMAIN, TAG, msg, args as object[]);
  }

  static error(msg: string, ...args: string[]): void {
    hilog.error(DOMAIN, TAG, msg, args as object[]);
  }

  static fatal(msg: string, ...args: string[]): void {
    hilog.fatal(DOMAIN, TAG, msg, args as object[]);
  }
}
