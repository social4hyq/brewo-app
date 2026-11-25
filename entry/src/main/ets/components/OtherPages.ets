// 其余页面：Services / Doctor / Configuration
import { C, L, F } from '../theme/Tokens';
import { DoctorResult, DoctorFinding, ConfigItem } from '../data/BrewRunner';
import { HarborService } from '../data/HarborIpc';
import { copyText } from './Shell';
import { Appearance } from '../theme/Appearance';
import { CommandCard, DetailLine, Segments } from './PageChrome';

function serviceStatus(status: string): string {
  if (status === 'started') return '运行中';
  if (status === 'disabled') return '已禁用';
  if (status === 'error') return '异常';
  if (status === 'stopped') return '已停止';
  return '未启动';
}

// ============ Services 页（由 Harbor HAP 托管，经回环 IPC 读真实状态）============
@Component
export struct ServicesPage {
  @Prop services: HarborService[] = [];
  @Prop loaded: boolean = false;
  @Prop widthAvailable: number = 0;
  onRefresh: () => void = () => {};
  @State selected: string = '';
  @State filter: string = '全部';
  @State showDetails: boolean = false;

  private visibleServices(): HarborService[] {
    if (this.filter === '全部') return this.services;
    return this.services.filter((service: HarborService) => this.filter === '运行中' ?
      service.status === 'started' : service.status !== 'started');
  }

  private active(): HarborService | undefined {
    const services = this.visibleServices();
    return services.find((item: HarborService) => item.name === this.selected) ?? services[0];
  }

