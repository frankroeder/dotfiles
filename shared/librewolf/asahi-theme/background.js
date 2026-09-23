function hex(value) {
  if (typeof value !== "string" || value.length === 0) return "#000000";
  return value.charAt(0) === "#" ? value : "#" + value;
}

function themeFrom(palette) {
  const base = hex(palette.base);
  const mantle = hex(palette.mantle);
  const surface = hex(palette.surface0);
  const surfaceAlt = hex(palette.surface1);
  const text = hex(palette.text);
  const muted = hex(palette.subtext0);
  const accent = hex(palette.accent);
  const mode = palette.mode === "light" ? "light" : "dark";
  return {
    colors: {
      frame: base,
      frame_inactive: mantle,
      toolbar: base,
      toolbar_text: text,
      toolbar_field: surface,
      toolbar_field_text: text,
      toolbar_field_border: surfaceAlt,
      toolbar_field_border_focus: accent,
      toolbar_field_focus: surfaceAlt,
      toolbar_top_separator: surfaceAlt,
      toolbar_bottom_separator: surfaceAlt,
      tab_background_text: muted,
      tab_selected: surface,
      tab_text: text,
      tab_line: accent,
      popup: mantle,
      popup_text: text,
      popup_border: surfaceAlt,
      popup_highlight: accent,
      popup_highlight_text: base,
      sidebar: base,
      sidebar_text: text,
      sidebar_border: surfaceAlt,
      sidebar_highlight: surface,
      button_background_hover: surface,
      button_background_active: surfaceAlt,
      icons: text,
      ntp_background: base,
      ntp_text: text,
    },
    properties: {
      color_scheme: mode,
      content_color_scheme: mode,
    },
  };
}

function apply(message) {
  if (!message || !message.base) return;
  browser.theme.update(themeFrom(message));
}

const port = browser.runtime.connectNative("asahi_theme");
port.onMessage.addListener(apply);
