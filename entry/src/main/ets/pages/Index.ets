import { C, L } from '../theme/Tokens';
import { APPEARANCE_STORAGE, Appearance, applyAppearance, saveAppearance } from '../theme/Appearance';
import common from '@ohos.app.ability.common';
import { Sidebar, ConsolePanel, Page } from '../components/Shell';
import { InstalledPage, UpgradesPage, DiscoverPage } from '../components/PackagePages';
import { ServicesPage, DoctorPage, ConfigurationPage } from '../components/OtherPages';
import {
  parseInfoJson, parseDoctorJson, parseConfig, parseInstalledCasks,
  LivePkg, DoctorResult, ConfigItem, InstalledCask,
} from '../data/BrewRunner';
import { CataloguePackage } from '../data/BrewCatalogue';
import { BrewJobStatus, cancelJob, startJob, waitForBrewHost, waitForJob } from '../data/BrewHost';
import hilog from '@ohos.hilog';
import { queryServices, HarborService } from '../data/HarborIpc';

@Entry
@Component
struct Index {
  @State current: Page = Page.Installed;
  @State packages: LivePkg[] = [];
  @State casks: InstalledCask[] = [];
  @State loaded: boolean = false;
  @State inventoryError: boolean = false;
  @State doctor: DoctorResult = { tier: 0, findings: [] };
  @State doctorLoaded: boolean = false;
  @State doctorValid: boolean = false;
  @State doctorOutput: string = '';
  @State config: ConfigItem[] = [];
  @State configLoaded: boolean = false;
  @State consoleText: string = '$ brew …\n→ 正在读取实时数据…';
  @State harborServices: HarborService[] = [];
  @State harborLoaded: boolean = false;
  // 写任务状态
  @State taskPhase: string = '';   // '' 空闲 | 'running' | 'done' | 'failed' | 'cancelled'
  @State taskLabel: string = '';
  @State workspaceWidth: number = 0;
  @StorageLink(APPEARANCE_STORAGE) appearance: Appearance = Appearance.System;
  @State appearanceMessage: string = '';
  @State appearanceSaving: boolean = false;
  private writeJob: string = '';
  private cancelling: boolean = false;
  private readJobs: Set<string> = new Set<string>();

  private runJob(args: string[], id: string, done: (out: string) => void): void {
    if (this.readJobs.has(id)) return;
    this.readJobs.add(id);
    startJob(args).then((job: string) => waitForJob(job, () => {})).then((result: BrewJobStatus) => {
      this.readJobs.delete(id);
      done(result.output);
    }).catch((error: Error) => {
      this.readJobs.delete(id);
      done(error.message);
    });
  }

  private refreshData(): void {
    this.runJob(['info', '--installed', '--json=v2'], 'info-all', (out: string) => {
      const pkgs = parseInfoJson(out);
      this.inventoryError = pkgs === undefined;
      if (pkgs !== undefined) {
        this.packages = pkgs;
        this.casks = parseInstalledCasks(out);
        this.loaded = true;
      }
      if (this.taskPhase === '') {
        this.consoleText = '$ brew info --installed --json=v2\n' +
          (pkgs !== undefined ? '✓ 已读取 ' + pkgs.length + ' 个软件包' : '✕ 无法读取已安装的软件包\n' + out);
      }
    });
  }

  private loadDoctor(): void {
    this.doctorLoaded = false;
    this.runJob(['doctor', '--json'], 'doctor', (out: string) => {
      this.doctorOutput = out;
      const result = parseDoctorJson(out);
      this.doctor = result ?? { tier: 0, findings: [] };
      this.doctorValid = result !== undefined;
      this.doctorLoaded = true;
    });
  }

  private loadHarborServices(): void {
    this.harborLoaded = false;
    queryServices().then((svcs: HarborService[]) => {
      this.harborServices = svcs;
      this.harborLoaded = true;
      hilog.info(0, 'BrewoLive', 'harbor services: %{public}d', svcs.length);
    });
  }

