import { C, L, F } from '../theme/Tokens';
import common from '@ohos.app.ability.common';
import { InstalledCask, LivePkg } from '../data/BrewRunner';
import { CommandCard, DetailLine, DetailLink, Segments } from './PageChrome';
import { CatalogueKind, CataloguePackage, loadCatalogue, searchCatalogue } from '../data/BrewCatalogue';
import { DownloadStats, loadDownloads } from '../data/BrewDownloads';

function formatDate(ts: number): string {
  if (ts <= 0) return '—';
  const date = new Date(ts * 1000);
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

function packageKey(p: LivePkg): string { return p.fullName || p.name; }

function isManagedByTerminal(p: LivePkg): boolean { return p.name === 'brewo-app' || p.name === 'harbor-app'; }

function resolveDependency(name: string, packages: LivePkg[]): LivePkg | undefined {
  if (name.includes('/')) return packages.find((p: LivePkg) => p.fullName === name);
  const matches = packages.filter((p: LivePkg) => p.name === name);
  return matches.length === 1 ? matches[0] : undefined;
}

function dependentsOf(p: LivePkg, packages: LivePkg[]): LivePkg[] {
  const shortNameIsUnique = packages.filter((other: LivePkg) => other.name === p.name).length === 1;
  return packages.filter((other: LivePkg) => packageKey(other) !== packageKey(p) &&
    (other.deps.includes(packageKey(p)) || (shortNameIsUnique && other.deps.includes(p.name))));
}

@Component
struct RelationshipLines {
  @Prop count: number = 0;
  @Prop graphHeight: number = 42;
  @Prop incoming: boolean = true;

  private commands(): string {
    const middle = this.graphHeight / 2;
    const scale = this.getUIContext().vp2px(1);
    const paths: string[] = [];
    for (let index = 0; index < this.count; index++) {
      const node = middle + (index - (this.count - 1) / 2) * 36;
      const from = this.incoming ? node : middle;
      const to = this.incoming ? middle : node;
      paths.push(`M 0 ${from * scale} C ${12 * scale} ${from * scale} ${10 * scale} ${to * scale} ${22 * scale} ${to * scale}`);
    }
    return paths.join(' ');
  }

  build() {
    Stack() {
      if (this.count > 0) {
        Path().width(22).height(this.graphHeight).commands(this.commands())
          .fill(Color.Transparent).stroke(this.incoming ? C.textLink : C.outdated).strokeWidth(1.2)
      }
    }.width(22).height(this.graphHeight)
  }
}

@Component
struct PackageGlyph {
  @Prop name: string = '';
  @Prop glyphSize: number = 34;

  private accent(): ResourceColor {
    const colors = [C.textLink, C.statusSuccess, C.outdated, C.caskBlue];
    return colors[(this.name.charCodeAt(0) || 0) % colors.length];
  }

  build() {
    Text(this.name.slice(0, 2).toUpperCase()).fontSize(this.glyphSize * 0.34)
      .fontWeight(FontWeight.Bold).fontColor(this.accent()).fontFamily('monospace')
      .width(this.glyphSize).height(this.glyphSize).textAlign(TextAlign.Center)
      .backgroundColor(C.surfaceRecessed).border({ width: 1, color: C.borderDefault, radius: 8 })
  }
}

@Component
struct SearchBox {
  @Link query: string;
  @Prop hint: string = '';
  @Prop focusKey: string = '';
  @State focused: boolean = false;

  build() {
    Row({ space: 4 }) {
      Text('⌕').fontSize(19).fontColor(C.textTertiary)
      TextInput({ placeholder: this.hint, text: this.query }).height(34).layoutWeight(1)
        .id(this.focusKey)
        .fontSize(F.body).fontColor(C.textPrimary).placeholderColor(C.textTertiary)
        .padding({ left: 2, right: 2 }).backgroundColor(Color.Transparent)
        .onFocus(() => { this.focused = true; }).onBlur(() => { this.focused = false; })
        .onChange((value: string) => { this.query = value; })
      if (this.query.length > 0) {
        Button('×', { type: ButtonType.Normal }).width(28).height(28).padding(0)
          .backgroundColor(Color.Transparent).fontColor(C.textSecondary)
          .accessibilityText('清除搜索').onClick(() => { this.query = ''; })
      }
    }.width('100%').padding({ left: L.sm, right: L.xs }).backgroundColor(C.surfaceRecessed)
    .border({ width: 1, color: this.focused ? C.brandPrimary : C.borderDefault, radius: L.radiusSm })
  }
}

@Component
struct PackageTableRow {
  @Prop pkg: LivePkg;
  @Prop selected: boolean = false;
  @Prop showDate: boolean = true;
  onSelect: (p: LivePkg) => void = () => {};

  build() {
    Row({ space: L.sm }) {
      PackageGlyph({ name: this.pkg.name })
      Column({ space: 3 }) {
        Text(this.pkg.name).fontSize(F.body).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.pkg.desc || this.pkg.tap).fontSize(F.caption).fontColor(C.textSecondary)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text(this.pkg.installedVersion || '—').fontSize(F.caption2).fontFamily('monospace')
        .fontColor(this.pkg.outdated ? C.outdated : C.textSecondary).width(64).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.showDate) {
        Text(formatDate(this.pkg.installTime)).fontSize(F.caption2).width(72).fontColor(C.textTertiary)
      }
      Text('›').fontSize(17).width(9).fontColor(C.textTertiary)
    }.width('100%').height(55).padding({ left: L.sm, right: L.sm })
    .backgroundColor(this.selected ? C.selectionFill : C.surfaceElevated)
    .border({ width: 1, color: C.borderSeparator, radius: L.radiusSm })
    .focusable(true).onClick(() => { this.onSelect(this.pkg); })
  }
}

@Component
struct DetailField {
  @Prop label: string = '';
  @Prop value: string = '';

  build() {
    Row({ space: L.sm }) {
      Text(this.label).fontSize(F.callout).fontColor(C.textSecondary).width(72)
      Text(this.value).fontSize(F.callout).fontColor(C.textPrimary).layoutWeight(1)
        .copyOption(CopyOptions.LocalDevice)
    }.width('100%').padding({ top: 5, bottom: 5 })
  }
}

@Component
struct PackageInspector {
  @Prop @Watch('refreshDependents') pkg: LivePkg;
  @Prop @Watch('refreshDependents') packages: LivePkg[] = [];
  @Prop taskPhase: string = '';
  @Prop refreshing: boolean = false;
  @State tab: string = '概览';
  @State dependents: LivePkg[] = [];
  onSelect: (p: LivePkg) => void = () => {};
  onUninstall: (p: LivePkg) => void = () => {};
  onUpgrade: (p: LivePkg) => void = () => {};

