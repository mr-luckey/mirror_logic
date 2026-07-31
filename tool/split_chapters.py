"""Re-shard the level catalog into fixed-size chapters.

The catalog shipped as one 1000-level `ch1`, which makes the level grid an
endless scroll and the chapter screen pointless. This rewrites `chapterId`,
`levelId` and `levelIndex` so every chapter holds `PER_CHAPTER` levels, and
fixes up the ids that levels refer to each other by.
"""

import json
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, 'assets', 'levels', 'levels.json')
BACKUP_DIR = os.path.join(ROOT, '.level-backups')

PER_CHAPTER = 100


def main():
    with open(CATALOG, encoding='utf-8') as f:
        data = json.load(f)

    levels = data['levels']
    # Keep the order the catalog already plays in.
    levels.sort(key=lambda l: l['metadata'].get('globalIndex', l['levelIndex']))

    os.makedirs(BACKUP_DIR, exist_ok=True)
    backup = os.path.join(BACKUP_DIR, 'levels.before-chapter-split.json')
    if not os.path.exists(backup):
        shutil.copyfile(CATALOG, backup)
        print('backed up ->', backup)

    remap = {}
    for i, level in enumerate(levels):
        chapter = i // PER_CHAPTER + 1
        index = i % PER_CHAPTER + 1
        new_id = f'ch{chapter}_{index:03d}'
        remap[level['levelId']] = new_id

    for i, level in enumerate(levels):
        chapter = i // PER_CHAPTER + 1
        index = i % PER_CHAPTER + 1
        level['chapterId'] = f'ch{chapter}'
        level['levelId'] = remap[level['levelId']]
        level['levelIndex'] = index
        meta = level.setdefault('metadata', {})
        meta['globalIndex'] = i + 1
        meta['difficultyBand'] = f'ch{chapter}'

    # Any cross-reference between levels has to follow the rename.
    ref_keys = ('nextLevelId', 'previousLevelId', 'unlocksLevelId')
    fixed = 0
    for level in levels:
        for key in ref_keys:
            old = level.get(key)
            if isinstance(old, str) and old in remap:
                level[key] = remap[old]
                fixed += 1

    data['levels'] = levels
    with open(CATALOG, 'w', encoding='utf-8') as f:
        json.dump(data, f, separators=(',', ':'), ensure_ascii=False)

    chapters = {}
    for level in levels:
        chapters[level['chapterId']] = chapters.get(level['chapterId'], 0) + 1
    print(f'{len(levels)} levels across {len(chapters)} chapters, '
          f'{fixed} cross-references remapped')
    for cid in sorted(chapters, key=lambda c: int(c[2:])):
        print(f'  {cid}: {chapters[cid]}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
