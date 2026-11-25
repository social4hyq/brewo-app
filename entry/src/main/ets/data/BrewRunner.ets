import hilog from '@ohos.hilog';

const TAG = 'BrewoBrew';

// ---- brew info --json=v2 解析（最小字段）----
interface InstRaw { version?: string; time?: number; poured_from_bottle?: boolean; installed_on_request?: boolean; }
interface VersionsRaw { stable?: string; }
interface FormulaRaw {
  name?: string; full_name?: string; tap?: string; desc?: string; license?: string; homepage?: string;
  outdated?: boolean; keg_only?: boolean; pinned?: boolean; caveats?: string;
  dependencies?: string[]; versions?: VersionsRaw; installed?: InstRaw[]; revision?: number;
}
export interface InstalledCask { token?: string; tap?: string; installed?: string; }
interface InfoJson { formulae?: FormulaRaw[]; casks?: InstalledCask[]; }

export function parseInstalledCasks(json: string): InstalledCask[] {
  try {
    const data = JSON.parse(json) as InfoJson;
    return Array.isArray(data.casks) ? data.casks : [];
  } catch (error) {
    return [];
  }
}

export interface LivePkg {
  name: string; fullName: string; tap: string; desc: string; license: string; homepage: string;
  installedVersion: string; latestVersion: string; outdated: boolean; poured: boolean;
  installTime: number; installedOnRequest: boolean; kegOnly: boolean; pinned: boolean;
  caveats: string; deps: string[];
}

export function parseInfoJson(json: string): LivePkg[] | undefined {
  const out: LivePkg[] = [];
  if (json.length === 0) return undefined;
  try {
    const d = JSON.parse(json) as InfoJson;
    if (!Array.isArray(d.formulae)) return undefined;
    const list = d.formulae;
    for (const f of list) {
      const inst = (f.installed && f.installed.length > 0) ? f.installed[0] : undefined;
      const stable = f.versions?.stable ?? '';
      const revision = f.revision ?? 0;
      out.push({
        name: f.name ?? '',
        fullName: f.full_name ?? '',
        tap: f.tap ?? '',
        desc: f.desc ?? '',
        license: f.license ?? '',
        homepage: f.homepage ?? '',
        installedVersion: inst?.version ?? '',
        latestVersion: stable && revision > 0 ? stable + '_' + revision : stable,
        outdated: f.outdated === true,
        poured: inst?.poured_from_bottle === true,
        installTime: inst?.time ?? 0,
        installedOnRequest: inst?.installed_on_request === true,
        kegOnly: f.keg_only === true,
        pinned: f.pinned === true,
        caveats: f.caveats ?? '',
        deps: f.dependencies ?? [],
      });
    }
  } catch (e) {
    hilog.error(0x0000, TAG, 'parseInfoJson failed');
    return undefined;
  }
  out.sort((a, b) => a.name < b.name ? -1 : (a.name > b.name ? 1 : 0));
  return out;
}

// ---- brew doctor --json 解析 ----
export interface DoctorFinding {
  tier: number;
  text: string;
  affects: string[];
}
export interface DoctorResult {
  tier: number;
  findings: DoctorFinding[];
}
interface DoctorFindingRaw { tier?: number; text?: string; affects?: string[]; }
interface DoctorJson { tier?: number; findings?: DoctorFindingRaw[]; }

export function parseDoctorJson(json: string): DoctorResult | undefined {
  if (json.length === 0) return undefined;
  try {
    const d = JSON.parse(json) as DoctorJson;
    if (!Array.isArray(d.findings)) return undefined;
    const findings: DoctorFinding[] = [];
    for (const f of (d.findings ?? [])) {
      findings.push({
        tier: Number(f.tier ?? 0),
        text: f.text ?? '',
        affects: f.affects ?? [],
      });
    }
    return { tier: Number(d.tier ?? 0), findings: findings };
  } catch (e) {
    hilog.error(0x0000, TAG, 'parseDoctorJson failed');
    return undefined;
  }
}

// ---- brew config 解析（纯文本 Key: Value）----
export interface ConfigItem { key: string; value: string; }
export function parseConfig(text: string): ConfigItem[] {
  const out: ConfigItem[] = [];
  for (const line of text.split('\n')) {
    const eq = line.indexOf(':');
    if (eq <= 0) continue;
    const key = line.substring(0, eq).trim();
    const value = line.substring(eq + 1).trim();
    if (key.length > 0 && value.length > 0) out.push({ key: key, value: value });
  }
  return out;
}
