#!/bin/bash
# ROX-Filer: Send to desktop — pp4mnk 2026 4 EasyOS
# Run without arguments to install. ROX passes selected paths as arguments.
set -u
notify() {
 if command -v Xdialog >/dev/null 2>&1; then Xdialog --title 'Send to desktop' --msgbox "$1" 0 0
 elif command -v yad >/dev/null 2>&1; then yad --info --title='Send to desktop' --text="$1" --width=460
 else printf '%s\n' "$1"; fi
}
if ! command -v rox >/dev/null 2>&1; then
 notify 'ROX-Filer (rox) is required.'; exit 1
fi
if [[ $# -eq 0 ]]; then
 tool="$HOME/.local/bin/pp4mnk-rox-send-to-desktop"
 config="${XDG_CONFIG_HOME:-$HOME/.config}/rox.sourceforge.net/SendTo"
 mkdir -p "${tool%/*}" || exit 1
 source_file=$(readlink -f -- "$0") || exit 1
 [[ "$source_file" == "$tool" ]] || cp -- "$source_file" "$tool" || exit 1
 chmod 755 "$tool" || exit 1
 for mime in application_x-desktop application_x-executable application_x-pie-executable application_x-shellscript text_x-shellscript; do
  directory="$config/.$mime"
  mkdir -p -- "$directory" || exit 1
  entry="$directory/Send to desktop"
  if [[ -e "$entry" || -L "$entry" ]]; then
   if [[ ! -L "$entry" || $(readlink -- "$entry") != "$tool" ]]; then
    notify "An existing action was preserved: $entry"; exit 1
   fi
  else
   ln -s -- "$tool" "$entry" || exit 1
  fi
 done
 notify 'Installed. Right-click an application .desktop file in /usr/share/applications and choose Send to desktop. Depending on your ROX menu settings, look under File. You can also use Shift + right-click. Close and reopen the menu if necessary.'
 exit 0
fi
# Pin the original launcher: no copy, no modification of its Exec command.
# Removing its desktop icon later does not remove the original file.
xml_escape() {
 printf '%s' "$1" | sed 's/\&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g;s/"/\&quot;/g'
}
failed=0
for selected in "$@"; do
 path=$(readlink -f -- "$selected") || { failed=1; continue; }
 if [[ ! -f "$path" ]]; then notify "Not a regular file: $selected"; failed=1; continue; fi
 if [[ "$path" != *.desktop && ! -x "$path" ]]; then
  notify "Select an application .desktop file or an executable program: $selected"
  failed=1; continue
 fi
 label=$(basename -- "$path")
 if [[ "$path" == *.desktop ]]; then
  name=$(awk '/^\[Desktop Entry\]/{section=1;next} /^\[/{section=0} section && /^Name=/{sub(/^Name=/, "");sub(/\r$/, "");print;exit}' "$path")
  [[ -z "$name" ]] || label="$name"
 fi
 escaped_path=$(xml_escape "$path")
 escaped_label=$(xml_escape "$label")
 # Negative coordinates let modern ROX choose a free position on the pinboard.
 reply=$(rox -R <<EOF
<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2001/12/soap-envelope">
 <env:Body xmlns="http://rox.sourceforge.net/SOAP/ROX-Filer">
  <PinboardAdd><Path>$escaped_path</Path><X>-1</X><Y>-1</Y><Label>$escaped_label</Label></PinboardAdd>
 </env:Body>
</env:Envelope>
EOF
 )
 status=$?
 if [[ $status -ne 0 || "$reply" == *Fault* || "$reply" == *fault* ]]; then
  notify "ROX could not add the icon. Check that its desktop pinboard is active. $reply"
  failed=1
 fi
done
exit "$failed"