  aboutToAppear(): void {
    this.loadHarborServices();
    waitForBrewHost().then(() => { this.reloadBrew(); }).catch(() => { this.reloadBrew(); });
  }

  private reloadBrew(): void {
    this.refreshData();
    this.loadDoctor();
    this.loadConfig();
  }

  private loadConfig(): void {
    this.configLoaded = false;
    this.runJob(['config'], 'config', (out: string) => {
      this.config = parseConfig(out);
      this.configLoaded = true;
    });
  }

  private async runWrite(label: string, args: string[], refreshInventory: boolean = true): Promise<void> {
    if (this.taskPhase === 'running') return;
    this.taskLabel = label;
    this.taskPhase = 'running';
    const command = '$ brew ' + args.join(' ');
    this.consoleText = command + '\n→ 执行中…';
    try {
      this.writeJob = await startJob(args);
      const result = await waitForJob(this.writeJob, (status: BrewJobStatus) => {
        if (status.output.length > 0) this.consoleText = command + '\n' + status.output;
      });
      if (result.cancelled) {
        this.taskPhase = 'cancelled';
        this.consoleText = command + '\n' + result.output + '\n已取消';
      } else if (result.exitCode === 0) {
        this.taskPhase = 'done';
        this.consoleText = command + '\n' + result.output + '\n✓ 完成 (exit 0)';
      } else {
        this.taskPhase = 'failed';
        this.consoleText = command + '\n' + result.output + '\n✕ 失败 (exit ' + result.exitCode + ')';
      }
      if (refreshInventory) this.refreshData();
    } catch (error) {
      this.taskPhase = 'failed';
      this.consoleText += '\n✕ ' + (error as Error).message;
    } finally {
      this.writeJob = '';
    }
  }

  private doUninstall(p: LivePkg): void {
    void this.runWrite('卸载 ' + p.name, ['uninstall', '--formula', p.fullName || p.name]);
  }

  private async installDiscovered(pkg: CataloguePackage): Promise<string> {
    if (this.taskPhase === 'running') return 'busy';
    await this.runWrite('安装 ' + pkg.displayName, ['install', '--' + pkg.kind, pkg.fullName]);
    return this.taskPhase;
  }
  private doUpgrade(p: LivePkg): void {
    void this.runWrite('更新 ' + p.name, ['upgrade', '--formula', p.fullName || p.name]);
  }
  private doUpgradeSelected(packages: LivePkg[]): void {
    if (packages.length === 0) return;
    void this.runWrite('更新 ' + packages.length + ' 个软件包',
      ['upgrade', '--formula'].concat(packages.map((p: LivePkg) => p.fullName || p.name)));
  }

  private previewUpgrade(packages: LivePkg[]): void {
    if (packages.length === 0) return;
    void this.runWrite('预览 ' + packages.length + ' 个软件包的更新',
      ['upgrade', '--dry-run', '--formula'].concat(packages.map((p: LivePkg) => p.fullName || p.name)),
      false);
  }
  private async doCancel(): Promise<void> {
    if (this.writeJob.length === 0 || this.cancelling) return;
    this.cancelling = true;
    try {
      await cancelJob(this.writeJob);
    } catch (error) {
      this.consoleText += '\n✕ 取消请求失败：' + (error as Error).message;
    } finally {
      this.cancelling = false;
    }
  }

  private changeTrust(target: string, grant: boolean): void {
    const command = grant ? 'trust' : 'untrust';
    const args = target.split('/').length === 3 ? [command, '--formula', target] : [command, target];
    void this.runWrite((grant ? '信任 ' : '撤销信任 ') + target, args);
  }

  private upgradeCount(): number {
    let n = 0;
    for (const p of this.packages) if (p.outdated && !p.pinned) n++;
    return n;
  }

