// HarborIpc：通过回环 TCP 连接 Harbor HAP 的 IPC，拿真实服务状态。
// 协议：AUTH <token> STATUS\n -> OK [{"name","pid","status"}]\n
import socket from '@ohos.net.socket';
import fileIo from '@ohos.file.fs';
import hilog from '@ohos.hilog';
import { BusinessError } from '@ohos.base';

const TAG = 'BrewoHarborIpc';
const HOST = '127.0.0.1';
const PORT = 19876;
const TOKEN_FILE = '/storage/Users/currentUser/.config/harbor/ipc.conf';
const APPS_FILE = '/storage/Users/currentUser/.config/harbor/apps.json';

export interface HarborService {
  name: string;
  pid: number;
  status: string;   // started | stopped | none | disabled
  unit: string;
  log: string;
  timed: boolean;
}

function readToken(): string {
  try {
    if (fileIo.accessSync(TOKEN_FILE)) {
      for (const line of fileIo.readTextSync(TOKEN_FILE).split('\n')) {
        if (line.startsWith('token=')) return line.substring(6).trim();
      }
    }
  } catch (e) { /* ignore */ }
  return '';
}

interface SvcRaw { name?: string; pid?: number; status?: string; }
interface HarborApp { name?: string; unit?: string; log?: string; timer?: object; }
interface HarborConfig { apps?: HarborApp[]; }

function readServiceConfig(): HarborApp[] {
  try { return (JSON.parse(fileIo.readTextSync(APPS_FILE)) as HarborConfig).apps ?? []; }
  catch (error) { return []; }
}

function logPath(app: HarborApp | undefined): string {
  if (!app?.unit) return app?.log ?? '';
  try {
    const match = /^\s*Standard(?:Output|Error)\s*=\s*append:(.+)$/m.exec(fileIo.readTextSync(app.unit));
    return match?.[1]?.trim() ?? app.log ?? '';
  } catch (error) { return app.log ?? ''; }
}

// 查询 Harbor 服务列表；失败返回空数组（Harbor 未启动/未授权时优雅降级）
export async function queryServices(): Promise<HarborService[]> {
  const token = readToken();
  if (token.length === 0) {
    hilog.warn(0x0000, TAG, 'no harbor token');
    return [];
  }
  return new Promise<HarborService[]>((resolve) => {
    const tcp = socket.constructTCPSocketInstance();
    let settled = false;
    const finish = (r: HarborService[]): void => {
      if (settled) return;
      settled = true;
      try { tcp.close(); } catch (e) {}
      resolve(r);
    };
    tcp.on('message', (info: socket.SocketMessageInfo) => {
      const bytes = new Uint8Array(info.message);
      let text = '';
      for (let i = 0; i < bytes.length; i++) text += String.fromCharCode(bytes[i]);
      const nl = text.indexOf('\n');
      const line = (nl >= 0 ? text.substring(0, nl) : text).trim();
      hilog.info(0x0000, TAG, 'reply: %{public}s', line.substring(0, 80));
      if (!line.startsWith('OK ')) { finish([]); return; }
      const json = line.substring(3);
      try {
        const arr = JSON.parse(json) as SvcRaw[];
        const out: HarborService[] = [];
        const config = readServiceConfig();
        for (const s of arr) {
          const app = config.find((item: HarborApp) => item.name === s.name);
          out.push({ name: s.name ?? '', pid: Number(s.pid ?? 0), status: s.status ?? 'none',
            unit: app?.unit ?? '', log: logPath(app), timed: app?.timer !== undefined });
        }
        finish(out);
      } catch (e) {
        hilog.error(0x0000, TAG, 'parse failed');
        finish([]);
      }
    });
    tcp.on('error', (e: BusinessError) => {
      hilog.warn(0x0000, TAG, 'socket error: %{public}s', JSON.stringify(e));
      finish([]);
    });
    const addr: socket.NetAddress = { address: HOST, port: PORT };
    tcp.connect({ address: addr } as socket.TCPConnectOptions).then(() => {
      const cmd = 'AUTH ' + token + ' STATUS\n';
      const buf = new Uint8Array(cmd.length);
      for (let i = 0; i < cmd.length; i++) buf[i] = cmd.charCodeAt(i);
      tcp.send({ data: buf.buffer } as socket.TCPSendOptions).catch((e: BusinessError) => {
        hilog.warn(0x0000, TAG, 'send failed');
        finish([]);
      });
    }).catch((e: BusinessError) => {
      hilog.warn(0x0000, TAG, 'connect failed (Harbor not running?)');
      finish([]);
    });
    // 10 秒超时
    setTimeout(() => { finish([]); }, 10000);
  });
}
