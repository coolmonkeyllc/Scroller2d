#!/bin/sh
set -eu
project_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
workspace="${1:-$project_dir/../Skypirates Workspace}"
python3 - "$project_dir" "$workspace" <<'PY'
from pathlib import Path
import sys,shutil,plistlib,json
project=Path(sys.argv[1])/'Skypirates'; workspace=Path(sys.argv[2]).resolve()
files=['Levels/Skypirates.plist','Assets/ObstacleList.plist','Assets/CharacterList.plist','Assets/ObjectList.plist']
images={'hero_plane':'Characters','patrol_ship':'Obstacles','island':'Obstacles','cloud':'Backgrounds'}
# Validate everything before copying, so a missing input does not leave a partial sync.
for file in files: plistlib.loads((workspace/file).read_bytes())
for name,category in images.items():
    if not (workspace/'Assets/Images'/category/f'{name}.png').is_file(): raise SystemExit(f'Missing image: {category}/{name}.png')
for file in files: shutil.copy2(workspace/file,project/file)
for name,category in images.items():
    target=project/'LevelArt.xcassets'/f'{name}.imageset';target.mkdir(exist_ok=True)
    shutil.copy2(workspace/'Assets/Images'/category/f'{name}.png',target/f'{name}.png')
    (target/'Contents.json').write_text(json.dumps({'images':[{'filename':f'{name}.png','idiom':'universal'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')
print('Updated Skypirates level, catalogs, and four image sets. Build and run again.')
PY
