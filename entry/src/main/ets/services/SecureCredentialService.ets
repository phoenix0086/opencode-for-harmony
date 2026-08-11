import { asset } from '@kit.AssetStoreKit'
import { util } from '@kit.ArkTS'
import { Logger } from '../utils/Logger'
import { errStr } from '../utils/ErrorUtil'

const PROVIDER_KEY_PREFIX = 'ohopencode.provider.api-key.'
const SERVER_PASSWORD_ALIAS = 'ohopencode.server.password.default'

/** Stores provider API keys outside Preferences in the system Asset Store. */
export class SecureCredentialService {
  private encoder: util.TextEncoder = util.TextEncoder.create('utf-8')
  private decoder: util.TextDecoder = util.TextDecoder.create('utf-8')

  private alias(providerId: string): Uint8Array {
    return this.encoder.encodeInto(`${PROVIDER_KEY_PREFIX}${providerId}`)
  }

  private serverPasswordAlias(): Uint8Array {
    return this.encoder.encodeInto(SERVER_PASSWORD_ALIAS)
  }

  private async setSecret(alias: Uint8Array, secret: string, logLabel: string): Promise<boolean> {
    if (secret.length === 0) {
      await this.removeSecret(alias)
      return true
    }

    const attributes: asset.AssetMap = new Map<asset.Tag, asset.Value>()
    attributes.set(asset.Tag.ALIAS, alias)
    attributes.set(asset.Tag.SECRET, this.encoder.encodeInto(secret))
    attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED)
    attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE)
    try {
      await asset.add(attributes)
      return true
    } catch (e) {
      Logger.warn(`Secure credential write failed for ${logLabel}: ${errStr(e)}`)
      return false
    }
  }

  private async getSecret(alias: Uint8Array): Promise<string> {
    const query: asset.AssetMap = new Map<asset.Tag, asset.Value>()
    query.set(asset.Tag.ALIAS, alias)
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL)
    try {
      const result = await asset.query(query)
      if (result.length === 0) return ''
      const secret = result[0].get(asset.Tag.SECRET)
      if (!(secret instanceof Uint8Array)) return ''
      return this.decoder.decodeToString(secret)
    } catch (e) {
      return ''
    }
  }

  private async removeSecret(alias: Uint8Array): Promise<void> {
    const query: asset.AssetMap = new Map<asset.Tag, asset.Value>()
    query.set(asset.Tag.ALIAS, alias)
    try {
      await asset.remove(query)
    } catch (e) {
      // Removing a credential is idempotent.
    }
  }

  async setProviderApiKey(providerId: string, apiKey: string): Promise<boolean> {
    if (providerId.length === 0) return false
    return this.setSecret(this.alias(providerId), apiKey, providerId)
  }

  async getProviderApiKey(providerId: string): Promise<string> {
    if (providerId.length === 0) return ''
    return this.getSecret(this.alias(providerId))
  }

  async removeProviderApiKey(providerId: string): Promise<void> {
    if (providerId.length === 0) return
    await this.removeSecret(this.alias(providerId))
  }

  async setServerPassword(password: string): Promise<boolean> {
    return this.setSecret(this.serverPasswordAlias(), password, 'OpenCode server')
  }

  async getServerPassword(): Promise<string> {
    return this.getSecret(this.serverPasswordAlias())
  }

  async removeServerPassword(): Promise<void> {
    await this.removeSecret(this.serverPasswordAlias())
  }
}

export const secureCredentialService = new SecureCredentialService()
