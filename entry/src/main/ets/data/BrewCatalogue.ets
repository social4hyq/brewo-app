import http from '@ohos.net.http';

const API = 'https://harmonybrew.atomgit.com/api/';
const CACHE_TTL = 60 * 60 * 1000;

export type CatalogueKind = 'formula' | 'cask';

interface CatalogueEnvelope { payload?: string; }
interface CatalogueVersions { stable?: string; }
interface CaskDependencies { formula?: string[]; cask?: string[]; }
interface CatalogueRow {
  name?: string | string[];
  full_name?: string;
  token?: string;
  full_token?: string;
  tap?: string;
  desc?: string;
  license?: string;
  homepage?: string;
  ruby_source_path?: string;
  versions?: CatalogueVersions;
  version?: string;
  aliases?: string[];
  oldnames?: string[];
  old_tokens?: string[];
  dependencies?: string[];
  depends_on?: CaskDependencies;
}

export interface CataloguePackage {
  id: string;
  kind: CatalogueKind;
  name: string;
  fullName: string;
  displayName: string;
  tap: string;
  desc: string;
  license: string;
  homepage: string;
  sourceUrl: string;
  version: string;
  aliases: string[];
  deps: string[];
}

interface CachedCatalogue { fetchedAt: number; packages: CataloguePackage[]; }
const cache = new Map<CatalogueKind, CachedCatalogue>();
const pending = new Map<CatalogueKind, Promise<CataloguePackage[]>>();

async function fetchCatalogue(kind: CatalogueKind): Promise<CataloguePackage[]> {
  const client = http.createHttp();
  try {
    const response = await client.request(API + kind + '.jws.json', {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 8000,
      readTimeout: 20000,
      maxLimit: 32 * 1024 * 1024,
    });
    if (response.responseCode !== 200 || typeof response.result !== 'string') {
      throw new Error('Harmonybrew catalogue HTTP ' + response.responseCode);
    }
    const envelope = JSON.parse(response.result) as CatalogueEnvelope;
    if (typeof envelope.payload !== 'string') throw new Error('Invalid Harmonybrew catalogue envelope');
    const payload = JSON.parse(envelope.payload) as CatalogueRow[] | Record<string, CatalogueRow>;
    let items: CatalogueRow[];
    if (Array.isArray(payload)) {
      items = payload;
    } else if (kind === 'cask' && payload && typeof payload === 'object' && Object.keys(payload).length === 0) {
      // Harmonybrew currently publishes its empty cask catalogue as an object.
      items = [];
    } else {
      throw new Error('Invalid Harmonybrew catalogue payload');
    }

    const packages: CataloguePackage[] = [];
    for (const item of items) {
      const name = kind === 'formula' && typeof item.name === 'string' ? item.name : item.token;
      if (!name) continue;
      const shortName = (kind === 'formula' ? item.full_name : item.full_token) || name;
      const fullName = item.tap && !shortName.includes('/') ? item.tap + '/' + shortName : shortName;
      packages.push({
        id: kind + ':' + fullName, kind, name, fullName,
        displayName: Array.isArray(item.name) ? item.name[0] || name : name,
        tap: item.tap ?? '', desc: item.desc ?? '', license: item.license ?? '', homepage: item.homepage ?? '',
        sourceUrl: item.tap === 'harmonybrew/core' && item.ruby_source_path ?
          'https://atomgit.com/Harmonybrew/homebrew-core/blob/main/' + item.ruby_source_path : '',
        version: (kind === 'formula' ? item.versions?.stable : item.version) ?? '',
        aliases: kind === 'formula' ? (item.aliases ?? []).concat(item.oldnames ?? []) : (item.old_tokens ?? []),
        deps: kind === 'formula' ? (item.dependencies ?? []) :
          (item.depends_on?.formula ?? []).concat(item.depends_on?.cask ?? []),
      });
    }
    cache.set(kind, { fetchedAt: Date.now(), packages });
    return packages;
  } finally {
    client.destroy();
  }
}

export async function loadCatalogue(kind: CatalogueKind, refresh: boolean): Promise<CataloguePackage[]> {
  const cached = cache.get(kind);
  if (!refresh && cached && Date.now() - cached.fetchedAt < CACHE_TTL) return cached.packages;
  const loading = pending.get(kind);
  if (loading) return loading;
  const request = fetchCatalogue(kind);
  pending.set(kind, request);
  try {
    return await request;
  } finally {
    pending.delete(kind);
  }
}

export function searchCatalogue(packages: CataloguePackage[], input: string): CataloguePackage[] {
  const query = input.trim().toLowerCase();
  return packages.filter((pkg: CataloguePackage) => !query || pkg.fullName.toLowerCase().includes(query) ||
    pkg.displayName.toLowerCase().includes(query) || pkg.aliases.some((name: string) => name.toLowerCase().includes(query)))
    .sort((left: CataloguePackage, right: CataloguePackage) => {
      const a = left.name.toLowerCase();
      const b = right.name.toLowerCase();
      if ((a === query) !== (b === query)) return a === query ? -1 : 1;
      if (a.startsWith(query) !== b.startsWith(query)) return a.startsWith(query) ? -1 : 1;
      return a.localeCompare(b);
    });
}
