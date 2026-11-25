// 包相关页面：Installed（三栏）、Upgrades、Discover
// 视觉对齐 Homebrew 7 版 BrewUI 截图（h7 brewui-5 / discover / update）
import { C, L, F } from '../theme/Tokens';
import { LivePkg } from '../data/BrewRunner';

function formatDate(ts: number): string {
  if (ts <= 0) return '—';
  const d = new Date(ts * 1000);
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return d.getDate() + ' ' + months[d.getMonth()] + ' ' + d.getFullYear();
}

function isCask(p: LivePkg): boolean {
  return p.fullName.toLowerCase().includes('cask');
}

// 稳定伪随机（基于包名）用于模拟 installs(30d)，让 Discover 有真实感
function pseudoInstalls(name: string): number {
  let h = 0;
  for (let i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) % 100000;
  return 2000 + h;
}

// 类型圆标：FORMULA 橙立方体 / CASK 蓝立方体
interface IconParam { p: LivePkg; size: number; }
@Builder
function PackageIcon(ip: IconParam) {
  Stack() {
    Circle({ width: ip.size, height: ip.size })
      .fill(Color.Transparent)
      .stroke(isCask(ip.p) ? C.caskBlue : C.brandPrimary)
      .strokeWidth(1.5)
    Text('▣').fontSize(ip.size * 0.5)
      .fontColor(isCask(ip.p) ? C.caskBlue : C.brandPrimary)
  }
  .width(ip.size).height(ip.size)
}

interface BadgeParam { p: LivePkg; }
@Builder
function TypeBadge(bp: BadgeParam) {
  Text(isCask(bp.p) ? 'CASK' : 'FORMULA')
    .fontSize(F.caption2).fontWeight(FontWeight.Bold)
    .fontColor(isCask(bp.p) ? C.caskBlue : C.textBrand)
    .padding({ left: 5, right: 5, top: 1, bottom: 1 })
    .borderRadius(4)
    .backgroundColor(isCask(bp.p) ? C.caskTint : C.brandTint)
}

@Builder
function OutdatedBadge() {
  Text('OUTDATED')
    .fontSize(F.caption2).fontWeight(FontWeight.Medium).fontColor(C.outdated)
    .padding({ left: 5, right: 5, top: 1, bottom: 1 })
    .borderRadius(4).border({ width: 1, color: C.brandPrimary })
}

@Builder
function InstalledCheck() {
  Text('✓').fontSize(F.caption).fontColor(Color.White)
    .backgroundColor(C.statusSuccess).borderRadius(9)
    .width(16).height(16).textAlign(TextAlign.Center)
}

// 包行（列表中间栏）
@Component
struct PackageRow {
  @Prop p: LivePkg;
  @Prop selected: boolean = false;
  onSelect: (p: LivePkg) => void = () => {};

  build() {
    Row({ space: L.sm }) {
      PackageIcon({ p: this.p, size: 30 })
      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(this.p.name).fontSize(F.body).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
          TypeBadge({ p: this.p })
          if (this.p.outdated) {
            OutdatedBadge()
          } else {
            InstalledCheck()
          }
        }
        Text(this.p.desc.length > 0 ? this.p.desc : 'No description')
          .fontSize(F.callout).fontColor(C.textSecondary)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.p.outdated) {
          Text('v' + this.p.installedVersion + ' → v' + this.p.latestVersion)
            .fontSize(F.caption2).fontColor(C.outdated)
        } else {
          Text('v' + this.p.installedVersion).fontSize(F.caption2).fontColor(C.textTertiary)
        }
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: L.md, right: L.md, top: L.sm, bottom: L.sm })
    .borderRadius(L.radiusMd)
    .backgroundColor(this.selected ? C.brandTint : Color.Transparent)
    .border({ width: { bottom: 1 }, color: C.borderSeparator })
    .onClick(() => { this.onSelect(this.p); })
  }
}

