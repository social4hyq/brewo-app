// ArkUI resolves these colors from the active light or dark resource group.

export class C {
  static readonly windowBase: Resource = $r('app.color.window_base');
  static readonly surface: Resource = $r('app.color.surface');
  static readonly surfaceElevated: Resource = $r('app.color.surface_elevated');
  static readonly surfaceRecessed: Resource = $r('app.color.surface_recessed');
  static readonly terminal: Resource = $r('app.color.terminal');

  static readonly textPrimary: Resource = $r('app.color.text_primary');
  static readonly textSecondary: Resource = $r('app.color.text_secondary');
  static readonly textTertiary: Resource = $r('app.color.text_tertiary');
  static readonly textLink: Resource = $r('app.color.text_link');
  static readonly textBrand: Resource = $r('app.color.text_brand');
  static readonly codeDefault: Resource = $r('app.color.code_default');
  static readonly codeCommand: Resource = $r('app.color.code_command');
  static readonly codeError: Resource = $r('app.color.code_error');

  static readonly brandPrimary: Resource = $r('app.color.brand_primary');
  static readonly brandTint: Resource = $r('app.color.brand_tint');
  static readonly selectionFill: Resource = $r('app.color.selection_fill');
  static readonly selectionInk: Resource = $r('app.color.selection_ink');
  static readonly ctaBlue: Resource = $r('app.color.cta_blue');
  static readonly brandGradient: Resource = $r('app.color.brand_gradient');
  static readonly caskBlue: Resource = $r('app.color.accent_violet');
  static readonly outdated: Resource = $r('app.color.status_warning');

  static readonly statusSuccess: Resource = $r('app.color.status_success');
  static readonly statusSuccessSubtle: Resource = $r('app.color.status_success_subtle');
  static readonly statusWarning: Resource = $r('app.color.status_warning');
  static readonly statusWarningSubtle: Resource = $r('app.color.status_warning_subtle');
  static readonly statusError: Resource = $r('app.color.status_error');
  static readonly statusErrorSubtle: Resource = $r('app.color.status_error_subtle');
  static readonly statusInfo: Resource = $r('app.color.text_link');

  static readonly borderDefault: Resource = $r('app.color.border_default');
  static readonly borderSeparator: Resource = $r('app.color.border_separator');
}

// Layout（对齐 BrewSpacing / BrewLayout，单位 vp≈pt）
export class L {
  static readonly xxs: number = 2;
  static readonly xs: number = 4;
  static readonly sm: number = 8;
  static readonly md: number = 12;
  static readonly lg: number = 16;
  static readonly xl: number = 24;
  static readonly xxl: number = 32;

  static readonly sidebarWidth: number = 166;
  static readonly iconWidth: number = 20;
  static readonly inspectorWidth: number = 360;
  static readonly radiusMd: number = 10;
  static readonly radiusSm: number = 6;
}

// 字体层级（对齐 BrewFonts）
export class F {
  static readonly largeTitle: number = 28;
  static readonly title1: number = 22;
  static readonly title2: number = 17;
  static readonly title3: number = 15;
  static readonly body: number = 13;
  static readonly bodyEmphasized: number = 13;
  static readonly callout: number = 12;
  static readonly subheadline: number = 11;
  static readonly caption: number = 11;
  static readonly caption2: number = 10;
  static readonly code: number = 12;
  static readonly codeSmall: number = 11;
}
