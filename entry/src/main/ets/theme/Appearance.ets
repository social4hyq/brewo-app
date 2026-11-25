import common from '@ohos.app.ability.common';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';
import preferences from '@ohos.data.preferences';

export enum Appearance { System = 'system', Light = 'light', Dark = 'dark' }

export const APPEARANCE_STORAGE = 'brewoAppearance';
const KEY = 'appearance';

function settings(context: common.UIAbilityContext): preferences.Preferences {
  return preferences.getPreferencesSync(context, { name: 'brewo_settings' });
}

export function loadAppearance(context: common.UIAbilityContext): Appearance {
  const value = settings(context).getSync(KEY, Appearance.System);
  if (value === Appearance.Light) return Appearance.Light;
  if (value === Appearance.Dark) return Appearance.Dark;
  return Appearance.System;
}

export function applyAppearance(context: common.UIAbilityContext, appearance: Appearance): void {
  let mode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
  if (appearance === Appearance.Light) mode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
  if (appearance === Appearance.Dark) mode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  context.getApplicationContext().setColorMode(mode);
}

export async function saveAppearance(context: common.UIAbilityContext, appearance: Appearance): Promise<void> {
  const store = settings(context);
  store.putSync(KEY, appearance);
  await store.flush();
}
