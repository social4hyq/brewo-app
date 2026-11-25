import pasteboard from '@ohos.pasteboard';
import { C, L, F } from '../theme/Tokens';

export enum Page { Installed, Upgrades, Discover, Services, Doctor, Configuration }

interface NavItem { page: Page; title: string; icon: string; }

const NAV_ITEMS: NavItem[] = [
  { page: Page.Installed, title: '已安装', icon: '▣' },
  { page: Page.Upgrades, title: '更新看板', icon: '⇧' },
  { page: Page.Discover, title: '发现', icon: '⌕' },
  { page: Page.Services, title: '服务', icon: '▤' },
  { page: Page.Doctor, title: 'Doctor 诊断', icon: '✚' },
  { page: Page.Configuration, title: '配置', icon: '⚙' },
];

export async function copyText(text: string): Promise<void> {
  await pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text));
}

@Component
export struct Sidebar {
  @Link current: Page;
  @Prop upgradeCount: number = 0;

  build() {
    Column({ space: 5 }) {
      Row({ space: L.sm }) {
        Text('B').fontSize(17).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .width(34).height(34).textAlign(TextAlign.Center).borderRadius(9)
          .linearGradient({ angle: 135, colors: [[C.ctaBlue, 0], [C.brandGradient, 1]] })
        Column({ space: 1 }) {
          Text('Brewo').fontSize(19).fontWeight(FontWeight.Bold).fontColor(C.textPrimary)
          Text('Harmonybrew').fontSize(F.caption2).fontColor(C.textTertiary)
        }.alignItems(HorizontalAlign.Start)
      }.width('100%').padding({ left: L.xs, top: L.md, bottom: L.xl })

      ForEach(NAV_ITEMS, (item: NavItem) => {
        Row({ space: L.sm }) {
          Text(item.icon).fontSize(18).width(L.iconWidth).textAlign(TextAlign.Center)
            .fontColor(this.current === item.page ? C.selectionInk : C.textTertiary)
          Text(item.title).fontSize(F.body).fontWeight(FontWeight.Medium)
            .fontColor(this.current === item.page ? C.selectionInk : C.textSecondary)
            .layoutWeight(1)
          if (item.page === Page.Upgrades && this.upgradeCount > 0) {
            Text(this.upgradeCount.toString()).fontSize(F.caption2).fontColor(C.textPrimary)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(C.brandTint).borderRadius(6)
          }
        }.width('100%').height(42).padding({ left: L.sm, right: L.sm }).borderRadius(L.radiusMd)
        .backgroundColor(this.current === item.page ? C.selectionFill : Color.Transparent)
        .accessibilitySelected(this.current === item.page)
        .focusable(true).onClick(() => { this.current = item.page; })
      }, (item: NavItem) => item.title)
      Blank()
    }.width(L.sidebarWidth).height('100%').padding(L.md)
    .linearGradient({ angle: 180, colors: [[C.surfaceElevated, 0], [C.surface, 1]] })
    .border({ width: { right: 1 }, color: C.borderSeparator })
  }
}

function outputColor(line: string): ResourceColor {
  if (/^(✕|Error:|error:)/.test(line)) return C.codeError;
  if (/^(Warning:|警告)/.test(line)) return C.statusWarning;
  if (line.startsWith('✓')) return C.statusSuccess;
  if (/^(\$|==>|→)/.test(line)) return C.codeCommand;
  return C.codeDefault;
}

@Component
export struct ConsolePanel {
  @Prop @Watch('updateTranscript') consoleText: string = '';
  @Prop @Watch('updatePhase') phase: string = '';
  @Prop label: string = '';
  onCancel: () => void = () => {};
  @State expanded: boolean = false;
  @State follow: boolean = true;
  @State paused: boolean = false;
  @State transcript: string = '';
  @State cleared: string = '';
  @State copyLabel: string = '复制';
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void { this.updateTranscript(); }

