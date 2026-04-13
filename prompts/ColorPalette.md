theme:
  ratio:
    primary: "60%"     # Dominant UI color
    secondary: "30%"   # Supporting surfaces
    accent: "10%"      # Highlights / subtle areas

  primary:
    base: "#066FD1"        # 60% - Main brand color
    pressed: "#055CB0"
    disabled: "#A9CBEF"
    contrastText: "#FFFFFF"

  secondary:
    base: "#90CAF9"        # 30% - Supporting color
    pressed: "#74B6F2"
    disabled: "#D6EAFB"
    contrastText: "#0F172A"

  accent:
    base: "#E6F0FA"        # 10% - Background highlights

  background:
    base: "#FFFFFF"
    surface: "#F9FAFB"
    surfaceAlt: "#F3F6F9"

  border:
    default: "#E5E8EC"
    muted: "#EEF1F4"
    focus: "#066FD1"
    error: "#D63939"

  text:
    primary: "#333333"
    secondary: "#6B7280"
    muted: "#999999"
    inverse: "#FFFFFF"
    placeholder: "#B0B7C3"
    disabled: "#C7CDD6"
    link: "#066FD1"

  icon:
    primary: "#333333"
    secondary: "#6B7280"
    muted: "#999999"
    inverse: "#FFFFFF"
    disabled: "#C7CDD6"

components:
  badge:
    primary:
      background: "#E6F0FA"   # accent usage (10%)
      text: "#066FD1"

    secondary:
      background: "#F9FAFB"
      text: "#6B7280"

    success:
      background: "#E6F6F1"
      text: "#0CA678"

    warning:
      background: "#FEF5E5"
      text: "#F59F00"

    danger:
      background: "#FBEBEB"
      text: "#D63939"

    dark:
      background: "#E8E9EB"
      text: "#1F2937"

  button:
    primary:
      background: "#066FD1"        # 60% usage
      text: "#FFFFFF"
      pressed: "#055CB0"
      disabledBackground: "#A9CBEF"
      disabledText: "#FFFFFF"

    secondary:
      background: "#E6F0FA"        # 10% usage (soft button)
      text: "#066FD1"
      pressed: "#D7E8F8"
      disabledBackground: "#EEF4FA"
      disabledText: "#9BB8D4"

  input:
    background: "#FFFFFF"
    text: "#333333"
    placeholder: "#B0B7C3"
    border: "#E5E8EC"
    focusBorder: "#066FD1"        # primary interaction
    errorBorder: "#D63939"
    disabledBackground: "#F3F6F9"
    disabledText: "#999999"

  card:
    background: "#F9FAFB"         # secondary usage (30%)
    border: "#E5E8EC"

  divider:
    color: "#EEF1F4"

status:
  success:
    base: "#0CA678"
    background: "#E6F6F1"
    text: "#0CA678"

  warning:
    base: "#F59F00"
    background: "#FEF5E5"
    text: "#F59F00"

  danger:
    base: "#D63939"
    background: "#FBEBEB"
    text: "#D63939"

  info:
    base: "#066FD1"               # aligned with primary
    background: "#E6F0FA"
    text: "#066FD1"

effects:
  focusRing: "#066FD1"
  overlay: "#0f172a14"