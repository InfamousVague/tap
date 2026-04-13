import * as SecureStore from 'expo-secure-store';

const RELAY_URL_KEY = 'tap_relay_url';
const TOKEN_KEY = 'tap_token';
const RELAY_URL = 'https://tap.mattssoftware.com';

// Types shared with relay
export interface Server {
  id: string;
  name: string;
  host: string;
  port: number;
  user: string;
  status: string | null;
  latency_ms: number | null;
  commands: Command[];
  suites: Suite[];
}

export interface Command {
  id: string;
  server_id: string;
  label: string;
  command: string;
  confirm: boolean;
  timeout_sec: number;
  sort_order: number;
  pinned: boolean;
}

export interface Suite {
  id: string;
  server_id: string;
  label: string;
}

export interface ExecResult {
  status: string;
  exit_code: number | null;
  stdout: string;
  stderr: string;
  duration_ms: number;
}

export interface ExecHistoryEntry {
  id: string;
  server_id: string;
  command_id: string | null;
  command_text: string | null;
  exit_code: number | null;
  stdout: string | null;
  stderr: string | null;
  duration_ms: number | null;
  device: string | null;
  created_at: string | null;
}

export interface SshKeyMeta {
  id: string;
  label: string;
  public_key: string;
  key_type: string;
  created_at: string;
}

export interface Template {
  id: string;
  category: string;
  label: string;
  command: string;
  confirm: boolean;
  timeout_sec: number;
  variables: string[];
}

export interface ConfigResponse {
  version: string;
  servers: Server[];
}

class APIClient {
  private baseURL: string = '';
  private token: string = '';
  private _configured: boolean = false;

  async initialize(): Promise<boolean> {
    const url = await SecureStore.getItemAsync(RELAY_URL_KEY);
    const token = await SecureStore.getItemAsync(TOKEN_KEY);
    if (url && token) {
      this.baseURL = url.endsWith('/') ? url.slice(0, -1) : url;
      this.token = token;
      this._configured = true;
      return true;
    }
    return false;
  }

  async configure(url: string, token: string): Promise<void> {
    const cleanUrl = url.endsWith('/') ? url.slice(0, -1) : url;
    await SecureStore.setItemAsync(RELAY_URL_KEY, cleanUrl);
    await SecureStore.setItemAsync(TOKEN_KEY, token);
    this.baseURL = cleanUrl;
    this.token = token;
    this._configured = true;
  }

  async disconnect(): Promise<void> {
    await SecureStore.deleteItemAsync(RELAY_URL_KEY);
    await SecureStore.deleteItemAsync(TOKEN_KEY);
    this.baseURL = '';
    this.token = '';
    this._configured = false;
  }

  get isConfigured(): boolean {
    return this._configured;
  }

