import http from '@ohos.net.http';
import fileIo from '@ohos.file.fs';

const BASE_URL = 'http://127.0.0.1:19877';
const UNAVAILABLE = '无法连接 Brewo 执行端。请确认 Harbor 及其 brewo-app 服务已启动，然后刷新。';
let tokenPath = '';

export function configureBrewHost(filesDir: string): void {
  tokenPath = filesDir + '/brewo-host-token';
}

interface StartRequest { arguments: string[]; }
interface HostReply { id?: string; error?: string; }
export interface BrewJobStatus { exitCode: number | null; output: string; cancelled: boolean; }

async function request(path: string, method: http.RequestMethod, body?: StartRequest): Promise<string> {
  let token: string;
  try {
    token = fileIo.readTextSync(tokenPath).trim();
  } catch (error) {
    throw new Error('Brewo 尚未与本机宿主配对。');
  }
  const client = http.createHttp();
  let result: http.HttpResponse;
  try {
    result = await client.request(BASE_URL + path, {
      method: method,
      header: { 'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json' },
      extraData: body === undefined ? undefined : JSON.stringify(body),
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 2000,
      readTimeout: 5000,
      usingProxy: false
    });
  } catch (error) {
    throw new Error(UNAVAILABLE);
  } finally {
    client.destroy();
  }
  const text = result.result as string;
  if (result.responseCode < 200 || result.responseCode >= 300) {
    throw new Error((JSON.parse(text) as HostReply).error ?? UNAVAILABLE);
  }
  return text;
}

export async function startJob(args: string[]): Promise<string> {
  const reply = JSON.parse(await request('/jobs', http.RequestMethod.POST, { arguments: args })) as HostReply;
  if (!reply.id || !/^[0-9a-f]{32}$/.test(reply.id)) throw new Error('宿主返回了无效的任务编号。');
  return reply.id;
}

export async function waitForBrewHost(): Promise<void> {
  for (let attempt = 0; attempt < 5; attempt++) {
    try {
      await request('/ready', http.RequestMethod.GET);
      return;
    } catch (error) {
      if (attempt === 4) throw new Error((error as Error).message);
      await new Promise<void>((resolve: () => void) => { setTimeout(resolve, 400); });
    }
  }
}

export async function jobStatus(id: string): Promise<BrewJobStatus> {
  return JSON.parse(await request('/jobs/' + id, http.RequestMethod.GET)) as BrewJobStatus;
}

export async function cancelJob(id: string): Promise<BrewJobStatus> {
  return JSON.parse(await request('/jobs/' + id, http.RequestMethod.DELETE)) as BrewJobStatus;
}

export async function waitForJob(id: string, onStatus: (status: BrewJobStatus) => void): Promise<BrewJobStatus> {
  let status = await jobStatus(id);
  onStatus(status);
  while (status.exitCode === null) {
    await new Promise<void>((resolve: () => void) => { setTimeout(resolve, 500); });
    status = await jobStatus(id);
    onStatus(status);
  }
  return status;
}
