import hilog from '@ohos.hilog';

const DOMAIN: number = 0xFF00;
const TAG: string = 'OpenCode';

export class Logger {
  static debug(msg: string): void {
    hilog.debug(DOMAIN, TAG, msg);
  }
  static info(msg: string): void {
    hilog.info(DOMAIN, TAG, msg);
  }
  static warn(msg: string): void {
    hilog.warn(DOMAIN, TAG, msg);
  }
  static error(msg: string): void {
    hilog.error(DOMAIN, TAG, msg);
  }
  static fatal(msg: string): void {
    hilog.fatal(DOMAIN, TAG, msg);
  }
}