  @Builder
  ServiceList() {
    Column({ space: L.md }) {
      CommandCard({ command: 'harbor list' })
      Segments({ labels: ['全部', '运行中', '已停止'], selected: this.filter })
      if (!this.loaded || this.visibleServices().length === 0) {
        Text(!this.loaded ? '正在连接 Harbor…' : this.services.length === 0 ? '没有可显示的服务' : '此筛选下没有服务')
          .fontSize(F.body).fontColor(C.textSecondary).padding({ top: L.md })
      }
      List() {
        ForEach(this.visibleServices(), (service: HarborService) => {
          ListItem() {
            Row({ space: L.sm }) {
              Column({ space: 4 }) {
                Text(service.name).fontSize(F.body).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                Row({ space: 6 }) {
                  Circle({ width: 6, height: 6 }).fill(service.status === 'started' ? C.statusSuccess : C.textTertiary)
                  Text(serviceStatus(service.status)).fontSize(F.caption).fontColor(C.textSecondary)
                }
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Text('›').fontSize(F.title2).fontColor(C.textTertiary)
            }.width('100%').padding(L.md).borderRadius(L.radiusMd)
            .backgroundColor(this.active()?.name === service.name ? C.selectionFill : Color.Transparent)
            .focusable(true).onClick(() => { this.selected = service.name; this.showDetails = true; })
          }
        }, (service: HarborService) => service.name)
      }.width('100%').layoutWeight(1).divider({ strokeWidth: 1, color: C.borderSeparator })
    }.width('100%').height('100%').padding(L.lg).alignItems(HorizontalAlign.Start)
  }

  @Builder
  ServiceDetails() {
    Scroll() {
      Column({ space: L.lg }) {
        if (this.widthAvailable < 710) {
          Button('‹ 返回服务', { type: ButtonType.Normal }).fontSize(F.callout).fontColor(C.textLink)
            .backgroundColor(Color.Transparent).height(28).onClick(() => { this.showDetails = false; })
        }
        if (this.active()) {
          Row({ space: L.md }) {
            Text('▤').fontSize(F.title1).fontColor(C.selectionInk).width(42).height(42)
              .textAlign(TextAlign.Center).border({ width: 1, color: C.borderDefault, radius: L.radiusMd })
            Column({ space: 4 }) {
              Text(this.active()!.name).fontSize(F.title1).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
              Text(serviceStatus(this.active()!.status)).fontSize(F.callout)
                .fontColor(this.active()!.status === 'started' ? C.statusSuccess : C.textSecondary)
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }.width('100%')
          Column({ space: L.xs }) {
            Text('详情').fontSize(F.body).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
            DetailLine({ label: '进程 ID（PID）', value: this.active()!.pid > 0 ? String(this.active()!.pid) : '—' })
            DetailLine({ label: '支持定时运行', value: this.active()!.timed ? '是' : '否' })
            DetailLine({ label: '管理方式', value: 'Harbor' })
          }.width('100%').alignItems(HorizontalAlign.Start)
          Divider().color(C.borderSeparator)
          Column({ space: L.xs }) {
            Text('文件').fontSize(F.body).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
            DetailLine({ label: '服务定义', value: this.active()!.unit })
            DetailLine({ label: '输出日志', value: this.active()!.log })
          }.width('100%').alignItems(HorizontalAlign.Start)
        } else {
          Text('选择一个服务以查看详情').fontSize(F.body).fontColor(C.textSecondary)
        }
      }.width('100%').padding(L.lg).alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').align(Alignment.TopStart)
  }

  build() {
    Column({ space: 0 }) {
      Column({ space: 4 }) {
        Row() {
          Column() {
            Text('服务').fontSize(F.title1).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
            Text(this.loaded ? this.services.filter((s: HarborService) => s.status === 'started').length + ' 个服务正在运行' :
              '查看由 Harbor 托管的服务').fontSize(F.caption).fontColor(C.textSecondary)
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Button('刷新', { type: ButtonType.Normal }).fontSize(F.callout).fontColor(C.textLink)
            .backgroundColor(C.surfaceRecessed).borderRadius(L.radiusSm).height(30)
            .enabled(this.loaded).onClick(() => { this.onRefresh(); })
        }.width('100%')
      }.width('100%').padding({ left: L.lg, right: L.lg, top: L.md, bottom: L.md })
       .backgroundColor(C.surface).border({ width: { bottom: 1 }, color: C.borderSeparator })
      Row({ space: 0 }) {
        if (this.widthAvailable >= 710 || !this.showDetails) {
          Column() { this.ServiceList() }.layoutWeight(1).height('100%')
        }
        if (this.widthAvailable >= 710 || this.showDetails) {
          Column() { this.ServiceDetails() }.layoutWeight(1).height('100%')
            .border({ width: { left: this.widthAvailable >= 710 ? 1 : 0 }, color: C.borderSeparator })
        }
      }.width('100%').layoutWeight(1)
    }.width('100%').height('100%').backgroundColor(C.surface)
    .border({ width: 1, color: C.borderDefault, radius: L.radiusMd }).clip(true)
  }
}

// ============ Doctor 页（实时 brew doctor --json）============
function tierLabel(tier: number): string { return tier >= 2 ? '严重' : tier === 1 ? '警告' : '提示'; }
function tierColor(tier: number): ResourceColor { return tier >= 2 ? C.statusError : tier === 1 ? C.statusWarning : C.statusInfo; }

@Component
export struct DoctorPage {
  @Prop result: DoctorResult = { tier: 0, findings: [] };
  @Prop loaded: boolean = false;
  @Prop valid: boolean = false;
  @Prop rawOutput: string = '';
  @Prop compact: boolean = false;
  @Prop widthAvailable: number = 0;
  onRunAgain: () => void = () => {};
  @State copyLabel: string = '复制输出';
  @State selectedFinding: string = '';
  @State detailCopyLabel: string = '复制详情';

  private findings(): DoctorFinding[] {
    return this.result.findings.slice().sort((a: DoctorFinding, b: DoctorFinding) => b.tier - a.tier);
  }

  private currentFinding(): DoctorFinding | undefined {
    const findings = this.findings();
    return findings.find((finding: DoctorFinding) => finding.text === this.selectedFinding) ?? findings[0];
  }

  @Builder
  SplitFindings() {
    Row() {
      List() {
        ForEach(this.findings(), (finding: DoctorFinding, index: number) => {
          ListItem() {
            Column({ space: L.xs }) {
              Text(tierLabel(finding.tier)).fontSize(F.caption).fontColor(tierColor(finding.tier))
              Text(finding.text.trim().split('\n')[0]).fontSize(F.body).fontWeight(FontWeight.Medium)
                .fontColor(C.textPrimary).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            }.width('100%').padding(L.md).alignItems(HorizontalAlign.Start).borderRadius(L.radiusMd)
            .backgroundColor(this.currentFinding()?.text === finding.text ? C.selectionFill : Color.Transparent)
            .focusable(true).onClick(() => { this.selectedFinding = finding.text; this.detailCopyLabel = '复制详情'; })
          }
        }, (finding: DoctorFinding, index: number) => index + ':' + finding.text)
      }.layoutWeight(1).height('100%').padding({ right: L.md })
      .divider({ strokeWidth: 1, color: C.borderSeparator })

      Scroll() {
        Column({ space: L.md }) {
          if (this.currentFinding()) {
            Row({ space: L.sm }) {
              Text(tierLabel(this.currentFinding()!.tier)).fontSize(F.caption).fontWeight(FontWeight.Bold)
                .fontColor(tierColor(this.currentFinding()!.tier)).padding(L.xs)
              Blank()
              Button(this.detailCopyLabel, { type: ButtonType.Normal }).height(28).borderRadius(L.radiusSm)
                .fontSize(F.callout).fontColor(C.textLink).backgroundColor(C.surfaceRecessed).onClick(() => {
                  copyText(this.currentFinding()!.text).then(() => { this.detailCopyLabel = '已复制'; })
                    .catch(() => { this.detailCopyLabel = '复制失败'; });
                })
            }.width('100%')
            Text(this.currentFinding()!.text.trim().split('\n')[0]).fontSize(F.title2).fontWeight(FontWeight.Bold)
              .fontColor(C.textPrimary).width('100%')
            if (this.currentFinding()!.text.trim().includes('\n')) {
              Text(this.currentFinding()!.text.trim().split('\n').slice(1).join('\n').trim())
                .fontSize(F.body).fontColor(C.textSecondary).width('100%').copyOption(CopyOptions.LocalDevice)
            }
            if (this.currentFinding()!.affects.length > 0) {
              DetailLine({ label: '涉及软件包', value: this.currentFinding()!.affects.join('、') })
            }
          }
        }.width('100%').padding({ left: L.lg, right: L.xs, top: L.xs, bottom: L.md })
        .alignItems(HorizontalAlign.Start)
      }.layoutWeight(1.1).height('100%').align(Alignment.TopStart)
      .border({ width: { left: 1 }, color: C.borderSeparator })
    }.width('100%').layoutWeight(1)
  }

  build() {
    Column({ space: L.md }) {
      Row({ space: L.sm }) {
        Column({ space: 4 }) {
          Text('Doctor 诊断').fontSize(this.compact ? F.title1 : F.largeTitle).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
          Text(this.loaded ? (this.valid ? '本次检查报告了 ' + this.result.findings.length + ' 项发现' : '诊断输出不可用') :
            '正在检查 Harmonybrew 环境…').fontSize(F.callout).fontColor(C.textSecondary)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Button(this.copyLabel, { type: ButtonType.Normal }).height(32).borderRadius(6)
          .fontSize(F.callout).fontColor(C.textLink).backgroundColor(C.brandTint)
          .enabled(this.loaded && this.rawOutput.length > 0).onClick(() => {
            copyText(this.rawOutput).then(() => { this.copyLabel = '已复制'; })
              .catch(() => { this.copyLabel = '复制失败'; });
          })
        Button('运行诊断', { type: ButtonType.Normal }).height(32).borderRadius(6)
          .fontSize(F.callout).fontColor(Color.White).backgroundColor(C.ctaBlue)
          .enabled(this.loaded).onClick(() => { this.copyLabel = '复制输出'; this.onRunAgain(); })
      }.width('100%')

      if (this.loaded && this.valid && this.result.findings.length === 0) {
        Column({ space: L.sm }) {
          Text('✓').fontSize(34).fontColor(C.statusSuccess)
          Text('未发现问题').fontSize(F.title2).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.loaded && this.valid && !this.compact && this.widthAvailable >= 710) {
        this.SplitFindings()
      } else if (this.loaded) {
        Scroll() {
          Column({ space: L.md }) {
            if (!this.valid) {
              Text(this.rawOutput || '未收到诊断结果，请重新运行诊断。')
                .fontSize(F.body).fontColor(C.statusWarning).width('100%').copyOption(CopyOptions.LocalDevice)
            }
            ForEach(this.findings(), (finding: DoctorFinding) => {
              Column({ space: L.sm }) {
                Text(tierLabel(finding.tier)).fontSize(F.caption).fontWeight(FontWeight.Bold)
                  .fontColor(tierColor(finding.tier)).padding({ left: L.sm, right: L.sm, top: 4, bottom: 4 })
                  .backgroundColor(finding.tier >= 2 ? C.statusErrorSubtle : finding.tier === 1 ? C.statusWarningSubtle : C.brandTint)
                  .borderRadius(5)
                Text(finding.text.trim()).fontSize(this.compact ? F.callout : F.body).fontColor(C.textPrimary)
                  .width('100%').copyOption(CopyOptions.LocalDevice)
                if (finding.affects.length > 0) {
                  Text('涉及 ' + finding.affects.join('、')).fontSize(F.callout).fontColor(C.textSecondary)
                    .width('100%').copyOption(CopyOptions.LocalDevice)
                }
              }.width('100%').padding(L.md).alignItems(HorizontalAlign.Start)
              .backgroundColor(C.surfaceElevated)
              .border({ width: { left: 3 }, color: tierColor(finding.tier), radius: L.radiusMd })
            }, (finding: DoctorFinding, index: number) => index + ':' + finding.text)
          }.width('100%').alignItems(HorizontalAlign.Start)
        }.width('100%').layoutWeight(1).align(Alignment.TopStart)
      }
    }.width('100%').height('100%').padding(L.lg).backgroundColor(C.surface)
    .border({ width: 1, color: C.borderDefault, radius: L.radiusMd })
  }
}

// ============ Configuration 页（实时 brew config）============
@Component
export struct ConfigurationPage {
  @Prop config: ConfigItem[] = [];
  @Prop loaded: boolean = false;
  @Prop appearance: Appearance = Appearance.System;
  @Prop appearanceMessage: string = '';
  @Prop appearanceSaving: boolean = false;
  @Prop taskRunning: boolean = false;
  @State trustTarget: string = '';
  @State reportCopyLabel: string = '复制报告';
  onAppearance: (value: Appearance) => void = () => {};
  onTrust: (target: string, grant: boolean) => void = () => {};
  onRefresh: () => void = () => {};

  private validTrustTarget(): boolean {
    return /^[A-Za-z0-9][A-Za-z0-9+_.@-]*(\/[A-Za-z0-9][A-Za-z0-9+_.@-]*){1,2}$/.test(this.trustTarget.trim());
  }

  private confirmTrust(grant: boolean): void {
    const target = this.trustTarget.trim();
    if (!this.validTrustTarget()) return;
    this.getUIContext().showAlertDialog({
      title: (grant ? '信任 ' : '撤销信任 ') + target + '？',
      message: grant ? 'Harmonybrew 将允许加载此来源的代码。请先核对来源。此选择适用于 Harbor 托管的 Brewo。' :
        '撤销后，Brewo 将按 Harmonybrew 的信任规则重新检查这个来源。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: grant ? '确认信任' : '撤销信任', action: () => { this.onTrust(target, grant); } }
    });
  }

  private appearanceLabel(value: Appearance): string {
    if (value === Appearance.Light) return '浅色';
    if (value === Appearance.Dark) return '深色';
    return '跟随系统';
  }

  private isBrewSetting(item: ConfigItem): boolean {
    return /^(HOMEBREW_|Homebrew |ORIGIN$|HEAD$|Last commit$|Branch$|Core )/.test(item.key);
  }

  @Builder
  ConfigGroup(title: string, brewSettings: boolean) {
    Column({ space: L.xs }) {
      Text(title).fontSize(F.title3).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
        .margin({ bottom: L.xs })
      ForEach(this.config.filter((item: ConfigItem) => this.isBrewSetting(item) === brewSettings), (item: ConfigItem) => {
        DetailLine({ label: item.key, value: item.value })
      }, (item: ConfigItem, index: number) => item.key + String(index))
    }.width('100%').padding(L.md).alignItems(HorizontalAlign.Start).backgroundColor(C.surface)
    .border({ width: 1, color: C.borderDefault, radius: L.radiusMd })
  }

  build() {
    Column({ space: 0 }) {
      Row({ space: L.sm }) {
        Column({ space: 4 }) {
          Text('配置').fontSize(F.title1).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
          Text('Harmonybrew 环境与诊断信息').fontSize(F.caption).fontColor(C.textSecondary)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Button(this.reportCopyLabel, { type: ButtonType.Normal }).height(30).borderRadius(L.radiusSm)
          .fontSize(F.callout).fontColor(C.textLink).backgroundColor(C.surfaceRecessed)
          .enabled(this.loaded && this.config.length > 0).onClick(() => {
            copyText(this.config.map((item: ConfigItem) => item.key + ': ' + item.value).join('\n'))
              .then(() => { this.reportCopyLabel = '已复制'; }).catch(() => { this.reportCopyLabel = '复制失败'; });
          })
        Button('刷新', { type: ButtonType.Normal }).height(30).borderRadius(L.radiusSm)
          .fontSize(F.callout).fontColor(C.textLink).backgroundColor(C.surfaceRecessed)
          .onClick(() => { this.reportCopyLabel = '复制报告'; this.onRefresh(); })
      }.width('100%').padding({ left: L.lg, right: L.lg, top: L.md, bottom: L.md })
       .backgroundColor(C.surface).border({ width: { bottom: 1 }, color: C.borderSeparator })
      Scroll() {
        Column({ space: L.sm }) {
          Text('Brewo 通过 Harbor 运行 Harmonybrew。这里的报告与 Tap 信任均来自 Harbor 的运行环境。')
            .fontSize(F.callout).fontColor(C.textLink).padding(L.md).width('100%')
            .backgroundColor(C.brandTint).borderRadius(L.radiusMd)
          Column({ space: L.sm }) {
            Text('外观').fontSize(F.title2).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
            Row({ space: L.xs }) {
              ForEach([Appearance.System, Appearance.Light, Appearance.Dark], (value: Appearance) => {
                Button(this.appearanceLabel(value), { type: ButtonType.Normal }).height(32).borderRadius(L.radiusSm)
                  .fontSize(F.body).fontColor(this.appearance === value ? Color.White : C.textSecondary)
                  .backgroundColor(this.appearance === value ? C.ctaBlue : Color.Transparent)
                  .accessibilitySelected(this.appearance === value).enabled(!this.appearanceSaving)
                  .onClick(() => { this.onAppearance(value); })
              }, (value: Appearance) => value)
            }.padding(L.xs).backgroundColor(C.surfaceRecessed).borderRadius(L.radiusMd)
            if (this.appearanceMessage.length > 0) {
              Text(this.appearanceMessage).fontSize(F.callout).fontColor(C.statusWarning)
            }
          }.width('100%').padding(L.md).alignItems(HorizontalAlign.Start)
          .backgroundColor(C.surface).border({ width: 1, color: C.borderDefault, radius: L.radiusMd })
          Column({ space: L.sm }) {
            Text('Tap 信任').fontSize(F.title2).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
            Text('配置 Harbor 执行端的信任。可指定整个 tap 或单个 formula。')
              .fontSize(F.callout).fontColor(C.textSecondary)
            Row({ space: L.sm }) {
              TextInput({ text: this.trustTarget, placeholder: '用户/tap[/formula]' })
                .layoutWeight(1).height(34).fontSize(F.body).fontColor(C.textPrimary)
                .placeholderColor(C.textTertiary).backgroundColor(C.surfaceRecessed)
                .onChange((value: string) => { this.trustTarget = value; })
              Button('信任', { type: ButtonType.Normal }).height(32).borderRadius(L.radiusSm)
                .fontSize(F.body).fontColor(Color.White).backgroundColor(C.ctaBlue)
                .enabled(this.validTrustTarget() && !this.taskRunning).onClick(() => { this.confirmTrust(true); })
              Button('撤销信任', { type: ButtonType.Normal }).height(32).borderRadius(L.radiusSm)
                .fontSize(F.body).fontColor(C.textLink).backgroundColor(C.brandTint)
                .enabled(this.validTrustTarget() && !this.taskRunning).onClick(() => { this.confirmTrust(false); })
            }.width('100%')
          }.width('100%').padding(L.md).alignItems(HorizontalAlign.Start)
          .backgroundColor(C.surface).border({ width: 1, color: C.borderDefault, radius: L.radiusMd })
          if (!this.loaded) {
            Text('正在读取 brew config…').fontSize(F.callout).fontColor(C.textTertiary)
          } else if (this.config.length === 0) {
            Text('未收到 Harmonybrew 环境报告').fontSize(F.callout).fontColor(C.textSecondary)
          } else {
            this.ConfigGroup('Harmonybrew', true)
            this.ConfigGroup('系统', false)
          }
        }.width('100%').padding({ left: L.xl, right: L.xl, top: L.sm, bottom: L.lg })
      }.layoutWeight(1).height('100%').backgroundColor(C.surfaceElevated)
    }.width('100%').height('100%').backgroundColor(C.surfaceElevated)
    .border({ width: 1, color: C.borderDefault, radius: L.radiusMd }).clip(true)
  }
}
