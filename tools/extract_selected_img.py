#!/usr/bin/env python3
"""Extract an explicit DFF/TXD allowlist from an uncompressed PC VC IMG v1.

The small DIR index is read; the IMG payload is sought/read only for selected
entries. Sector padding is preserved. This does not convert RenderWare models.
"""
import argparse
import hashlib
import json
import re
import struct
from pathlib import Path

SECTOR = 2048
ENTRY = struct.Struct('<II24s')


class ArchiveError(ValueError):
    pass


def safe_name(name):
    if not re.fullmatch(r'[A-Za-z0-9_.-]+\.(?:dff|txd)', name, re.IGNORECASE):
        raise ArchiveError('Only simple .dff/.txd filenames are allowed: '+repr(name))
    return name.lower()


def select_entries(directory, image_size, names):
    wanted = list(dict.fromkeys(safe_name(name) for name in names))
    if not wanted:
        raise ArchiveError('Select at least one exact filename; bulk extraction is unsupported')
    if not directory or len(directory) % ENTRY.size:
        raise ArchiveError('DIR must contain complete 32-byte v1 directory records')
    found = {}
    for cursor in range(0, len(directory), ENTRY.size):
        sector, sectors, raw = ENTRY.unpack_from(directory, cursor)
        name = raw.split(b'\0', 1)[0].decode('ascii', errors='replace').lower()
        if name not in wanted:
            continue
        if name in found:
            raise ArchiveError('Ambiguous duplicate selected entry: '+name)
        offset, size = sector * SECTOR, sectors * SECTOR
        if not size or offset + size > image_size:
            raise ArchiveError('Selected entry is empty or outside IMG: '+name)
        found[name] = {'name':name, 'offset':offset, 'bytes':size}
    missing = [name for name in wanted if name not in found]
    if missing:
        raise ArchiveError('Missing entries: '+', '.join(missing))
    selected = [found[name] for name in wanted]
    by_offset = sorted(selected, key=lambda row:row['offset'])
    for left, right in zip(by_offset, by_offset[1:]):
        if left['offset'] + left['bytes'] > right['offset']:
            raise ArchiveError('Selected entries overlap')
    return selected


def extract(image, directory, output, names, dry_run=False):
    selected = select_entries(directory.read_bytes(), image.stat().st_size, names)
    report = {'format':'PC VC IMG v1', 'directory_sha256':hashlib.sha256(directory.read_bytes()).hexdigest(),
              'archive_bytes':image.stat().st_size, 'selected_bytes':sum(row['bytes'] for row in selected),
              'dry_run':dry_run, 'entries':selected, 'conversion_performed':False}
    if dry_run:
        return report
    # Fresh output avoids mixing old full-archive exports with this allowlist.
    output.mkdir(parents=True, exist_ok=False)
    try:
        with image.open('rb') as source:
            for row in selected:
                source.seek(row['offset'])
                remaining = row['bytes']
                digest = hashlib.sha256()
                with (output/row['name']).open('xb') as target:
                    while remaining:
                        block = source.read(min(remaining, 1024*1024))
                        if not block:
                            raise ArchiveError('IMG truncated during extraction')
                        target.write(block)
                        digest.update(block)
                        remaining -= len(block)
                row['sha256'] = digest.hexdigest()
        (output/'selection_manifest.json').write_text(json.dumps(report, indent=2)+'\n')
    except Exception:
        # Only this invocation's fresh output is removed on failure.
        for path in output.iterdir():
            path.unlink()
        output.rmdir()
        raise
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--img', type=Path, required=True)
    parser.add_argument('--dir', type=Path, required=True, help='Matching PC Vice City .dir index')
    parser.add_argument('--out', type=Path, required=True, help='New output directory')
    parser.add_argument('--entry', action='append', required=True, help='Exact filename; repeat for each selection')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    try:
        report = extract(args.img, args.dir, args.out, args.entry, args.dry_run)
    except (ArchiveError, OSError) as error:
        parser.exit(1, str(error)+'\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