  // Apple Sign In
  async signInWithApple(identityToken: string, userIdentifier: string, email?: string): Promise<string> {
    const res = await fetch(`${RELAY_URL}/auth/apple`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ identity_token: identityToken, user_identifier: userIdentifier, email: email ?? '' }),
    });
    if (!res.ok) throw new APIError(res.status, await res.text());
    const data = await res.json();
    await this.configure(RELAY_URL, data.token);
    return data.token;
  }

  // Config
  async getConfig(): Promise<ConfigResponse> {
    return this.get('/config');
  }

  // Servers
  async listServers(): Promise<Server[]> {
    const config = await this.getConfig();
    return config.servers;
  }

  async createServer(server: { name: string; host: string; port: number; user: string; ssh_key_id?: string }): Promise<{ id: string }> {
    return this.post('/servers', server);
  }

  async updateServer(id: string, server: Partial<Server>): Promise<void> {
    return this.put(`/servers/${id}`, server);
  }

  async deleteServer(id: string): Promise<void> {
    return this.del(`/servers/${id}`);
  }

  async pingServer(id: string): Promise<{ status: string; latency_ms: number | null }> {
    return this.get(`/servers/${id}/ping`);
  }

  async importSshConfig(): Promise<{ imported: number }> {
    return this.post('/servers/import-ssh-config', {});
  }

  // Commands
  async listCommands(serverId: string): Promise<Command[]> {
    return this.get(`/servers/${serverId}/commands`);
  }

  async createCommand(serverId: string, cmd: { label: string; command: string; confirm?: boolean; timeout_sec?: number; pinned?: boolean }): Promise<{ id: string }> {
    return this.post(`/servers/${serverId}/commands`, cmd);
  }

  async updateCommand(id: string, cmd: Partial<Command>): Promise<void> {
    return this.put(`/commands/${id}`, cmd);
  }

  async deleteCommand(id: string): Promise<void> {
    return this.del(`/commands/${id}`);
  }

  // Execution
  async execute(serverId: string, commandId: string): Promise<ExecResult> {
    return this.post('/exec', { server_id: serverId, command_id: commandId });
  }

  async executeAdhoc(serverId: string, command: string): Promise<ExecResult> {
    return this.post('/exec/adhoc', { server_id: serverId, command });
  }

  // SSH Keys
  async listKeys(): Promise<SshKeyMeta[]> {
    return this.get('/keys');
  }

  async uploadKey(label: string, privateKey: string): Promise<{ id: string; public_key: string }> {
    return this.post('/keys/upload', { label, private_key: privateKey });
  }

  async generateKey(label: string): Promise<{ id: string; public_key: string }> {
    return this.post('/keys/generate', { label });
  }

  async deleteKey(id: string): Promise<void> {
    return this.del(`/keys/${id}`);
  }

  // Templates
  async listTemplates(): Promise<{ templates: Template[] }> {
    return this.get('/templates');
  }

  async createFromTemplate(serverId: string, templateId: string, variables?: Record<string, string>): Promise<{ id: string }> {
    return this.post(`/servers/${serverId}/commands/from-template`, { template_id: templateId, variables });
  }

  // History
  async listHistory(limit?: number): Promise<ExecHistoryEntry[]> {
    const params = limit ? `?limit=${limit}` : '';
    return this.get(`/history${params}`);
  }

  // Auth
  async createToken(label: string, deviceType?: string): Promise<{ id: string; token: string }> {
    return this.post('/auth/token', { label, device_type: deviceType });
  }

  // Health
  async healthCheck(): Promise<{ relay: string; version: string }> {
    return this.get('/health');
  }

  // Private helpers
  private async get<T>(path: string): Promise<T> {
    const res = await fetch(`${this.baseURL}${path}`, { headers: this.headers() });
    if (!res.ok) throw new APIError(res.status, await res.text());
    return res.json();
  }

  private async post<T>(path: string, body: any): Promise<T> {
    const res = await fetch(`${this.baseURL}${path}`, {
      method: 'POST',
      headers: this.headers(),
      body: JSON.stringify(body),
    });
    if (!res.ok) throw new APIError(res.status, await res.text());
    return res.json();
  }

  private async put<T>(path: string, body: any): Promise<T> {
    const res = await fetch(`${this.baseURL}${path}`, {
      method: 'PUT',
      headers: this.headers(),
      body: JSON.stringify(body),
    });
    if (!res.ok) throw new APIError(res.status, await res.text());
    return undefined as any;
  }

  private async del<T>(path: string): Promise<T> {
    const res = await fetch(`${this.baseURL}${path}`, {
      method: 'DELETE',
      headers: this.headers(),
    });
    if (!res.ok) throw new APIError(res.status, await res.text());
    return undefined as any;
  }

  private headers(): Record<string, string> {
    return {
      'Authorization': `Bearer ${this.token}`,
      'Content-Type': 'application/json',
    };
  }
}

export class APIError extends Error {
  constructor(public status: number, public body: string) {
    super(`API Error ${status}: ${body}`);
  }
}

export const api = new APIClient();
