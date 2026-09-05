#!/usr/bin/env bash
# Keybindings Cheatsheet Modal (Replicates Image 2 aesthetic)

THEME_FILE="$HOME/.config/rofi/cheatsheet.rasi"
[ -f "$THEME_FILE" ] || THEME_FILE="$(dirname "$0")/cheatsheet.rasi"

ROFI_BIN="$(command -v rofi || echo "$HOME/.local/bin/rofi")"

CONTENT='<span foreground="#cba6f7"><b>██████╗ ██╗  ██╗██╗████████╗████████╗███████╗██████╗ </b></span>
<span foreground="#cba6f7"><b>██╔══██╗██║  ██║██║╚══██╔══╝╚══██╔══╝██╔════╝██╔══██╗</b></span>
<span foreground="#cba6f7"><b>██████╔╝███████║██║   ██║      ██║   █████╗  ██████╔╝</b></span>
<span foreground="#cba6f7"><b>██╔═══╝ ██╔══██║██║   ██║      ██║   ██╔══╝  ██╔══██╗</b></span>
<span foreground="#cba6f7"><b>██║     ██║  ██║██║   ██║      ██║   ███████╗██║  ██║</b></span>
<span foreground="#cba6f7"><b>╚═╝     ╚═╝  ╚═╝╚═╝   ╚═╝      ╚═╝   ╚══════╝╚═╝  ╚═╝</b></span>

<span foreground="#6c7086">Press ESC or F1 to close this window</span>

<span background="#a6e3a1" foreground="#11111b"><b>  BASIC SYSTEM  </b></span>              <span background="#fab387" foreground="#11111b"><b>  WINDOW CONTROLS  </b></span>           <span background="#f38ba8" foreground="#11111b"><b>  AUDIO & MEDIA  </b></span>             <span background="#89dceb" foreground="#11111b"><b>  POWER / SESSION  </b></span>
Terminal            <span foreground="#b4befe">Super+Enter</span>   Close Window        <span foreground="#b4befe">Super+Q</span>       Volume Up        <span foreground="#b4befe">VolUp</span>        Lock Screen         <span foreground="#b4befe">Super+L</span>
App Launcher        <span foreground="#b4befe">Super+Space</span>   Maximize            <span foreground="#b4befe">Super+Up</span>      Volume Down      <span foreground="#b4befe">VolDown</span>      Logout              <span foreground="#b4befe">Super+Shift+E</span>
File Manager        <span foreground="#b4befe">Super+E</span>       Minimize            <span foreground="#b4befe">Super+Down</span>    Mute Volume      <span foreground="#b4befe">Mute</span>         Reboot              <span foreground="#b4befe">kreboot</span>
Web Browser         <span foreground="#b4befe">Super+B</span>       Tile Left           <span foreground="#b4befe">Super+Left</span>    Play / Pause     <span foreground="#b4befe">MediaPlay</span>    Shutdown            <span foreground="#b4befe">poweroff</span>
Code Editor         <span foreground="#b4befe">Super+C</span>       Tile Right          <span foreground="#b4befe">Super+Right</span>   Next Track       <span foreground="#b4befe">MediaNext</span>    Restart Plasma      <span foreground="#b4befe">kstart5</span>
Screenshot          <span foreground="#b4befe">Super+Shift+S</span> Fullscreen          <span foreground="#b4befe">F11</span>           Prev Track       <span foreground="#b4befe">MediaPrev</span>    Equalizer           <span foreground="#b4befe">EasyEffects</span>
Task Switcher       <span foreground="#b4befe">Alt+Tab</span>       Switch Desktop      <span foreground="#b4befe">Super+1..4</span>    System Monitor   <span foreground="#b4befe">btop</span>         Fastfetch           <span foreground="#b4befe">fastfetch</span>
'

"$ROFI_BIN" -markup -theme "$THEME_FILE" -e "$CONTENT"