  aboutToAppear(): void { this.refreshDependents(); }

  private refreshDependents(): void { this.dependents = dependentsOf(this.pkg, this.packages); }

  private openDependency(name: string): void {
    const match = resolveDependency(name, this.packages);
    if (match) this.onSelect(match);
  }

  private confirmUninstall(): void {
    const pkg = this.pkg;
    this.getUIContext().showAlertDialog({
      title: '卸载 ' + pkg.name + '？',
      message: '将通过 Harmonybrew 从这台电脑移除此软件包。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '卸载', fontColor: C.statusError, action: () => { this.onUninstall(pkg); } }
    });
  }

  @Builder
  Relation(name: string, incoming: boolean) {
    Row({ space: 5 }) {
      Circle({ width: 5, height: 5 }).fill(incoming ? C.textLink : C.outdated)
      Text(name.split('/').pop() || name).fontSize(F.caption).fontColor(C.textPrimary).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
    }.width('100%').height(31).padding({ left: 6, right: 4 })
    .backgroundColor(C.surfaceElevated).border({ width: 1, color: C.borderDefault, radius: 6 })
    .focusable(true).onClick(() => { this.openDependency(name); })
  }

  private graphHeight(): number {
    return Math.max(70, Math.min(5, Math.max(this.pkg.deps.length, this.dependents.length)) * 36 - 5);
  }

  @Builder
  Relationships() {
    Column({ space: L.sm }) {
      Row({ space: L.sm }) {
        Text('依赖项 · ' + this.pkg.deps.length).fontSize(F.caption).fontColor(C.textLink).layoutWeight(1)
        Text('被依赖 · ' + this.dependents.length).fontSize(F.caption).fontColor(C.outdated)
      }.width('100%')
      Row() {
        Column({ space: 5 }) {
          if (this.pkg.deps.length === 0) {
            Text('无依赖项').fontSize(F.caption).fontColor(C.textTertiary)
          }
          ForEach(this.pkg.deps.slice(0, 5), (name: string) => { this.Relation(name, true) }, (name: string) => name)
        }.layoutWeight(1)
        RelationshipLines({ count: Math.min(5, this.pkg.deps.length), graphHeight: this.graphHeight() })
        Column({ space: 5 }) {
          PackageGlyph({ name: this.pkg.name, glyphSize: 32 })
          Text(this.pkg.name).fontSize(F.caption).fontWeight(FontWeight.Bold).fontColor(C.statusSuccess)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).textAlign(TextAlign.Center)
        }.width(78).padding(6).backgroundColor(C.statusSuccessSubtle)
        .border({ width: 1, color: C.statusSuccess, radius: 8 })
        RelationshipLines({ count: Math.min(5, this.dependents.length), graphHeight: this.graphHeight(), incoming: false })
        Column({ space: 5 }) {
          if (this.dependents.length === 0) {
            Text('无已知下游').fontSize(F.caption).fontColor(C.textTertiary)
          }
          ForEach(this.dependents.slice(0, 5), (item: LivePkg) => { this.Relation(packageKey(item), false) },
            (item: LivePkg) => packageKey(item))
        }.layoutWeight(1)
      }.width('100%')
      if (this.pkg.deps.length > 5 || this.dependents.length > 5) {
        if (this.tab === '概览') {
          Button('查看完整依赖关系', { type: ButtonType.Normal }).height(28).fontSize(F.caption)
            .fontColor(C.textLink).backgroundColor(Color.Transparent).onClick(() => { this.tab = '依赖关系'; })
        } else {
          Column({ space: 5 }) {
            ForEach(this.pkg.deps.slice(5), (name: string) => { this.Relation(name, true) }, (name: string) => name)
            ForEach(this.dependents.slice(5), (item: LivePkg) => { this.Relation(packageKey(item), false) },
              (item: LivePkg) => packageKey(item))
          }.width('100%')
        }
      }
      if (this.dependents.length > 0) {
        Text('有 ' + this.dependents.length + ' 个已安装软件包声明依赖此包。卸载前请先处理这些依赖。')
          .fontSize(F.callout).fontColor(C.statusWarning).width('100%').padding(L.sm)
          .backgroundColor(C.statusWarningSubtle).borderRadius(6)
      }
    }.width('100%').padding(L.md).backgroundColor(C.surfaceRecessed)
    .border({ width: 1, color: C.borderSeparator, radius: L.radiusMd })
  }

  build() {
    Scroll() {
      Column({ space: L.md }) {
        Row({ space: L.md }) {
          PackageGlyph({ name: this.pkg.name, glyphSize: 46 })
          Column({ space: 4 }) {
            Text(this.pkg.name).fontSize(F.title1).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.pkg.desc).fontSize(F.callout).fontColor(C.textSecondary)
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Text(this.pkg.outdated ? '有更新' : '已安装').fontSize(F.caption)
            .fontColor(this.pkg.outdated ? C.outdated : C.statusSuccess).padding(6).borderRadius(6)
            .backgroundColor(this.pkg.outdated ? C.statusWarningSubtle : C.statusSuccessSubtle)
        }.width('100%')

        Row({ space: 4 }) {
          ForEach(['概览', '依赖关系', '来源'], (tab: string) => {
            Button(tab, { type: ButtonType.Normal }).height(31).layoutWeight(1).borderRadius(6)
              .fontSize(F.callout).fontColor(this.tab === tab ? Color.White : C.textSecondary)
              .backgroundColor(this.tab === tab ? C.ctaBlue : Color.Transparent)
              .onClick(() => { this.tab = tab; })
          }, (tab: string) => tab)
        }.width('100%').padding(4).backgroundColor(C.surfaceRecessed).borderRadius(8)

        if (this.tab === '来源') {
          Column() {
            DetailField({ label: '来源', value: this.pkg.tap || '—' })
            DetailField({ label: '名称', value: packageKey(this.pkg) })
            DetailField({ label: '主页', value: this.pkg.homepage || '—' })
            DetailField({ label: '许可证', value: this.pkg.license || '—' })
          }.width('100%').padding(L.md).backgroundColor(C.surfaceRecessed).borderRadius(L.radiusMd)
        } else {
          this.Relationships()
          if (this.tab === '概览') {
            Column() {
              DetailField({ label: '当前版本', value: this.pkg.installedVersion || '—' })
              if (this.pkg.outdated) { DetailField({ label: '最新版本', value: this.pkg.latestVersion || '—' }) }
              DetailField({ label: '安装时间', value: formatDate(this.pkg.installTime) })
              DetailField({ label: '安装原因', value: this.pkg.installedOnRequest ? '主动安装' : '作为依赖安装' })
            }.width('100%').padding(L.md).backgroundColor(C.surfaceRecessed).borderRadius(L.radiusMd)
          }
          Row({ space: L.sm }) {
            if (this.pkg.outdated && !isManagedByTerminal(this.pkg)) {
              Button('更新软件包', { type: ButtonType.Normal }).height(32).borderRadius(6)
                .fontSize(F.callout).fontColor(Color.White).backgroundColor(C.ctaBlue)
                .enabled(this.taskPhase !== 'running' && !this.refreshing && !this.pkg.pinned)
                .onClick(() => { this.onUpgrade(this.pkg); })
            }
            if (isManagedByTerminal(this.pkg)) {
              Text('请在终端中管理此软件包。').fontSize(F.callout).fontColor(C.textSecondary)
            } else {
              Button('卸载…', { type: ButtonType.Normal }).height(32).borderRadius(6)
                .fontSize(F.callout).fontColor(C.statusError).backgroundColor(C.statusErrorSubtle)
                .enabled(this.taskPhase !== 'running' && !this.refreshing && this.dependents.length === 0)
                .onClick(() => { this.confirmUninstall(); })
            }
          }.width('100%')
        }
      }.width('100%').padding(L.lg).alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').align(Alignment.TopStart)
  }
}

