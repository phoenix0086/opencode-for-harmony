import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';
import { Logger } from '../utils/Logger';

const TAG: string = 'EntryBackupAbility';

/**
 * Backup extension ability for HarmonyOS backup/restore.
 * Ensures app preferences and local data are included in device backups.
 */
export default class EntryBackupAbility extends BackupExtensionAbility {
  onBackup(): void {
    Logger.info(': onBackup called' + String(TAG));
  }

  onRestore(bundleVersion: BundleVersion): void {
    Logger.info('%{public}s: onRestore called, version=%{public}s',
      TAG, JSON.stringify(bundleVersion));
  }
}