// 终端命令卡片（Details 里的 Terminal command 块）
@Component
struct CommandCard {
  @Prop command: string;
  @Prop note: string;
  build() {
    Column({ space: 0 }) {
      Row({ space: L.sm }) {
        Text('▣').fontSize(F.caption).fontColor(C.textSecondary)
        Text('Terminal command').fontSize(F.caption).fontColor(C.textSecondary).layoutWeight(1)
        Text('Copy').fontSize(F.caption).fontColor(C.textLink)
      }.width('100%').padding({ left: L.sm, right: L.sm, top: L.sm, bottom: L.xs })
       .backgroundColor(C.surfaceRecessed)
      Text(this.command).fontSize(F.codeSmall).fontFamily('monospace').fontColor(C.textPrimary)
        .width('100%').padding({ left: L.sm, right: L.sm, top: L.sm, bottom: L.sm })
      Text(this.note).fontSize(F.caption2).fontColor(C.textSecondary)
        .width('100%').padding({ left: L.sm, right: L.sm, top: 0, bottom: L.sm })
    }.width('100%').borderRadius(L.radiusMd).clip(true).backgroundColor(C.surfaceRecessed)
  }
}

// 详情面板（右侧）
@Component
struct DetailPanel {
  @Prop p: LivePkg | undefined = undefined;
  @Prop taskPhase: string = '';
  @State confirmUninstall: boolean = false;
  onUninstall: (p: LivePkg) => void = () => {};
  onUpgrade: (p: LivePkg) => void = () => {};

  @Builder
  MetaRow(label: string, value: string) {
    Row({ space: L.md }) {
      Text(label).fontSize(F.callout).fontColor(C.textSecondary).width(96)
      Text(value).fontSize(F.callout).fontColor(C.textPrimary).layoutWeight(1)
    }.width('100%').padding({ top: 3, bottom: 3 })
  }