@Component
export struct InstalledPage {
  @Prop packages: LivePkg[] = [];
  @Prop loaded: boolean = false;
  @Prop loadFailed: boolean = false;
  @Prop taskPhase: string = '';
  @Link selected: string;
  @State query: string = '';
  @State hideDeps: boolean = false;
  @State paneWidth: number = 900;
  @State showDetail: boolean = false;
  onUninstall: (p: LivePkg) => void = () => {};
  onUpgrade: (p: LivePkg) => void = () => {};

  aboutToAppear(): void { this.showDetail = this.selected.length > 0; }

  private filtered(): LivePkg[] {
    const query = this.query.trim().toLowerCase();
    return this.packages.filter((p: LivePkg) => (!this.hideDeps || p.installedOnRequest) &&
      (p.name.toLowerCase().includes(query) || p.desc.toLowerCase().includes(query)));
  }

  private select(p: LivePkg): void { this.selected = packageKey(p); this.showDetail = true; }

  private selectedPackage(): LivePkg | undefined {
    if (this.selected.length === 0) return this.filtered()[0];
    return this.packages.find((p: LivePkg) => packageKey(p) === this.selected);
  }

  private showsDate(): boolean {
    return this.paneWidth >= 830 || (this.paneWidth < 740 && this.paneWidth >= 410);
  }

  @Builder
  Inventory() {
    Column({ space: L.sm }) {
      Row({ space: L.sm }) {
        Column({ space: 4 }) {
          Text('已安装的软件包').fontSize(F.title1).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
          Text(this.loadFailed ? '读取失败，可在升级页重试' :
            this.loaded ? this.filtered().length + ' / ' + this.packages.length + ' 个软件包' : '正在读取本机软件包…')
            .fontSize(F.caption).fontColor(C.textSecondary)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Row({ space: L.xs }) {
          Text('隐藏依赖').fontSize(F.callout).fontColor(C.textPrimary)
          Toggle({ type: ToggleType.Switch, isOn: this.hideDeps }).width(35).height(20)
            .selectedColor(C.ctaBlue).accessibilityText('隐藏依赖').onChange((value: boolean) => { this.hideDeps = value; })
        }.padding(L.sm).backgroundColor(C.brandTint).borderRadius(L.radiusSm)
      }.width('100%').padding({ bottom: 5 })
      SearchBox({ query: this.query, hint: '搜索包名或描述' })

      Row({ space: L.sm }) {
        Text('软件包').fontSize(F.caption).fontColor(C.textSecondary).layoutWeight(1)
        Text('版本').fontSize(F.caption).fontColor(C.textSecondary).width(64)
        if (this.showsDate()) {
          Text('安装时间').fontSize(F.caption).fontColor(C.textSecondary).width(72)
        }
        Blank().width(9)
      }.width('100%').height(30).padding({ left: L.sm, right: L.sm })
      .backgroundColor(C.surfaceRecessed).borderRadius(L.radiusSm)

      if (this.loaded && this.filtered().length === 0) {
        Text('没有符合条件的软件包').fontSize(F.body).fontColor(C.textSecondary).margin({ top: L.xl })
      }
      if (!this.loaded && !this.loadFailed) {
        Column({ space: L.sm }) {
          ForEach([0, 1, 2, 3, 4], (index: number) => {
            Column({ space: 6 }) {
              Row({ space: L.sm }) {
                Rect().width(index % 2 === 0 ? '36%' : '27%').height(9).fill(C.borderDefault).radius(3)
                Rect().width(36).height(8).fill(C.selectionFill).radius(3)
              }.width('100%')
              Rect().width(index % 2 === 0 ? '74%' : '67%').height(7).fill(C.surfaceRecessed).radius(3)
            }.width('100%').height(45).alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Center)
              .padding({ left: L.md, right: L.md }).border({ width: { bottom: 1 }, color: C.borderSeparator })
          }, (index: number) => String(index))
        }.width('100%').alignItems(HorizontalAlign.Start).accessibilityLevel('no')
      }
      List({ space: 5 }) {
        ForEach(this.filtered(), (p: LivePkg) => {
          ListItem() {
            PackageTableRow({ pkg: p, selected: p === this.selectedPackage(),
              showDate: this.showsDate(),
              onSelect: (item: LivePkg) => { this.select(item); } })
          }
        }, (p: LivePkg) => packageKey(p))
      }.width('100%').layoutWeight(1)
    }.height('100%').padding(L.md).backgroundColor(C.surface)
    .border({ width: 1, color: C.borderDefault, radius: L.radiusMd })
  }

