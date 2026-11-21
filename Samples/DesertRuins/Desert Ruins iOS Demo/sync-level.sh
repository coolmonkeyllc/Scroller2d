#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    printf 'Usage: %s /path/to/Desert-Ruins-workspace\n' "$0" >&2
    exit 1
fi
project_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
workspace="$(CDPATH= cd -- "$1" && pwd)"
for file in Levels/DesertRuins.plist Assets/ObjectList.plist Assets/ObstacleList.plist Assets/CharacterList.plist; do
    plutil -lint "$workspace/$file"
done
for folder in Assets/Images Assets/Sounds; do
    test -d "$workspace/$folder" || { printf 'Missing %s\n' "$workspace/$folder" >&2; exit 1; }
done
python3 "$project_dir/import-art.py" "$workspace/Assets/Images" "$project_dir/DesertRuins/LevelArt.xcassets"
for file in Levels/DesertRuins.plist Assets/ObjectList.plist Assets/ObstacleList.plist Assets/CharacterList.plist; do
    cp "$workspace/$file" "$project_dir/DesertRuins/$file"
done
rsync -a --delete "$workspace/Assets/Sounds/" "$project_dir/DesertRuins/Assets/Sounds/"
printf 'Updated the bundled level and assets. Build and run DesertRuins again.\n'
