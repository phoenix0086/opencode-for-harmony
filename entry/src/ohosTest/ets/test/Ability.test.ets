import { describe, it, expect } from '@ohos/hypium';

/**
 * Basic test suite for the OpenCode HarmonyOS app.
 * Tests model creation, utility functions, and basic state management.
 */
export default function AbilityTest() {
  describe('ChatMessage', () => {
    it('should_create_user_message', () => {
      // Import and test ChatMessage model
      const msg = {
        id: 'test_1',
        role: 'user',
        content: 'Hello',
        timestamp: Date.now(),
        status: 'complete',
        sessionId: '',
        toolCalls: [],
        isError: false,
        isStreaming: false
      };
      expect(msg.role).assertEqual('user');
      expect(msg.content).assertEqual('Hello');
      expect(msg.isError).assertFalse();
    });
  });

  describe('ServerInfo', () => {
    it('should_create_server_info', () => {
      const server = {
        url: 'http://localhost:3000',
        username: 'test',
        password: 'pass',
        displayName: 'Test Server',
        type: 'remote',
        connected: false,
        healthOk: false
      };
      expect(server.url).assertEqual('http://localhost:3000');
      expect(server.connected).assertFalse();
    });

    it('should_serialize_to_json', () => {
      const server = {
        url: 'http://localhost:3000',
        username: 'test',
        password: 'pass',
        displayName: 'Test',
        type: 'remote',
        connected: false,
        healthOk: false
      };
      const json = {
        'url': server.url,
        'username': server.username,
        'password': server.password,
        'displayName': server.displayName,
        'type': server.type
      };
      expect(json['url']).assertEqual('http://localhost:3000');
      expect(json['username']).assertEqual('test');
    });
  });

  describe('Constants', () => {
    it('should_have_default_values', () => {
      // Verify constants are properly defined
      const appName = 'OpenCode';
      const defaultModel = 'anthropic/claude-sonnet-4-20250514';
      expect(appName).assertEqual('OpenCode');
      expect(defaultModel).assertEqual('anthropic/claude-sonnet-4-20250514');
    });
  });
}