  @Builder
  Inspector() {
    Column() {
      if (this.paneWidth < 740) {
        Button('‹ 返回软件包', { type: ButtonType.Normal }).height(32).fontSize(F.callout)
          .fontColor(C.textLink).backgroundColor(Color.Transparent)
          .onClick(() => { this.showDetail = false; })
      }
      if (this.selectedPackage() !== undefined) {
        Column() {
          PackageInspector({ pkg: this.selectedPackage()!, packages: this.packages, taskPhase: this.taskPhase,
            onSelect: (item: LivePkg) => { this.select(item); },
            onUninstall: this.onUninstall, onUpgrade: this.onUpgrade })
        }.width('100%').layoutWeight(1)
      } else {
        Column({ space: L.sm }) {
          Text('▣').fontSize(26).fontColor(C.textLink)
          Text('软件包详情').fontSize(F.title2).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
          Text('选择一个软件包，查看版本、来源与依赖。').fontSize(F.callout).fontColor(C.textSecondary)
            .textAlign(TextAlign.Center)
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).padding(L.lg)
      }
    }.height('100%').backgroundColor(C.surface)
    .border({ width: 1, color: C.borderDefault, radius: L.radiusMd }).clip(true)
  }

  build() {
    Row({ space: L.md }) {
      if (this.paneWidth >= 740 || !this.showDetail) {
        Column() { this.Inventory() }.layoutWeight(1).height('100%')
      }
      if (this.paneWidth >= 740 || this.showDetail) {
        Column() { this.Inspector() }
          .layoutWeight(this.paneWidth >= 740 ? 1.1 : 1).height('100%')
      }
    }.width('100%').height('100%').onAreaChange((_, area) => { this.paneWidth = Number(area.width); })
  }
}

@Component
export struct UpgradesPage {
  @Prop packages: LivePkg[] = [];
  @Prop loaded: boolean = false;
  @Prop loading: boolean = true;
  @Prop loadFailed: boolean = false;
  @Prop widthAvailable: number = 0;
  @Prop taskPhase: string = '';
  @State query: string = '';
  @State checkedKeys: string[] = [];
  @State selectedKey: string = '';
  onUpgrade: (p: LivePkg) => void = () => {};
  onUninstall: (p: LivePkg) => void = () => {};
  onUpgradeSelected: (packages: LivePkg[]) => void = () => {};
  onPreview: (packages: LivePkg[]) => void = () => {};
  onRefresh: () => void = () => {};
  onOpenInstalled: (p: LivePkg) => void = () => {};
  private upgradeScroller: ListScroller = new ListScroller();

  private outdated(): LivePkg[] { return this.packages.filter((p: LivePkg) => p.outdated && !p.pinned); }

  private visible(): LivePkg[] {
    const query = this.query.trim().toLowerCase();
    return this.outdated().filter((p: LivePkg) => packageKey(p).toLowerCase().includes(query) ||
      p.desc.toLowerCase().includes(query));
  }

  private active(): LivePkg | undefined {
    return this.visible().find((p: LivePkg) => packageKey(p) === this.selectedKey);
  }

  private actionable(): LivePkg[] { return this.visible().filter((p: LivePkg) => !isManagedByTerminal(p)); }
  private checked(): LivePkg[] { return this.actionable().filter((p: LivePkg) => this.checkedKeys.includes(packageKey(p))); }
  private targets(): LivePkg[] { return this.checked().length > 0 ? this.checked() : this.actionable(); }
  private busy(): boolean { return this.loading || this.taskPhase === 'running'; }

  private toggle(p: LivePkg, checked: boolean): void {
    const key = packageKey(p);
    if (checked && !this.checkedKeys.includes(key)) this.checkedKeys = this.checkedKeys.concat(key);
    if (!checked) this.checkedKeys = this.checkedKeys.filter((item: string) => item !== key);
  }

  private subtitle(): string {
    if (!this.loaded && this.loading) return '正在加载软件包…';
    if (this.loading) return '正在检查可用升级…';
    if (this.loadFailed) return this.loaded ? '检查失败，显示上次结果' : '检查可用升级失败';
    const count = this.outdated().length;
    return this.query.trim() && count > 0 ? '显示 ' + this.visible().length + ' / ' + count + ' 个可用升级' :
      count + ' 个软件包可升级';
  }

  private command(): string {
    return 'brew upgrade --formula' + this.targets().map((p: LivePkg) => ' ' + packageKey(p)).join('');
  }

  private bulkLabel(): string {
    if (this.checked().length > 0) return '升级所选';
    return this.query.trim() ? '升级搜索结果' : '全部升级';
  }

  private navigateUpgrades(step: number): void {
    if (this.widthAvailable < 710) return;
    const rows = this.visible();
    const current = rows.findIndex((p: LivePkg) => packageKey(p) === this.selectedKey);
    const next = current + step;
    if (next < 0 || next >= rows.length) return;
    this.selectedKey = packageKey(rows[next]);
    this.upgradeScroller.scrollToIndex(next, false, ScrollAlign.AUTO);
  }

