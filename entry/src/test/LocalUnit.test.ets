/**
 * Unit tests for slash command parsing and V2 endpoint detection.
 * 跑法: hvigorw test --module entry --test unittest
 *
 * Uses HarmonyOS Hypium framework. Tests are wrapped in describe/it blocks.
 */

import { describe, it, expect } from '@ohos/hypium'
import {
  parseSlashCommand,
  buildHelpText,
  slashRegistry
} from '../main/ets/services/SlashCommandService'
import { UnsupportedV2Endpoint } from '../main/ets/services/V2Type'
import { i18n } from '../main/ets/services/I18nService'
import { ServerInfo } from '../main/ets/model/ServerInfo'

export default function slashCommandUnitTest() {
  describe('SlashCommandService', () => {
    it('parses simple /help', 0, () => {
      const r = parseSlashCommand('/help')
      expect(r !== null).assertTrue()
      if (r === null) return
      expect(r.command.name).assertEqual('help')
      expect(r.args).assertEqual('')
    })

    it('parses /new with title', 0, () => {
      const r = parseSlashCommand('/new my new session')
      expect(r !== null).assertTrue()
      if (r === null) return
      expect(r.command.name).assertEqual('new')
      expect(r.args).assertEqual('my new session')
    })

    it('returns null for non-slash input', 0, () => {
      const r = parseSlashCommand('hello world')
      expect(r).assertNull()
    })

    it('returns null for empty input', 0, () => {
      expect(parseSlashCommand('')).assertNull()
      expect(parseSlashCommand('   ')).assertNull()
    })

    it('returns null for unknown command', 0, () => {
      const r = parseSlashCommand('/nonexistent')
      expect(r).assertNull()
    })

    it('handles leading whitespace', 0, () => {
      const r = parseSlashCommand('  /clear')
      expect(r !== null).assertTrue()
      if (r === null) return
      expect(r.command.name).assertEqual('clear')
    })

    it('help text is non-empty', 0, () => {
      const t = buildHelpText('')
      expect(t.length).assertLarger(0)
    })
  })

  describe('V2 UnsupportedV2Endpoint', () => {
    it('constructs with path and status', 0, () => {
      const e = new UnsupportedV2Endpoint('/snapshot', 404)
      expect(e.endpoint).assertEqual('/snapshot')
      expect(e.statusCode).assertEqual(404)
      expect(e.name).assertEqual('UnsupportedV2Endpoint')
    })
  })

  describe('I18nService', () => {
    it('returns English by default for en-US locale', 0, () => {
      i18n.setLocale('en-US')
      const v = i18n.t('sidebar.chat')
      expect(v).assertEqual('Chat')
    })

    it('returns Chinese for zh-CN locale', 0, () => {
      i18n.setLocale('zh-CN')
      const v = i18n.t('sidebar.chat')
      expect(v).assertEqual('对话')
      expect(i18n.t('sidebar.sessions')).assertEqual('历史会话')
      expect(i18n.t('composer.send')).assertEqual('发送')
    })

    it('falls back to key when not found', 0, () => {
      i18n.setLocale('en-US')
      const v = i18n.t('nonexistent.key')
      expect(v).assertEqual('nonexistent.key')
    })
  })

  describe('ServerInfo', () => {
    it('creates padded Basic auth header', 0, () => {
      const server = new ServerInfo()
      server.username = 'opencode'
      server.password = 'p'
      expect(server.getAuthHeader()).assertEqual('Basic b3BlbmNvZGU6cA==')
    })

    it('omits auth when credentials are incomplete', 0, () => {
      const server = new ServerInfo()
      server.username = 'opencode'
      expect(server.getAuthHeader()).assertEqual('')
    })
  })
}
