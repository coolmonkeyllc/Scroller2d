#!/usr/bin/env python3
"""Build the generated SpriteKit catalog from a LevelEditor image library."""
import json
from pathlib import Path
import shutil
import sys
from tempfile import TemporaryDirectory


def metadata(folder, **fields):
    folder.mkdir(parents=True, exist_ok=True)
    contents = {"info": {"author": "xcode", "version": 1}, **fields}
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def image_set(parent, name, image):
    folder = parent / f"{name}.imageset"
    metadata(folder, images=[{"filename": image.name, "idiom": "universal", "scale": "1x"}])
    shutil.copyfile(image, folder / image.name)


def pngs(folder):
    return sorted(p for p in folder.iterdir() if p.is_file() and p.suffix.lower() == ".png")


def build(source, catalog):
    metadata(catalog)
    for category in sorted(p for p in source.iterdir() if p.is_dir() and not p.name.startswith(".")):
        group = catalog / category.name
        metadata(group)
        names = set()
        for image in pngs(category):
            name = f"{category.name}_{image.stem}"
            if name in names:
                raise ValueError(f"Duplicate image or sequence: {name}")
            names.add(name)
            image_set(group, name, image)
        for sequence in sorted(p for p in category.iterdir() if p.is_dir() and not p.name.startswith(".")):
            frames = pngs(sequence)
            if not frames:
                continue
            name = f"{category.name}_{sequence.name}"
            if name in names:
                raise ValueError(f"Duplicate image or sequence: {name}")
            names.add(name)
            atlas = group / f"{name}.spriteatlas"
            metadata(atlas, properties={"provides-namespace": True})
            for image in frames:
                image_set(atlas, image.stem, image)


if __name__ == "__main__":
    source, destination = map(Path, sys.argv[1:])
    with TemporaryDirectory(dir=destination.parent) as temp:
        staged = Path(temp) / destination.name
        build(source, staged)
        if destination.exists():
            shutil.rmtree(destination)
        staged.rename(destination)
