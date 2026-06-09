/**
 * Server connection information model.
 */
export class ServerInfo {
  url: string = '';
  username: string = '';
  password: string = '';
  displayName: string = 'Local Server';
  type: string = 'remote'; // 'local' | 'remote'
  connected: boolean = false;
  healthOk: boolean = false;

  static fromJson(json: Record<string, Object>): ServerInfo {
    const info = new ServerInfo();
    info.url = (json['url'] as string) ?? '';
    info.username = (json['username'] as string) ?? '';
    info.password = (json['password'] as string) ?? '';
    info.displayName = (json['displayName'] as string) ?? 'Local Server';
    info.type = (json['type'] as string) ?? 'remote';
    return info;
  }

  toJson(): Record<string, string> {
    return {
      'url': this.url,
      'username': this.username,
      'password': this.password,
      'displayName': this.displayName,
      'type': this.type
    };
  }

  getAuthHeader(): string {
    if (this.username.length > 0 && this.password.length > 0) {
      // Base64 encode "username:password"
      const combined = this.username + ':' + this.password;
      return 'Basic ' + utilBase64Encode(combined);
    }
    return '';
  }
}

function utilBase64Encode(input: string): string {
  // Simple base64 encoding for basic auth
  const chars: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  let result: string = '';
  let i: number = 0;
  while (i < input.length) {
    const a: number = input.charCodeAt(i++);
    const b: number = i < input.length ? input.charCodeAt(i++) : 0;
    const c: number = i < input.length ? input.charCodeAt(i++) : 0;
    const idx1: number = a >> 2;
    const idx2: number = ((a & 3) << 4) | (b >> 4);
    const idx3: number = ((b & 15) << 2) | (c >> 6);
    const idx4: number = c & 63;
    result += chars.charAt(idx1) + chars.charAt(idx2);
    if (i > input.length + 1) {
      result += '==';
    } else if (i > input.length) {
      result += chars.charAt(idx3) + '=';
    } else {
      result += chars.charAt(idx3) + chars.charAt(idx4);
    }
  }
  return result;
}
