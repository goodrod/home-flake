steam="${STEAM_DIR:-$HOME/.local/share/Steam}"
out="$1/applications"
skip='^(Proton|Steam Linux Runtime|Steamworks Common Redistributables|Steam Runtime)'

libraries=("$steam")
if [ -f "$steam/steamapps/libraryfolders.vdf" ]; then
  while IFS= read -r path; do
    [ "$path" != "$steam" ] && libraries+=("$path")
  done < <(sed -n 's/^\s*"path"\s*"\(.*\)"\s*$/\1/p' "$steam/steamapps/libraryfolders.vdf")
fi

field() {
  sed -n "s/^\s*\"$1\"\s*\"\(.*\)\"\s*$/\1/p" "$2" | head -n1
}

icon_for() {
  local appid="$1" cached
  cached=$(find "$steam/appcache/librarycache/$appid" -maxdepth 1 -regextype posix-extended \
    -regex '.*/[0-9a-f]{40}\.jpg' 2>/dev/null | head -n1)
  if [ -n "$cached" ]; then
    echo "$cached"
  else
    echo steam
  fi
}

staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT

for library in "${libraries[@]}"; do
  for manifest in "$library"/steamapps/appmanifest_*.acf; do
    [ -f "$manifest" ] || continue
    appid=$(field appid "$manifest")
    name=$(field name "$manifest")
    [ -n "$appid" ] && [ -n "$name" ] || continue
    [[ "$name" =~ $skip ]] && continue
    cat > "$staging/steam-game-$appid.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$name
Exec=steam steam://rungameid/$appid
Icon=$(icon_for "$appid")
Categories=Game;
EOF
  done
done

mkdir -p "$out"
find "$out" -maxdepth 1 -name 'steam-game-*.desktop' -delete
cp "$staging"/*.desktop "$out"/ 2>/dev/null || true