  private updatePhase(): void {
    if (this.phase === 'running') this.expanded = true;
  }

  private updateTranscript(): void {
    if (!this.paused) {
      this.transcript = this.consoleText === this.cleared ? '' : this.consoleText;
      this.copyLabel = '复制';
    }
  }

  private status(): string {
    switch (this.phase) {
      case 'running': return '正在运行';
      case 'done': return '已完成';
      case 'failed': return '执行失败';
      case 'cancelled': return '已取消';
      default: return '就绪';
    }
  }

  build() {
    Column() {
      Row({ space: 6 }) {
        Button((this.expanded ? '⌄  ' : '⌃  ') + '控制台', { type: ButtonType.Normal })
          .fontSize(F.body).fontWeight(FontWeight.Medium).fontColor(C.textPrimary)
          .height(30).backgroundColor(Color.Transparent).onClick(() => { this.expanded = !this.expanded; })
        Circle({ width: 6, height: 6 }).fill(this.phase === 'failed' ? C.statusError :
          this.phase === 'running' || this.phase === 'done' ? C.statusSuccess : C.textTertiary)
        Text(this.status()).fontSize(F.caption).fontColor(C.textSecondary)
        Text(this.label).fontSize(F.caption).fontColor(C.textTertiary).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        if (this.phase === 'running') {
          Button('取消任务', { type: ButtonType.Normal }).consoleTool()
            .fontColor(C.statusError).backgroundColor(C.statusErrorSubtle).onClick(() => { this.onCancel(); })
        }
        if (this.expanded) {
          Button(this.copyLabel, { type: ButtonType.Normal }).consoleTool()
            .enabled(this.transcript.length > 0).onClick(() => {
              copyText(this.transcript).then(() => { this.copyLabel = '已复制'; })
                .catch(() => { this.copyLabel = '复制失败'; });
            })
          Button('清空', { type: ButtonType.Normal }).consoleTool()
            .enabled(this.transcript.length > 0)
            .onClick(() => { this.cleared = this.consoleText; this.transcript = ''; })
          Button(this.paused ? '继续显示' : '暂停显示', { type: ButtonType.Normal }).consoleTool()
            .onClick(() => { this.paused = !this.paused; this.updateTranscript(); })
          Button(this.follow ? '自动滚动 ✓' : '自动滚动', { type: ButtonType.Normal }).consoleTool()
            .onClick(() => {
              this.follow = !this.follow;
              if (this.follow) this.scroller.scrollEdge(Edge.Bottom);
            })
        }
      }.width('100%').height(40).padding({ left: L.xs, right: L.sm })

      if (this.expanded) {
        Scroll(this.scroller) {
          Column({ space: 3 }) {
            if (this.transcript.length === 0) {
              Text('暂无输出').fontSize(F.code).fontColor(C.textTertiary)
            } else {
              ForEach(this.transcript.trimEnd().split('\n').slice(-200), (line: string) => {
                Text(line).fontSize(F.code).fontFamily('monospace').fontColor(outputColor(line))
                  .width('100%').copyOption(CopyOptions.LocalDevice)
              }, (line: string, index: number) => index + ':' + line)
            }
          }.width('100%').padding(L.md).alignItems(HorizontalAlign.Start)
          .onAreaChange(() => { if (this.follow) this.scroller.scrollEdge(Edge.Bottom); })
        }.width('100%').height(148).align(Alignment.TopStart).backgroundColor(C.terminal)
      }
    }.width('100%').backgroundColor(C.surfaceElevated)
    .border({ width: 1, color: C.borderDefault, radius: L.radiusMd }).clip(true)
  }
}

@Extend(Button)
function consoleTool() {
  .fontSize(F.caption).fontColor(C.textSecondary).height(26).borderRadius(5)
  .backgroundColor(C.surfaceRecessed).padding({ left: 8, right: 8 })
}