  build() {
    Stack() {
    if (this.p !== undefined) {
      Scroll() {
        Column({ space: L.md }) {
          Row({ space: L.md }) {
            PackageIcon({ p: this.p!, size: 40 })
            Column({ space: 2 }) {
              Row({ space: 6 }) {
                Text(this.p!.name).fontSize(F.title2).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
                TypeBadge({ p: this.p! })
                if (this.p!.outdated) { OutdatedBadge() } else { InstalledCheck() }
              }
              Text(this.p!.desc).fontSize(F.callout).fontColor(C.textSecondary)
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }.width('100%')

          Divider().color(C.borderSeparator)

          Column({ space: 2 }) {
            Text('Details').fontSize(F.body).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
            this.MetaRow('Installed', this.p!.installedVersion)
            if (this.p!.outdated) this.MetaRow('Latest version', this.p!.latestVersion)
            this.MetaRow('Installed on', 'Poured from bottle — ' + formatDate(this.p!.installTime))
            this.MetaRow('Install reason', this.p!.installedOnRequest ? 'As requested' : 'As dependency')
            if (this.p!.license.length > 0) this.MetaRow('Licence', this.p!.license)
            this.MetaRow('Source', this.p!.tap + ' ↗')
            if (this.p!.homepage.length > 0) this.MetaRow('Homepage', this.p!.homepage + ' ↗')
          }.width('100%')

          Divider().color(C.borderSeparator)

          Column({ space: 4 }) {
            Text('Dependencies').fontSize(F.body).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
            if (this.p!.deps.length === 0) {
              Text('No dependencies.').fontSize(F.callout).fontColor(C.textSecondary)
            } else {
              ForEach(this.p!.deps, (d: string) => {
                Text('• ' + d).fontSize(F.callout).fontColor(C.textPrimary)
              })
            }
          }.width('100%').alignItems(HorizontalAlign.Start)

          Divider().color(C.borderSeparator)

          Column({ space: 4 }) {
            Text('Dependents').fontSize(F.body).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
            if (this.p!.deps.length === 0) {
              Text('No dependents.').fontSize(F.callout).fontColor(C.textSecondary)
            } else {
              Text('blocking uninstall').fontSize(F.caption2).fontColor(C.outdated)
                .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                .backgroundColor(C.statusWarningSubtle).borderRadius(4)
            }
          }.width('100%').alignItems(HorizontalAlign.Start)

          Divider().color(C.borderSeparator)

          // 过期包显示 Upgrade 区块；否则显示 Uninstall 区块
          if (this.p!.outdated) {
            Column({ space: L.sm }) {
              Text('Upgrade').fontSize(F.body).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
              CommandCard({ command: 'brew upgrade --' + (isCask(this.p!) ? 'cask ' : 'formula ') + this.p!.name,
                            note: 'Upgrades this package to the latest available version' })
              Button(this.taskPhase === 'running' ? '升级中…' : 'Upgrade')
                .fontSize(F.callout).fontColor(Color.White).backgroundColor(C.ctaBlue)
                .padding({ left: L.lg, right: L.lg, top: L.xs, bottom: L.xs })
                .borderRadius(L.radiusSm).enabled(this.taskPhase !== 'running')
                .onClick(() => { if (this.p) this.onUpgrade(this.p); })
            }.width('100%').alignItems(HorizontalAlign.Start)
          } else {
            Column({ space: L.sm }) {
              Text('Uninstall').fontSize(F.body).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
              CommandCard({ command: 'brew uninstall --' + (isCask(this.p!) ? 'cask ' : 'formula ') + this.p!.name,
                            note: 'Uninstalls this package from this Mac' })
              Button(this.taskPhase === 'running' ? '卸载中…' : 'Uninstall')
                .fontSize(F.callout).fontColor(this.taskPhase === 'running' ? C.textTertiary : Color.White)
                .backgroundColor(this.taskPhase === 'running' ? C.surfaceRecessed : C.statusError)
                .padding({ left: L.lg, right: L.lg, top: L.xs, bottom: L.xs })
                .borderRadius(L.radiusSm).enabled(this.taskPhase !== 'running')
                .onClick(() => { this.confirmUninstall = true; })
            }.width('100%').alignItems(HorizontalAlign.Start)
          }
        }.width('100%').padding(L.lg)
      }
      .width('100%').height('100%')
      .backgroundColor(C.surfaceElevated)
      .border({ width: { left: 1 }, color: C.borderSeparator })
    } else {
      Column({ space: L.sm }) {
        Text('No selection').fontSize(F.title2).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
        Text('Choose a package from the list to see details.')
          .fontSize(F.callout).fontColor(C.textSecondary)
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
       .backgroundColor(C.surfaceElevated)
       .border({ width: { left: 1 }, color: C.borderSeparator })
    }

    // 卸载确认对话框（对齐 BrewUI）
    if (this.confirmUninstall && this.p !== undefined) {
      Column() {
        Column({ space: L.md }) {
          Text('Uninstall ' + this.p!.name + '?')
            .fontSize(F.title2).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
          Text('This will remove ' + this.p!.name + ' from this Mac using Homebrew.')
            .fontSize(F.callout).fontColor(C.textSecondary)
          Row({ space: L.sm }) {
            Button('Cancel').fontSize(F.callout).fontColor(C.textPrimary).backgroundColor(C.surfaceRecessed)
              .layoutWeight(1).onClick(() => { this.confirmUninstall = false; })
            Button('Uninstall').fontSize(F.callout).fontColor(Color.White).backgroundColor(C.statusError)
              .layoutWeight(1).onClick(() => {
                this.confirmUninstall = false;
                if (this.p) this.onUninstall(this.p);
              })
          }.width('100%')
        }.width('80%').padding(L.xl).backgroundColor(C.surfaceElevated).borderRadius(14)
         .shadow({ radius: 20, color: '#33000000', offsetY: 8 })
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
       .backgroundColor('#88000000')
    }
    }
  }
}

// 分段控件（All / Formulae / Casks）——选中态蓝色
@Component
struct ScopeSegments {
  @Prop scope: string;
  onScope: (s: string) => void = () => {};
  build() {
    Row({ space: 0 }) {
      ForEach(['All', 'Formulae', 'Casks'], (s: string) => {
        Text(s).fontSize(F.callout).fontWeight(this.scope === s ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.scope === s ? Color.White : C.textSecondary)
          .padding({ left: 12, right: 12, top: 5, bottom: 5 })
          .borderRadius(6)
          .backgroundColor(this.scope === s ? C.ctaBlue : Color.Transparent)
          .onClick(() => { this.onScope(s); })
      })
    }.backgroundColor(C.surfaceRecessed).borderRadius(8).padding(2)
  }
}

// ============ Installed 页（三栏）============
@Component
export struct InstalledPage {
  @Prop packages: LivePkg[] = [];
  @Prop taskPhase: string = '';
  onUninstall: (p: LivePkg) => void = () => {};
  onUpgrade: (p: LivePkg) => void = () => {};
  @State selected: LivePkg | undefined = undefined;
  @State query: string = '';
  @State scope: string = 'All';
  @State hideDeps: boolean = false;

  private filtered(): LivePkg[] {
    let list = this.packages.slice();
    if (this.scope === 'Formulae') list = list.filter((p: LivePkg): boolean => !isCask(p));
    if (this.scope === 'Casks') list = list.filter((p: LivePkg): boolean => isCask(p));
    if (this.query.length > 0) {
      const q = this.query.toLowerCase();
      list = list.filter((p: LivePkg): boolean => p.name.toLowerCase().includes(q) || p.desc.toLowerCase().includes(q));
    }
    if (this.hideDeps) list = list.filter((p: LivePkg): boolean => p.installedOnRequest);
    return list;
  }

  build() {
    Column({ space: 0 }) {
      Column({ space: 4 }) {
        Row() {
          Column() {
            Text('Installed').fontSize(F.title3).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
            Text('Browse or search your installed packages').fontSize(F.caption).fontColor(C.textSecondary)
          }.alignItems(HorizontalAlign.Start)
          Blank()
          Row({ space: 6 }) {
            Text('🔍').fontSize(12).fontColor(C.textSecondary)
            TextInput({ placeholder: 'Search Installed Packages', text: this.query })
              .fontSize(F.callout).fontColor(C.textPrimary).placeholderColor(C.textTertiary)
              .backgroundColor(Color.Transparent).borderWidth(0).width(200).height(28)
              .onChange((v: string) => { this.query = v; })
          }.padding({ left: L.sm, right: L.md, top: 4, bottom: 4 })
           .borderRadius(16).backgroundColor(C.surfaceElevated).border({ width: 1, color: C.borderDefault })
        }.width('100%')

        Row() {
          Column() {
            Text('Your packages').fontSize(F.title1).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
            Text(this.packages.length + ' packages').fontSize(F.callout).fontColor(C.textSecondary)
          }.alignItems(HorizontalAlign.Start)
          Blank()
          ScopeSegments({ scope: this.scope, onScope: (s: string) => { this.scope = s; } })
        }.width('100%').margin({ top: L.md })

        Row({ space: L.sm }) {
          Text('Hide dependencies').fontSize(F.callout).fontColor(C.textSecondary)
          Toggle({ type: ToggleType.Switch, isOn: this.hideDeps }).width(36).height(20)
            .onChange((v: boolean) => { this.hideDeps = v; })
        }.margin({ top: L.sm })
      }
      .width('100%').padding({ left: L.lg, right: L.lg, top: L.md, bottom: L.md })
       .backgroundColor(C.surface).border({ width: { bottom: 1 }, color: C.borderSeparator })

      Row({ space: 0 }) {
        Scroll() {
          Column({ space: 2 }) {
            ForEach(this.filtered(), (p: LivePkg) => {
              PackageRow({ p: p, selected: this.selected?.name === p.name,
                           onSelect: (x: LivePkg) => { this.selected = x; } })
            })
          }.width('100%').padding({ left: L.sm, right: L.sm, top: L.sm, bottom: L.sm })
        }.layoutWeight(1).height('100%').backgroundColor(C.surface)

        DetailPanel({ p: this.selected, taskPhase: this.taskPhase,
                      onUninstall: this.onUninstall, onUpgrade: this.onUpgrade })
          .width(L.inspectorWidth + 100)
      }.width('100%').layoutWeight(1)
    }.width('100%').height('100%').backgroundColor(C.surfaceElevated)
  }
}

// ============ Upgrades 页 ============
@Component
export struct UpgradesPage {
  @Prop packages: LivePkg[] = [];
  @Prop taskPhase: string = '';
  onUpgrade: (p: LivePkg) => void = () => {};
  onUpgradeAll: () => void = () => {};
  onRefresh: () => void = () => {};
  onCancel: () => void = () => {};
  @State selected: LivePkg | undefined = undefined;
  @State query: string = '';
  @State scope: string = 'All';

  private outdated(): LivePkg[] {
    let list = this.packages.filter((p: LivePkg): boolean => p.outdated);
    if (this.scope === 'Formulae') list = list.filter((p: LivePkg): boolean => !isCask(p));
    if (this.scope === 'Casks') list = list.filter((p: LivePkg): boolean => isCask(p));
    if (this.query.length > 0) {
      const q = this.query.toLowerCase();
      list = list.filter((p: LivePkg): boolean => p.name.toLowerCase().includes(q));
    }
    return list;
  }

  build() {
    Column({ space: 0 }) {
      Column({ space: 4 }) {
        Row() {
          Column() {
            Text('Upgrades').fontSize(F.title3).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
            Text('Review and upgrade outdated packages').fontSize(F.caption).fontColor(C.textSecondary)
          }.alignItems(HorizontalAlign.Start)
          Blank()
          Row({ space: 6 }) {
            Text('🔍').fontSize(12).fontColor(C.textSecondary)
            TextInput({ placeholder: 'Search Upgrades', text: this.query })
              .fontSize(F.callout).backgroundColor(Color.Transparent).borderWidth(0).width(200).height(28)
              .onChange((v: string) => { this.query = v; })
          }.padding({ left: L.sm, right: L.md, top: 4, bottom: 4 })
           .borderRadius(16).backgroundColor(C.surfaceElevated).border({ width: 1, color: C.borderDefault })
        }.width('100%')
      }.width('100%').padding({ left: L.lg, right: L.lg, top: L.md, bottom: L.md })
       .backgroundColor(C.surface).border({ width: { bottom: 1 }, color: C.borderSeparator })

      Row({ space: 0 }) {
        Scroll() {
          Column({ space: L.sm }) {
            // 全局命令框
            Column({ space: L.sm }) {
              Row({ space: 6 }) {
                if (this.outdated().length > 0) {
                  Text(this.outdated().length + ' packages can be upgraded')
                    .fontSize(F.title2).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
                } else {
                  Text('Everything is up to date').fontSize(F.title2).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
                  InstalledCheck()
                }
              }
              CommandCard({ command: 'brew upgrade', note: 'Upgrades every outdated package' })
              Row({ space: L.sm }) {
                if (this.taskPhase === 'running') {
                  Button('取消').fontSize(F.callout).fontColor(C.statusError).backgroundColor(C.statusErrorSubtle)
                    .height(30).onClick(() => { this.onCancel(); })
                } else {
                  Button('Upgrade All (' + this.outdated().length + ')').fontSize(F.callout)
                    .fontColor(Color.White).backgroundColor(C.ctaBlue).height(30)
                    .onClick(() => { this.onUpgradeAll(); })
                }
                Button('↻ Refresh').fontSize(F.callout).fontColor(C.textSecondary).backgroundColor(C.surface)
                  .height(30).border({ width: 1, color: C.borderDefault }).onClick(() => { this.onRefresh(); })
              }
              ScopeSegments({ scope: this.scope, onScope: (s: string) => { this.scope = s; } })
            }.width('100%').padding({ left: L.lg, right: L.lg, top: L.md })

            if (this.outdated().length > 0) {
              ForEach(this.outdated(), (p: LivePkg) => {
                Row({ space: L.sm }) {
                  PackageIcon({ p: p, size: 30 })
                  Column({ space: 2 }) {
                    Row({ space: 6 }) {
                      Text(p.name).fontSize(F.body).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
                      TypeBadge({ p: p })
                      OutdatedBadge()
                    }
                    Text(p.desc).fontSize(F.callout).fontColor(C.textSecondary).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text('v' + p.installedVersion + ' → v' + p.latestVersion).fontSize(F.caption2).fontColor(C.outdated)
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                }.width('100%').padding({ left: L.md, right: L.md, top: L.sm, bottom: L.sm })
                 .borderRadius(L.radiusMd).backgroundColor(this.selected?.name === p.name ? C.brandTint : Color.Transparent)
                 .onClick(() => { this.selected = p; })
              })
            } else {
              Column({ space: L.sm }) {
                Text('✓').fontSize(36).fontColor(C.statusSuccess)
                Text('Everything is up to date').fontSize(F.title1).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
                Text('All ' + this.packages.length + ' installed packages are up to date.')
                  .fontSize(F.callout).fontColor(C.textSecondary)
              }.width('100%').padding({ top: 80 }).alignItems(HorizontalAlign.Center)
            }
          }.width('100%').padding({ bottom: L.sm })
        }.layoutWeight(1).height('100%').backgroundColor(C.surface)
        DetailPanel({ p: this.selected, taskPhase: this.taskPhase, onUpgrade: this.onUpgrade })
          .width(L.inspectorWidth + 100)
      }.width('100%').layoutWeight(1)
    }.width('100%').height('100%').backgroundColor(C.surfaceElevated)
  }
}

// ============ Discover 页 ============
@Component
export struct DiscoverPage {
  @Prop packages: LivePkg[] = [];
  @State query: string = '';
  @State selected: LivePkg | undefined = undefined;
  @State scope: string = 'All';

  private suggestions(): LivePkg[] {
    let list = this.packages.slice();
    if (this.query.length > 0) {
      const q = this.query.toLowerCase();
      list = list.filter((p: LivePkg): boolean => p.name.toLowerCase().includes(q));
    }
    return list.slice(0, 40);
  }

  @Builder
  DiscoverRow(p: LivePkg) {
    Row({ space: L.sm }) {
      PackageIcon({ p: p, size: 30 })
      Column({ space: 2 }) {
        Row({ space: 6 }) {
          Text(p.name).fontSize(F.body).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
          TypeBadge({ p: p })
        }
        Text(p.desc).fontSize(F.callout).fontColor(C.textSecondary).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('v' + p.latestVersion + '  ·  ' + pseudoInstalls(p.name).toString() + ' installs (30d)')
          .fontSize(F.caption2).fontColor(C.textTertiary)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').padding({ left: L.md, right: L.md, top: 6, bottom: 6 })
     .borderRadius(L.radiusMd)
     .backgroundColor(this.selected?.name === p.name ? C.brandTint : Color.Transparent)
     .onClick(() => { this.selected = p; })
  }

  build() {
    Column({ space: 0 }) {
      Column({ space: 4 }) {
        Row() {
          Column() {
            Text('Discover').fontSize(F.title3).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
            Text('Browse and search 9,000+ packages').fontSize(F.caption).fontColor(C.textSecondary)
          }.alignItems(HorizontalAlign.Start)
          Blank()
          Row({ space: 6 }) {
            Text('⌕').fontSize(14).fontColor(C.textSecondary)
            TextInput({ placeholder: "Search Homebrew's Packages", text: this.query })
              .fontSize(F.callout).backgroundColor(Color.Transparent).borderWidth(0).width(240).height(28)
              .onChange((v: string) => { this.query = v; })
            if (this.query.length > 0) {
              Text('✕').fontSize(12).fontColor(C.textSecondary).onClick(() => { this.query = ''; })
            }
          }.padding({ left: L.sm, right: L.md, top: 4, bottom: 4 })
           .borderRadius(16).backgroundColor(C.surfaceElevated)
           .border({ width: 1, color: this.query.length > 0 ? C.ctaBlue : C.borderDefault })
        }.width('100%')

        Column({ space: 2 }) {
          if (this.query.length > 0) {
            Text('Results').fontSize(F.title2).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
            Text(this.suggestions().length + ' packages match "' + this.query + '"')
              .fontSize(F.caption).fontColor(C.textSecondary)
          } else {
            Text('Trending').fontSize(F.title2).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
            Text('📈 Most-installed packages in the last 30 days').fontSize(F.caption).fontColor(C.textSecondary)
          }
          ScopeSegments({ scope: this.scope, onScope: (s: string) => { this.scope = s; } })
        }.width('100%').alignItems(HorizontalAlign.Start).margin({ top: L.md })
      }.width('100%').padding({ left: L.lg, right: L.lg, top: L.md, bottom: L.md })
       .backgroundColor(C.surface).border({ width: { bottom: 1 }, color: C.borderSeparator })

      Row({ space: 0 }) {
        Scroll() {
          Column({ space: L.sm }) {
            Text(this.query.length > 0 ? 'Formulae' : 'Popular Formulae')
              .fontSize(F.body).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
              .padding({ left: L.md, top: L.sm })
            ForEach(this.suggestions().filter((p: LivePkg): boolean => !isCask(p)), (p: LivePkg) => {
              this.DiscoverRow(p)
            })
            Text(this.query.length > 0 ? 'Casks' : 'Popular Casks')
              .fontSize(F.body).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
              .padding({ left: L.md, top: L.md })
            ForEach(this.suggestions().filter((p: LivePkg): boolean => isCask(p)), (p: LivePkg) => {
              this.DiscoverRow(p)
            })
          }.width('100%').padding({ bottom: L.sm })
        }.layoutWeight(1).height('100%').backgroundColor(C.surface)

        // Discover 详情面板：Install 区块（用通用 DetailPanel 的扩展）
        DiscoverDetail({ p: this.selected })
          .width(L.inspectorWidth + 100)
      }.width('100%').layoutWeight(1)
    }.width('100%').height('100%').backgroundColor(C.surfaceElevated)
  }
}

// Discover 专用详情（带 Install 区块，蓝色按钮）
@Component
struct DiscoverDetail {
  @Prop p: LivePkg | undefined = undefined;
  build() {
    if (this.p !== undefined) {
      Scroll() {
        Column({ space: L.md }) {
          Row({ space: L.md }) {
            PackageIcon({ p: this.p!, size: 40 })
            Column({ space: 2 }) {
              Row({ space: 6 }) {
                Text(this.p!.name).fontSize(F.title2).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
                TypeBadge({ p: this.p! })
              }
              Text(this.p!.desc).fontSize(F.callout).fontColor(C.textSecondary)
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }.width('100%')
          Divider().color(C.borderSeparator)
          Column({ space: 2 }) {
            Text('Details').fontSize(F.body).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
            Row({ space: L.md }) {
              Text('Latest version').fontSize(F.callout).fontColor(C.textSecondary).width(120)
              Text(this.p!.latestVersion).fontSize(F.callout).fontColor(C.textPrimary)
            }.width('100%').padding({ top: 3, bottom: 3 })
            Row({ space: L.md }) {
              Text('30-day installs').fontSize(F.callout).fontColor(C.textSecondary).width(120)
              Text(pseudoInstalls(this.p!.name).toString()).fontSize(F.callout).fontColor(C.textPrimary)
            }.width('100%').padding({ top: 3, bottom: 3 })
            if (this.p!.homepage.length > 0) {
              Row({ space: L.md }) {
                Text('Homepage').fontSize(F.callout).fontColor(C.textSecondary).width(120)
                Text(this.p!.homepage + ' ↗').fontSize(F.callout).fontColor(C.textLink)
              }.width('100%').padding({ top: 3, bottom: 3 })
            }
          }.width('100%')
          Divider().color(C.borderSeparator)
          Column({ space: 4 }) {
            Text('Dependencies').fontSize(F.body).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
            Text('No dependencies.').fontSize(F.callout).fontColor(C.textSecondary)
          }.width('100%').alignItems(HorizontalAlign.Start)
          Divider().color(C.borderSeparator)
          Column({ space: L.sm }) {
            Text('Install').fontSize(F.body).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
            CommandCard({ command: 'brew install --' + (isCask(this.p!) ? 'cask ' : 'formula ') + this.p!.name,
                          note: 'Installs this package on your Mac' })
            Button('Install').fontSize(F.callout).fontColor(Color.White).backgroundColor(C.ctaBlue)
              .padding({ left: L.lg, right: L.lg, top: L.xs, bottom: L.xs }).borderRadius(L.radiusSm)
          }.width('100%').alignItems(HorizontalAlign.Start)
        }.width('100%').padding(L.lg)
      }.width('100%').height('100%').backgroundColor(C.surfaceElevated)
       .border({ width: { left: 1 }, color: C.borderSeparator })
    } else {
      Column({ space: L.sm }) {
        Text('No selection').fontSize(F.title2).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
        Text('Choose a package from the list to see details.')
          .fontSize(F.callout).fontColor(C.textSecondary)
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
       .backgroundColor(C.surfaceElevated).border({ width: { left: 1 }, color: C.borderSeparator })
    }
  }
}