  @Builder
  UpgradeSkeleton() {
    Column() {
      ForEach([0, 1, 2, 3], (index: number) => {
        Column({ space: L.sm }) {
          Row({ space: L.sm }) {
            Rect().width(index === 3 ? '28%' : '37%').height(10).fill(C.borderDefault).radius(3)
            Rect().width(36).height(8).fill(C.statusWarningSubtle).radius(3)
            Rect().width(14).height(14).fill(C.statusSuccessSubtle).radius(3)
          }.width('100%')
          Rect().width('94%').height(8).fill(C.surfaceRecessed).radius(3)
          Rect().width('28%').height(7).fill(C.surfaceRecessed).radius(3)
        }.width('100%').height(78).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Start)
        if (index < 3) { Divider().color(C.borderSeparator) }
      }, (index: number) => String(index))
    }.width('100%').layoutWeight(1).clip(true).id('upgrades-list-skeleton')
      .accessibilityLevel('no-hide-descendants')
  }

  @Builder
  UpgradeActions() {
    Row({ space: L.xs }) {
      Checkbox().select(this.checked().length === this.actionable().length).selectedColor(C.ctaBlue)
        .width(20).height(20).enabled(!this.busy()).accessibilityText('勾选列表中可升级的软件包')
        .onChange((value: boolean) => {
          this.checkedKeys = value ? this.actionable().map((p: LivePkg) => packageKey(p)) : [];
        })
      Button('预览', { type: ButtonType.Normal }).height(32).borderRadius(6)
        .fontSize(F.callout).fontColor(C.textLink).backgroundColor(C.brandTint)
        .enabled(!this.busy()).onClick(() => { this.onPreview(this.targets()); })
      Button(this.bulkLabel() + '（' + this.targets().length + '）',
        { type: ButtonType.Normal }).height(32).borderRadius(6)
        .fontSize(F.callout).fontColor(Color.White).backgroundColor(C.ctaBlue)
        .enabled(!this.busy()).onClick(() => { this.onUpgradeSelected(this.targets()); })
    }.width('100%')
  }

  @Builder
  UpgradeRow(p: LivePkg) {
    Row({ space: L.sm }) {
      if (!isManagedByTerminal(p)) {
        Checkbox().select(this.checkedKeys.includes(packageKey(p))).selectedColor(C.ctaBlue).width(20).height(20)
          .enabled(!this.busy()).accessibilityText('勾选 ' + p.name)
          .onChange((value: boolean) => { this.toggle(p, value); })
      }
      Button({ type: ButtonType.Normal }) {
        Column({ space: L.xs }) {
          Text(p.name).fontSize(F.body).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(p.desc || p.tap).fontSize(F.callout).fontColor(C.textSecondary)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text((p.installedVersion || '—') + ' → ' + (p.latestVersion || '—'))
            .fontSize(F.caption).fontFamily('monospace').fontColor(C.outdated)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.width('100%').padding(L.sm).alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).padding(0).borderRadius(L.radiusSm).backgroundColor(Color.Transparent)
        .accessibilitySelected(this.selectedKey === packageKey(p)).id('upgrade-' + packageKey(p))
        .onClick(() => { this.selectedKey = packageKey(p); })
    }.width('100%').padding({ left: L.sm, right: L.sm }).borderRadius(L.radiusSm)
      .backgroundColor(this.selectedKey === packageKey(p) ? C.selectionFill : Color.Transparent)
  }

  @Builder
  AvailableUpgrades() {
    Column({ space: L.md }) {
      Row({ space: L.sm }) {
        Column({ space: L.xs }) {
          Text('可用升级').fontSize(F.title2).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
          Text(this.subtitle()).fontSize(F.callout).fontColor(C.textSecondary)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (this.loaded || this.loadFailed) {
          Button(this.loadFailed && !this.loading ? '重试' : '刷新', { type: ButtonType.Normal })
            .height(32).borderRadius(6).fontSize(F.callout).fontColor(C.textLink).backgroundColor(C.brandTint)
            .enabled(!this.busy()).onClick(() => { this.onRefresh(); })
        }
      }.width('100%')
      if (this.actionable().length > 0) {
        CommandCard({ command: this.command(), maxCommandLines: 2 })
        this.UpgradeActions()
      }
      if (!this.loaded && this.loading) {
        this.UpgradeSkeleton()
      } else if (this.visible().length > 0) {
        List({ scroller: this.upgradeScroller }) {
          ForEach(this.visible(), (p: LivePkg) => {
            ListItem() { this.UpgradeRow(p) }
          }, (p: LivePkg) => packageKey(p))
        }.width('100%').layoutWeight(1).divider({ strokeWidth: 1, color: C.borderSeparator })
          .keyboardShortcut(FunctionKey.DPAD_UP, [], () => { this.navigateUpgrades(-1); })
          .keyboardShortcut(FunctionKey.DPAD_DOWN, [], () => { this.navigateUpgrades(1); })
      } else if (!this.loading && !this.loadFailed) {
        Column({ space: L.sm }) {
          if (this.outdated().length > 0) {
            Text('没有匹配的升级').fontSize(F.title2).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
            Button('显示全部升级', { type: ButtonType.Normal }).height(32).fontSize(F.callout)
              .fontColor(C.textLink).backgroundColor(C.brandTint).onClick(() => { this.query = ''; })
          } else {
            Text('✓').fontSize(32).fontColor(C.statusSuccess)
            Text('没有可升级的软件包').fontSize(F.title2).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
          }
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      }
    }.width('100%').height('100%').padding(L.lg).alignItems(HorizontalAlign.Start)
  }

  @Builder
  UpgradeDetails() {
    Column() {
      if (this.widthAvailable < 710) {
        Button('‹ 返回可用升级', { type: ButtonType.Normal }).height(32).fontSize(F.callout)
          .fontColor(C.textLink).backgroundColor(Color.Transparent).onClick(() => { this.selectedKey = ''; })
      }
      if (this.active() !== undefined) {
        Column() {
          PackageInspector({ pkg: this.active()!, packages: this.packages, taskPhase: this.taskPhase,
            refreshing: this.loading, onUpgrade: this.onUpgrade, onUninstall: this.onUninstall,
            onSelect: this.onOpenInstalled })
        }.width('100%').layoutWeight(1)
      } else {
        Column({ space: L.xs }) {
          Text('尚未选择').fontSize(F.title2).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
          Text('从列表中选择一个软件包以查看详情。').fontSize(F.callout).fontColor(C.textSecondary)
        }.width('100%').padding(L.lg).alignItems(HorizontalAlign.Start).id('upgrades-no-selection')
      }
    }.width('100%').height('100%').alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center, justifyContent: FlexAlign.SpaceBetween }) {
        Column({ space: L.xs }) {
          Text('升级').fontSize(F.title1).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
          Text('查看并升级有新版本的软件包').fontSize(F.callout).fontColor(C.textSecondary)
        }.padding({ right: L.md, bottom: L.xs }).alignItems(HorizontalAlign.Start)
        Column() {
          SearchBox({ query: this.query, hint: '搜索可用升级', focusKey: 'upgrades-search' })
        }.width(this.widthAvailable >= 600 ? '43%' : '100%')
      }.width('100%').padding(L.lg).border({ width: { bottom: 1 }, color: C.borderSeparator })
      Row() {
        if (this.widthAvailable >= 710 || this.active() === undefined) {
          Column() { this.AvailableUpgrades() }.layoutWeight(1).height('100%')
        }
        if (this.widthAvailable >= 710 || this.active() !== undefined) {
          Column() { this.UpgradeDetails() }.layoutWeight(1).height('100%')
            .border({ width: { left: this.widthAvailable >= 710 ? 1 : 0 }, color: C.borderSeparator })
        }
      }.width('100%').layoutWeight(1)
    }.width('100%').height('100%').backgroundColor(C.surface)
      .border({ width: 1, color: C.borderDefault, radius: L.radiusMd })
      .keyboardShortcut('f', [ModifierKey.CTRL], () => {
        this.getUIContext().getFocusController().requestFocus('upgrades-search');
      })
      .keyboardShortcut(FunctionKey.ESC, [], () => { this.selectedKey = ''; })
  }
}

