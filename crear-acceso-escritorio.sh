#!/bin/bash
# Crear acceso al escritorio — pp4mnk 2026 4 EasyOS
# Primera ejecución: instala la herramienta y su entrada de menú.
set -u
TITLE='Enviar programa al escritorio'
msg() {
 if command -v yad >/dev/null; then yad --info --title="$TITLE" --text="$1" --width=440
 elif command -v Xdialog >/dev/null; then Xdialog --title "$TITLE" --msgbox "$1" 0 0
 elif command -v zenity >/dev/null; then zenity --info --text="$1"
 else printf '%s\n' "$1"; fi
}
if [[ ${1:-} != --run ]]; then
 target="$HOME/.local/bin/pp4mnk-acceso-escritorio"
 menu="$HOME/.local/share/applications/pp4mnk-acceso-escritorio.desktop"
 mkdir -p "${target%/*}" "${menu%/*}" || exit 1
 source_file=$(readlink -f -- "$0") || exit 1
 if [[ "$source_file" != "$target" ]]; then cp -- "$source_file" "$target" || exit 1; fi
 chmod 755 "$target" || exit 1
 # Escapar la ruta conforme a la sintaxis Exec de los lanzadores.
 execpath=${target//\\/\\\\}; execpath=${execpath//\"/\\\"}
 execpath=${execpath//\$/\\\$}; execpath=${execpath//\`/\\\`}
 cat > "$menu" <<EOF
[Desktop Entry]
Type=Application
Name=Enviar programa al escritorio
Comment=Elegir un lanzador y añadirlo al escritorio
Exec="$execpath" --run
Icon=user-desktop
Terminal=false
Categories=Utility;
EOF
 command -v update-desktop-database >/dev/null && update-desktop-database "${menu%/*}" >/dev/null 2>&1
 command -v fixmenus >/dev/null && fixmenus >/dev/null 2>&1
 if command -v jwm >/dev/null && pidof jwm >/dev/null; then jwm -reload >/dev/null 2>&1; fi
 msg 'Instalado. Busca «Enviar programa al escritorio» en el menú, dentro de Utilidades. Si no aparece, reinicia el gestor de ventanas o la sesión. Ahora puedes crear el primer acceso.'
 exec "$target" --run
fi
if command -v yad >/dev/null; then
 selected=$(yad --file-selection --title="$TITLE: elige un archivo .desktop" --filename=/usr/share/applications/ --file-filter='Programas | *.desktop') || exit 0
elif command -v zenity >/dev/null; then
 selected=$(zenity --file-selection --title="$TITLE" --filename=/usr/share/applications/ --file-filter='Programas | *.desktop') || exit 0
elif command -v Xdialog >/dev/null; then
 selected=$(Xdialog --stdout --title='Elige el .desktop del programa' --fselect /usr/share/applications/ 30 90) || exit 0
else
 msg 'Se necesita YAD, Zenity o Xdialog para elegir el programa.'; exit 1
fi
[[ -n "$selected" ]] || exit 0
if [[ ! -f "$selected" || "$selected" != *.desktop ]]; then msg 'Selecciona un archivo .desktop de un programa.'; exit 1; fi
# Copia propia: no altera el lanzador original ni sobrescribe accesos existentes.
desktop=''
command -v xdg-user-dir >/dev/null && desktop=$(xdg-user-dir DESKTOP 2>/dev/null)
[[ -n "$desktop" && "$desktop" != "$HOME" ]] || desktop="$HOME/Desktop"
mkdir -p -- "$desktop" || exit 1
base=$(basename -- "$selected" .desktop)
dest="$desktop/$base.desktop"
n=1
while [[ -e "$dest" || -L "$dest" ]]; do dest="$desktop/$base-$n.desktop"; ((n++)); done
cp -- "$selected" "$dest" && chmod u+x "$dest" || { msg 'No se pudo crear el acceso.'; exit 1; }
if pidof xfdesktop >/dev/null 2>&1; then
 command -v gio >/dev/null && gio set "$dest" metadata::trusted true 2>/dev/null
elif command -v rox >/dev/null && pidof ROX-Filer >/dev/null 2>&1; then
 # ROX mantiene los iconos en el pinboard, no en la carpeta Desktop.
 xml=$(printf '%s' "$dest" | sed 's/\&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g;s/"/\&quot;/g')
 if ! rox -R <<EOF
<?xml version="1.0"?>
<env:Envelope xmlns:env="http://www.w3.org/2001/12/soap-envelope"><env:Body><PinboardAdd xmlns="http://rox.sourceforge.net/SOAP/ROX-Filer"><Path>$xml</Path></PinboardAdd></env:Body></env:Envelope>
EOF
 then msg "Acceso guardado en $dest. No se pudo fijar en ROX: arrástralo desde esa carpeta al escritorio."; exit 1; fi
fi
msg "Acceso creado:\n$dest\n\nSi el escritorio solicita permiso para ejecutar el lanzador, selecciona «Permitir» o «Marcar como fiable»."