  private async changeAppearance(value: Appearance): Promise<void> {
    if (this.appearanceSaving || this.appearance === value) return;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.appearanceMessage = '';
    try {
      applyAppearance(context, value);
    } catch (error) {
      this.appearanceMessage = '无法切换外观，请重试。';
      return;
    }
    this.appearance = value;
    this.appearanceSaving = true;
    try {
      await saveAppearance(context, value);
    } catch (error) {
      this.appearanceMessage = '外观已切换，未能保存到下次启动。';
    } finally {
      this.appearanceSaving = false;
    }
  }

  @Builder
  Diagnostics(compact: boolean) {
    DoctorPage({ result: this.doctor, loaded: this.doctorLoaded, valid: this.doctorValid, rawOutput: this.doctorOutput,
      compact: compact, widthAvailable: this.workspaceWidth, onRunAgain: () => { this.loadDoctor(); } })
  }

  build() {
    Column({ space: 0 }) {
      Row({ space: 0 }) {
        Sidebar({ current: this.current, upgradeCount: this.upgradeCount() })

        Column({ space: L.md }) {
          Column() {
            if (this.current === Page.Installed) {
              InstalledPage({
                packages: this.packages,
                loaded: this.loaded,
                loadFailed: this.inventoryError,
                onUninstall: (p: LivePkg) => { this.doUninstall(p); },
                onUpgrade: (p: LivePkg) => { this.doUpgrade(p); },
                taskPhase: this.taskPhase,
              })
            } else if (this.current === Page.Upgrades) {
              Row({ space: L.md }) {
                Column() {
                  UpgradesPage({
                    packages: this.packages,
                    loaded: this.loaded,
                    loadFailed: this.inventoryError,
                    onUpgrade: (p: LivePkg) => { this.doUpgrade(p); },
                    onUpgradeSelected: (items: LivePkg[]) => { this.doUpgradeSelected(items); },
                    onPreview: (items: LivePkg[]) => { this.previewUpgrade(items); },
                    onRefresh: () => { this.reloadBrew(); },
                    taskPhase: this.taskPhase,
                  })
                }.layoutWeight(1.15).height('100%')
                if (this.workspaceWidth >= 840) {
                  Column() { this.Diagnostics(true) }.layoutWeight(1).height('100%')
                }
              }.width('100%').height('100%')
            } else if (this.current === Page.Discover) {
              DiscoverPage({ installed: this.packages, installedCasks: this.casks, widthAvailable: this.workspaceWidth,
                taskRunning: this.taskPhase === 'running',
                onInstall: (pkg: CataloguePackage) => this.installDiscovered(pkg) })
            } else if (this.current === Page.Services) {
              ServicesPage({
                services: this.harborServices,
                loaded: this.harborLoaded,
                widthAvailable: this.workspaceWidth,
                onRefresh: () => { this.loadHarborServices(); },
              })
            } else if (this.current === Page.Doctor) {
              this.Diagnostics(false)
            } else if (this.current === Page.Configuration) {
              ConfigurationPage({ config: this.config, loaded: this.configLoaded, appearance: this.appearance,
                appearanceMessage: this.appearanceMessage, appearanceSaving: this.appearanceSaving,
                taskRunning: this.taskPhase === 'running', onTrust: (target: string, grant: boolean) => { this.changeTrust(target, grant); },
                onAppearance: (value: Appearance) => { void this.changeAppearance(value); },
                onRefresh: () => { this.loadConfig(); } })
            }
          }
          .width('100%').layoutWeight(1).onAreaChange((_, area) => { this.workspaceWidth = Number(area.width); })

          ConsolePanel({ consoleText: this.consoleText, phase: this.taskPhase, label: this.taskLabel,
            onCancel: () => { void this.doCancel(); } })
        }
        .layoutWeight(1).height('100%').padding(L.md)
      }
      .width('100%').height('100%')
    }
    .width('100%').height('100%')
    .backgroundColor(C.windowBase)
  }
}
