#!/usr/bin/env python3
"""Package application sources without build output or local configuration."""
from argparse import ArgumentParser
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parents[1]
DIRECTORIES = ('lib', 'assets', 'android', 'ios', 'web', 'test', 'integration_test', 'test_driver', 'docs', 'tool')
EXCLUDED_DIRECTORIES = {'build', 'Pods', '.gradle', '.symlinks', '.swiftpm', 'ephemeral', 'xcuserdata', '__pycache__'}
EXCLUDED_FILES = {'local.properties', 'key.properties', 'Generated.xcconfig', 'flutter_export_environment.sh', '.DS_Store'}
ROOT_FILES = ('pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml', 'README.md', '.gitignore', '.metadata')


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path('output/Tiny-Trails-Source.zip'))
    arguments = parser.parse_args()
    destination = arguments.output
    if not destination.is_absolute():
        destination = ROOT / destination
    destination.parent.mkdir(parents=True, exist_ok=True)
    files = [ROOT / name for name in ROOT_FILES if (ROOT / name).is_file()]
    for directory in DIRECTORIES:
        for path in (ROOT / directory).rglob('*'):
            relative = path.relative_to(ROOT)
            if any(part in EXCLUDED_DIRECTORIES for part in relative.parts):
                continue
            if path.name in EXCLUDED_FILES or path.name.startswith('.env') or path.is_symlink():
                continue
            if path.is_file():
                files.append(path)
    with ZipFile(destination, 'w', ZIP_DEFLATED) as archive:
        for path in sorted(files):
            archive.write(path, Path('Tiny-Trails') / path.relative_to(ROOT))
    print(f'{destination.name}: {len(files)} source files, {destination.stat().st_size:,} bytes')


if __name__ == '__main__':
    main()