@Component
export struct DiscoverPage {
  @Prop installed: LivePkg[] = [];
  @Prop installedCasks: InstalledCask[] = [];
  @Prop widthAvailable: number = 0;
  @Prop taskRunning: boolean = false;
  onInstall: (pkg: CataloguePackage) => Promise<string> = (_pkg: CataloguePackage) => Promise.resolve('failed');
  @State @Watch('scheduleSearch') query: string = '';
  @State selected: string = '';
  @State @Watch('updateResults') scope: string = '全部';
  @State showDetails: boolean = false;
  @State results: CataloguePackage[] = [];
  @State matchCount: number = 0;
  @State formulaStatus: string = 'loading';
  @State caskStatus: string = 'loading';
  @State downloadStatus: string = 'loading';
  @State downloads: DownloadStats = { counts: new Map<string, number>(), days: 0 };
  @State installTarget: string = '';
  @State installPhase: string = '';
  private formulae: CataloguePackage[] = [];
  private casks: CataloguePackage[] = [];
  private searchTimer: number = -1;
  private resultScroller: ListScroller = new ListScroller();

  aboutToAppear(): void {
    this.refreshCatalogue(false);
  }

  aboutToDisappear(): void {
    clearTimeout(this.searchTimer);
  }

  private scheduleSearch(): void {
    clearTimeout(this.searchTimer);
    this.searchTimer = setTimeout(() => { this.updateResults(); }, 250);
  }

  private refreshCatalogue(force: boolean): void {
    void this.refreshKind('formula', force);
    void this.refreshKind('cask', force);
    this.downloadStatus = 'loading';
    loadDownloads(force).then((stats: DownloadStats) => {
      this.downloads = stats;
      this.downloadStatus = 'ready';
      this.updateResults();
    }).catch(() => { this.downloadStatus = 'error'; });
  }

  private async refreshKind(kind: CatalogueKind, force: boolean): Promise<void> {
    this.setCatalogueStatus(kind, 'loading');
    try {
      const packages = await loadCatalogue(kind, force);
      if (kind === 'formula') this.formulae = packages;
      else this.casks = packages;
      this.setCatalogueStatus(kind, 'ready');
      this.updateResults();
    } catch (error) {
      this.setCatalogueStatus(kind, 'error');
    }
  }

  private setCatalogueStatus(kind: CatalogueKind, status: string): void {
    if (kind === 'formula') this.formulaStatus = status;
    else this.caskStatus = status;
  }

  private updateResults(): void {
    const packages = this.scope === 'Formula' ? this.formulae : this.scope === 'Cask' ?
      this.casks : this.formulae.concat(this.casks);
    const matches = searchCatalogue(packages, this.query);
    this.matchCount = matches.length;
    if (!this.query.trim() && this.downloads.days > 0) {
      matches.sort((left: CataloguePackage, right: CataloguePackage) => this.downloadCount(right) - this.downloadCount(left));
    }
    const results = matches.slice(0, 50);
    if (!results.some((pkg: CataloguePackage) => pkg.id === this.selected)) {
      this.selected = '';
      this.showDetails = false;
    }
    this.results = results;
  }

  private active(): CataloguePackage | undefined {
    return this.results.find((p: CataloguePackage) => p.id === this.selected) ?? this.results[0];
  }

  private installedVersion(pkg: CataloguePackage): string {
    if (pkg.kind === 'cask') {
      return this.installedCasks.find((item: InstalledCask) => item.token === pkg.name && item.tap === pkg.tap)?.installed ?? '';
    }
    return this.installedFormula(pkg)?.installedVersion ?? '';
  }

  private installedFormula(pkg: CataloguePackage): LivePkg | undefined {
    if (pkg.kind !== 'formula') return undefined;
    return this.installed.find((item: LivePkg) => item.name === pkg.name && item.tap === pkg.tap);
  }

  private downloadCount(pkg: CataloguePackage): number {
    return pkg.kind === 'formula' ? (this.downloads.counts.get(pkg.name) ?? 0) : 0;
  }

  private subtitle(): string {
    if (this.showCatalogueSkeleton()) return '正在加载在线目录…';
    if (this.catalogueStatus('error') && this.results.length === 0) return '';
    if (this.query.trim()) return this.matchCount + ' 个软件包匹配「' + this.query.trim() + '」' +
      (this.matchCount > this.results.length ? '，显示前 ' + this.results.length + ' 条' : '');
    if (this.scope === 'Cask') return '浏览 Harmonybrew 在线 Cask';
    if (this.downloadStatus === 'loading') return '正在读取下载统计…';
    if (this.downloadStatus === 'error') return '暂时无法更新下载统计';
    return '按近 30 天下载量排序' + (this.downloads.days < 30 ? '（有 ' + this.downloads.days + ' 天数据）' : '');
  }

  private select(pkg: CataloguePackage): void {
    this.selected = pkg.id;
    this.showDetails = true;
  }

  private navigateResults(step: number): void {
    if (this.widthAvailable < 710 && this.showDetails) return;
    const ordered = this.results.filter((pkg: CataloguePackage) => pkg.kind === 'formula')
      .concat(this.results.filter((pkg: CataloguePackage) => pkg.kind === 'cask'));
    const current = ordered.findIndex((pkg: CataloguePackage) => pkg.id === this.active()?.id);
    const next = current + step;
    if (next < 0 || next >= ordered.length) return;
    const pkg = ordered[next];
    this.selected = pkg.id;
    const row = ordered.filter((item: CataloguePackage) => item.kind === pkg.kind).findIndex((item: CataloguePackage) =>
      item.id === pkg.id);
    this.resultScroller.scrollToItemInGroup(pkg.kind === 'cask' && this.scope === '全部' ? 1 : 0, row,
      false, ScrollAlign.AUTO);
  }

  private async openPage(url: string): Promise<void> {
    if (!/^https?:\/\//i.test(url)) return;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await context.openLink(url, { appLinkingOnly: false });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: '无法打开链接，请复制网址后重试。' });
    }
  }

  private async install(pkg: CataloguePackage): Promise<void> {
    if (this.taskRunning || this.installPhase === 'running') return;
    this.installTarget = pkg.id;
    this.installPhase = 'running';
    this.installPhase = await this.onInstall(pkg);
  }

  private catalogueStatus(status: string): boolean {
    return (this.scope !== 'Cask' && this.formulaStatus === status) ||
      (this.scope !== 'Formula' && this.caskStatus === status);
  }

  private showCatalogueSkeleton(): boolean {
    return this.results.length === 0 && this.catalogueStatus('loading');
  }

