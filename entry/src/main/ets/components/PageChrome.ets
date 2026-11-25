import { C, F, L } from '../theme/Tokens';
import { copyText } from './Shell';

@Component
export struct Segments {
  @Prop labels: string[] = [];
  @Link selected: string;

  build() {
    Row({ space: 2 }) {
      ForEach(this.labels, (label: string) => {
        Button(label, { type: ButtonType.Normal }).height(28).borderRadius(L.radiusSm)
          .padding({ left: L.sm, right: L.sm }).fontSize(F.callout)
          .fontColor(this.selected === label ? Color.White : C.textSecondary)
          .backgroundColor(this.selected === label ? C.ctaBlue : Color.Transparent)
          .accessibilitySelected(this.selected === label).onClick(() => { this.selected = label; })
      }, (label: string) => label)
    }.padding(3).backgroundColor(C.surfaceRecessed).borderRadius(L.radiusMd)
  }
}

@Component
export struct CommandCard {
  @Prop @Watch('resetCopyLabel') command: string = '';
  @Prop caption: string = '终端命令';
  @State copyLabel: string = '复制';

  private resetCopyLabel(): void { this.copyLabel = '复制'; }

  build() {
    Column() {
      Row({ space: L.sm }) {
        Text('›_').fontFamily('monospace').fontSize(F.callout).fontColor(C.textTertiary)
        Text(this.caption).fontSize(F.caption).fontWeight(FontWeight.Medium)
          .fontColor(C.textSecondary).layoutWeight(1)
        Button(this.copyLabel, { type: ButtonType.Normal }).height(24).borderRadius(L.radiusSm)
          .fontSize(F.caption).fontColor(C.textLink).backgroundColor(Color.Transparent).onClick(() => {
            copyText(this.command).then(() => { this.copyLabel = '已复制'; })
              .catch(() => { this.copyLabel = '复制失败'; });
          })
      }.width('100%').padding({ left: L.md, right: L.xs, top: 3, bottom: 3 })
      .backgroundColor(C.surfaceRecessed)
      Text(this.command).fontSize(F.code).fontColor(C.textPrimary).fontFamily('monospace')
        .width('100%').padding(L.md).copyOption(CopyOptions.LocalDevice)
    }.width('100%').border({ width: 1, color: C.borderSeparator, radius: L.radiusMd }).clip(true)
  }
}

@Component
export struct DetailLink {
  @Prop label: string = '';
  @Prop value: string = '';
  onOpen: () => void = () => {};

  build() {
    Row({ space: L.md }) {
      Text(this.label).width(96).fontSize(F.callout).fontColor(C.textSecondary)
      Text(this.value).layoutWeight(1).fontSize(F.callout).fontColor(C.textLink).copyOption(CopyOptions.LocalDevice)
      Button('打开', { type: ButtonType.Normal }).height(28).fontSize(F.caption)
        .fontColor(C.textLink).backgroundColor(C.surfaceRecessed).borderRadius(L.radiusSm)
        .accessibilityText('打开' + this.label).onClick(() => { this.onOpen(); })
    }.width('100%')
  }
}

@Component
export struct DetailLine {
  @Prop label: string = '';
  @Prop value: string = '';

  build() {
    Row({ space: L.md }) {
      Text(this.label).width(96).fontSize(F.callout).fontColor(C.textSecondary)
      Text(this.value || '—').layoutWeight(1).fontSize(F.callout).fontColor(C.textPrimary)
        .copyOption(CopyOptions.LocalDevice)
    }.width('100%').padding({ top: 4, bottom: 4 }).alignItems(VerticalAlign.Top)
  }
}
