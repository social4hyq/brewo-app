import http from '@ohos.net.http';

const WINDOW_DAYS = 30;
const DAY_REQUESTS = 6;
const CACHE_TTL = 60 * 60 * 1000;

export interface DownloadStats {
  counts: Map<string, number>;
  days: number;
}

let cached: DownloadStats | undefined;
let fetchedAt = 0;
let pending: Promise<DownloadStats> | undefined;

async function fetchDay(date: string): Promise<Record<string, number> | undefined> {
  const client = http.createHttp();
  try {
    const response = await client.request('https://harmonybrew.atomgit.com/stats/stats-' + date + '.json', {
      expectDataType: http.HttpDataType.STRING, connectTimeout: 5000, readTimeout: 7000,
    });
    if (response.responseCode !== 200 || typeof response.result !== 'string') return undefined;
    const data = JSON.parse(response.result) as Record<string, number>;
    return data && typeof data === 'object' && !Array.isArray(data) ? data : undefined;
  } catch (error) {
    return undefined;
  } finally {
    client.destroy();
  }
}

async function fetchDownloads(): Promise<DownloadStats> {
  const today = new Date();
  const dates: string[] = [];
  for (let daysAgo = 1; daysAgo <= WINDOW_DAYS; daysAgo++) {
    const date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - daysAgo);
    dates.push(String(date.getFullYear()) + String(date.getMonth() + 1).padStart(2, '0') +
      String(date.getDate()).padStart(2, '0'));
  }
  const counts = new Map<string, number>();
  let days = 0;
  for (let index = 0; index < dates.length; index += DAY_REQUESTS) {
    const batch = await Promise.all(dates.slice(index, index + DAY_REQUESTS).map((date: string) => fetchDay(date)));
    for (const data of batch) {
      if (data === undefined) continue;
      days++;
      for (const name of Object.keys(data)) {
        const count = data[name];
        if (Number.isSafeInteger(count) && count >= 0) counts.set(name, (counts.get(name) ?? 0) + count);
      }
    }
  }
  if (days === 0) throw new Error('No Harmonybrew download data');
  cached = { counts, days };
  fetchedAt = Date.now();
  return cached;
}

export async function loadDownloads(refresh: boolean): Promise<DownloadStats> {
  if (!refresh && cached && Date.now() - fetchedAt < CACHE_TTL) return cached;
  if (pending) return pending;
  const request = fetchDownloads();
  pending = request;
  try {
    return await request;
  } finally {
    pending = undefined;
  }
}