  @Builder
  CatalogueListSkeleton() {
    Column() {
      Row() {
        Rect().width(72).height(9).fill(C.borderDefault).radius(3)
      }.width('100%').height(32).padding({ left: L.md }).backgroundColor(C.surfaceRecessed)
      ForEach([0, 1, 2, 3, 4, 5], (index: number) => {
        Column({ space: L.sm }) {
          Rect().width(index % 2 === 0 ? '34%' : '26%').height(10).fill(C.borderDefault).radius(3)
          Rect().width(index % 2 === 0 ? '82%' : '69%').height(8).fill(C.surfaceRecessed).radius(3)
          Rect().width('40%').height(7).fill(C.surfaceRecessed).radius(3)
        }.width('100%').padding(L.md).alignItems(HorizontalAlign.Start)
          .border({ width: { bottom: 1 }, color: C.borderSeparator })
      }, (index: number) => String(index))
    }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Start).clip(true)
      .accessibilityLevel('no-hide-descendants').id('discover-list-skeleton')
  }

  @Builder
  CatalogueDetailsSkeleton() {
    Column({ space: L.lg }) {
      Row({ space: L.md }) {
        Rect().width(44).height(44).fill(C.surfaceRecessed).radius(L.radiusSm)
        Column({ space: L.sm }) {
          Rect().width('38%').height(15).fill(C.borderDefault).radius(3)
          Rect().width('72%').height(8).fill(C.surfaceRecessed).radius(3)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')
      Column({ space: L.md }) {
        Rect().width(52).height(10).fill(C.borderDefault).radius(3)
        ForEach([0, 1, 2, 3], (index: number) => {
          Row({ space: L.md }) {
            Rect().width(70).height(8).fill(C.surfaceRecessed).radius(3)
            Rect().width(index % 2 === 0 ? '32%' : '46%').height(8).fill(C.surfaceRecessed).radius(3)
          }.width('100%')
        }, (index: number) => String(index))
      }.width('100%').alignItems(HorizontalAlign.Start)
      Divider().color(C.borderSeparator)
      Rect().width(54).height(10).fill(C.borderDefault).radius(3)
      Rect().width('100%').height(58).fill(C.surfaceRecessed).radius(L.radiusMd)
    }.width('100%').alignItems(HorizontalAlign.Start).accessibilityLevel('no-hide-descendants')
      .id('discover-details-skeleton')
  }

  private sectionTitle(kind: CatalogueKind): string {
    const name = kind === 'formula' ? 'Formula' : 'Cask';
    return !this.query.trim() && this.downloads.days > 0 && kind === 'formula' ? '热门 ' + name : name;
  }

  @Builder
  SectionHeading(kind: CatalogueKind) {
    Text(this.sectionTitle(kind)).fontSize(F.caption).fontWeight(FontWeight.Bold).fontColor(C.textSecondary)
      .width('100%').padding({ left: L.md, top: L.sm, bottom: L.sm }).backgroundColor(C.surfaceRecessed)
  }

  @Builder
  PackageResult(pkg: CataloguePackage) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: L.xs }) {
        Row({ space: L.sm }) {
          Text(pkg.displayName).fontSize(F.body).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.installedVersion(pkg)) {
            Text('已安装').fontSize(F.caption2).fontColor(C.statusSuccess)
          }
        }.width('100%')
        Text(pkg.desc || pkg.tap).fontSize(F.callout).fontColor(C.textSecondary)
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text((pkg.version ? 'v' + pkg.version : '—') + (pkg.kind === 'formula' && this.downloads.days > 0 ?
          ' · 近 30 天下载 ' + this.downloadCount(pkg).toLocaleString() + ' 次' : ''))
          .fontSize(F.caption).fontColor(C.textTertiary)
      }.width('100%').padding(L.md).alignItems(HorizontalAlign.Start)
    }.width('100%').padding(0).borderRadius(L.radiusMd)
    .backgroundColor(this.active()?.id === pkg.id ? C.selectionFill : Color.Transparent)
    .accessibilitySelected(this.active()?.id === pkg.id)
    .id('discover-' + pkg.id).onClick(() => { this.select(pkg); })
  }

  @Builder
  CatalogueList() {
    Column({ space: L.md }) {
      SearchBox({ query: this.query, hint: '搜索 Harmonybrew 软件包', focusKey: 'discover-search' })
      Segments({ labels: ['全部', 'Formula', 'Cask'], selected: this.scope })
      Column({ space: L.xs }) {
        Text(this.query.trim() ? (this.results.length || this.showCatalogueSkeleton() || this.catalogueStatus('error') ?
          '搜索结果' : '没有搜索结果') :
          (this.scope !== 'Cask' && this.downloads.days > 0 ? '热门软件包' : '在线目录'))
          .fontSize(F.title2).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
        if (this.subtitle()) { Text(this.subtitle()).fontSize(F.callout).fontColor(C.textSecondary) }
      }.width('100%').alignItems(HorizontalAlign.Start)
        .keyboardShortcut(FunctionKey.DPAD_UP, [], () => { this.navigateResults(-1); })
      if (this.catalogueStatus('error')) {
        Text('在线目录加载失败，请刷新重试。').fontSize(F.callout).fontColor(C.textSecondary)
      }
      if (this.showCatalogueSkeleton()) {
        this.CatalogueListSkeleton()
      } else {
        this.CatalogueResults()
      }
    }.width('100%').height('100%').padding(L.lg).alignItems(HorizontalAlign.Start)
  }

  @Builder
  CatalogueResults() {
    List({ scroller: this.resultScroller }) {
      ForEach(['formula', 'cask'] as CatalogueKind[], (kind: CatalogueKind) => {
        if ((kind === 'formula' && this.scope !== 'Cask') || (kind === 'cask' && this.scope !== 'Formula')) {
          ListItemGroup({ header: this.SectionHeading(kind) }) {
            ForEach(this.results.filter((pkg: CataloguePackage) => pkg.kind === kind), (pkg: CataloguePackage) => {
              ListItem() { this.PackageResult(pkg) }
            }, (pkg: CataloguePackage) => pkg.id)
            if (kind === 'cask' && this.caskStatus === 'ready' && this.casks.length === 0) {
              ListItem() {
                Text('Harmonybrew 在线目录暂无 Cask').fontSize(F.callout).fontColor(C.textSecondary).padding(L.md)
              }
            }
          }.divider({ strokeWidth: 1, color: C.borderSeparator })
        }
      }, (kind: CatalogueKind) => kind)
    }.width('100%').layoutWeight(1)
      .keyboardShortcut(FunctionKey.DPAD_DOWN, [], () => { this.navigateResults(1); })
  }

  @Builder
  InstallSection() {
    Column({ space: L.sm }) {
      Text('安装').fontSize(F.body).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
      CommandCard({ command: 'brew install --' + this.active()!.kind + ' ' + this.active()!.fullName })
      Button(this.installTarget === this.active()!.id && this.installPhase === 'running' ? '正在安装…' : '安装',
        { type: ButtonType.Normal }).height(34).borderRadius(L.radiusSm).fontSize(F.body)
        .fontColor(Color.White).backgroundColor(C.ctaBlue)
        .enabled(!this.taskRunning && this.installPhase !== 'running').onClick(() => {
          const pkg = this.active();
          if (pkg) void this.install(pkg);
        })
      if (this.installTarget === this.active()!.id && this.installPhase === 'failed') {
        Text('安装失败，详情见控制台。').fontSize(F.callout).fontColor(C.statusError)
      } else if (this.installTarget === this.active()!.id && this.installPhase === 'cancelled') {
        Text('安装已取消。').fontSize(F.callout).fontColor(C.textSecondary)
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  CatalogueDetails() {
    Scroll() {
      Column({ space: L.lg }) {
        if (this.widthAvailable < 710) {
          Button('‹ 返回发现', { type: ButtonType.Normal }).height(28).fontSize(F.callout)
            .fontColor(C.textLink).backgroundColor(Color.Transparent).onClick(() => { this.showDetails = false; })
        }
        if (this.active()) {
          Row({ space: L.md }) {
            PackageGlyph({ name: this.active()!.name, glyphSize: 44 })
            Column({ space: L.xs }) {
              Text(this.active()!.displayName).fontSize(F.title1).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
              Row({ space: L.sm }) {
                Text(this.active()!.kind === 'formula' ? 'Formula' : 'Cask').fontSize(F.caption2)
                  .fontColor(C.selectionInk).padding(3).backgroundColor(C.selectionFill).borderRadius(4)
                if (this.installedVersion(this.active()!)) {
                  Text('已安装').fontSize(F.caption).fontColor(C.statusSuccess)
                }
              }.width('100%')
              Text(this.active()!.desc).fontSize(F.callout).fontColor(C.textSecondary)
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }.width('100%')
          Column({ space: L.xs }) {
            Text('详情').fontSize(F.body).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
            if (this.installedVersion(this.active()!)) {
              DetailLine({ label: '已安装版本', value: this.installedVersion(this.active()!) })
            }
            DetailLine({ label: '最新版本', value: this.active()!.version })
            if (this.active()!.kind === 'formula' && this.downloads.days > 0) {
              DetailLine({ label: '近 30 天下载', value: this.downloadCount(this.active()!).toLocaleString() + ' 次' +
                (this.downloads.days < 30 ? '（' + this.downloads.days + ' 天数据）' : '') })
            }
            if ((this.installedFormula(this.active()!)?.installTime ?? 0) > 0) {
              DetailLine({ label: '安装日期', value: formatDate(this.installedFormula(this.active()!)!.installTime) })
            }
            if (this.installedFormula(this.active()!) && !this.installedFormula(this.active()!)!.installedOnRequest) {
              DetailLine({ label: '安装原因', value: '作为依赖项安装' })
            }
            if (this.active()!.license) { DetailLine({ label: '许可证', value: this.active()!.license }) }
            if (this.active()!.sourceUrl) {
              DetailLink({ label: '来源', value: this.active()!.tap,
                onOpen: () => { void this.openPage(this.active()?.sourceUrl ?? ''); } })
            } else if (this.active()!.tap) {
              DetailLine({ label: '来源', value: this.active()!.tap })
            }
            if (/^https?:\/\//i.test(this.active()!.homepage)) {
              DetailLink({ label: '主页', value: this.active()!.homepage,
                onOpen: () => { void this.openPage(this.active()?.homepage ?? ''); } })
            }
          }.width('100%').alignItems(HorizontalAlign.Start)
          if (!this.installedVersion(this.active()!)) {
            Divider().color(C.borderSeparator)
            if (this.installTarget === this.active()!.id && this.installPhase === 'done') {
              Text('安装完成，正在同步已安装清单。').fontSize(F.callout).fontColor(C.statusSuccess)
            } else {
              this.InstallSection()
            }
          }
          Divider().color(C.borderSeparator)
          Column({ space: L.sm }) {
            Text('依赖项').fontSize(F.body).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
            Text(this.active()!.deps.join('、') || '无已知依赖项').fontSize(F.callout)
              .fontColor(C.textSecondary).width('100%').copyOption(CopyOptions.LocalDevice)
          }.width('100%').alignItems(HorizontalAlign.Start)
        } else if (this.showCatalogueSkeleton()) {
          this.CatalogueDetailsSkeleton()
        } else if (!this.catalogueStatus('error')) {
          Text('选择一个软件包以查看详情').fontSize(F.body).fontColor(C.textSecondary)
        }
      }.width('100%').padding(L.lg).alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').align(Alignment.TopStart)
  }

  build() {
    Column() {
      Row({ space: L.sm }) {
        Text('发现').fontSize(F.title1).fontWeight(FontWeight.Bold).fontColor(C.textPrimary).layoutWeight(1)
        Button('刷新目录', { type: ButtonType.Normal }).height(30).borderRadius(L.radiusSm)
          .fontSize(F.callout).fontColor(C.textLink).backgroundColor(C.surfaceRecessed)
          .enabled(this.formulaStatus !== 'loading' && this.caskStatus !== 'loading' && this.downloadStatus !== 'loading')
          .onClick(() => { this.refreshCatalogue(true); })
      }.width('100%').padding(L.lg)
      .border({ width: { bottom: 1 }, color: C.borderSeparator })
      .keyboardShortcut(FunctionKey.ESC, [], () => { this.selected = ''; this.showDetails = false; })
      Row() {
        if (this.widthAvailable >= 710 || !this.showDetails) {
          Column() { this.CatalogueList() }.layoutWeight(1).height('100%')
        }
        if (this.widthAvailable >= 710 || this.showDetails) {
          Column() { this.CatalogueDetails() }.layoutWeight(1).height('100%')
            .border({ width: { left: this.widthAvailable >= 710 ? 1 : 0 }, color: C.borderSeparator })
        }
      }.width('100%').layoutWeight(1)
    }.width('100%').height('100%').alignItems(HorizontalAlign.Start)
    .backgroundColor(C.surface).border({ width: 1, color: C.borderDefault, radius: L.radiusMd })
    .keyboardShortcut('f', [ModifierKey.CTRL], () => {
      this.showDetails = false;
      setTimeout(() => { this.getUIContext().getFocusController().requestFocus('discover-search'); }, 0);
    })
  }
}
