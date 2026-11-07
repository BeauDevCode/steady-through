"""Strict unsigned iPhoneOS release evidence; stdlib only, no native subprocesses."""
import argparse
from dataclasses import asdict
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import re
import stat
import sys
import zipfile
from xml.parsers.expat import ExpatError

from apple_macho import MACHO_MAGICS, read_macho

ASSETS = 'Frameworks/App.framework/flutter_assets/'
PRIVACY_RESOURCES = (
    'file_picker_darwin_file_picker_darwin.bundle/PrivacyInfo.xcprivacy',
    'url_launcher_ios_url_launcher_ios.bundle/PrivacyInfo.xcprivacy',
)
NATIVE_KEY = 'package:objective_c/objective_c.dylib'
NATIVE_MAPPING = ['absolute', 'objective_c.framework/objective_c']
FIXTURE_MARKERS = tuple(s.encode() for s in (
    'Fictional native test river garden', 'Separate fictional backup meadow',
    'Fictional native life event', 'Fictional backup event',
    'native bridge remains paused without source consent',
    'native vault keeps an event through lock and authenticated unlock',
    'native encrypted backup restores only after its own passphrase',
    'native support flow preserves focused step and people after reopening',
    'Fictional native support journey',
))
MAX_FILE_SIZE = 512 * 1024 * 1024
MAX_ENTRIES = 100000


def _require(condition, message):
    if not condition:
        raise ValueError(message)


def _safe_path(value):
    _require(isinstance(value, str) and bool(value), 'Empty/nonstring bundle path')
    _require(not any(ord(c) < 32 or ord(c) == 127 for c in value) and '\\' not in value,
             f'Unsafe path: {value!r}')
    _require(not value.startswith('/') and all(part not in ('', '.', '..') for part in value.split('/')),
             f'Unsafe path: {value!r}')
    _require(not any(part.endswith(('.xctest', '.xcworkspace', '.dSYM')) or part in ('__MACOSX', '.DS_Store') for part in value.split('/')), 'Test/debug/Mac metadata in bundle')
    try:
        value.encode('utf-8')
    except UnicodeError as error:
        raise ValueError('Path is not UTF-8') from error
    return value


def _version(value):
    _require(isinstance(value, str) and re.fullmatch(r'\d+\.\d+(?:\.\d+)?', value), 'Invalid OS version')
    parts = tuple(int(part) for part in value.split('.'))
    return parts + (0,) * (3 - len(parts))


def _bytes(path):
    _require(path.is_file() and 0 < path.stat().st_size <= MAX_FILE_SIZE, f'Missing/empty/oversize file: {path.name}')
    return path.read_bytes()


def _plist(path):
    try:
        value = plistlib.loads(_bytes(path))
    except (plistlib.InvalidFileException, ExpatError, UnicodeError, TypeError, OverflowError) as error:
        raise ValueError(f'Invalid plist: {path.name}') from error
    _require(isinstance(value, dict), f'Plist must be dictionary: {path.name}')
    def resolved(item):
        if isinstance(item, str):
            _require('$(' not in item and '${' not in item, 'Unresolved plist substitution')
        elif isinstance(item, dict):
            for key, val in item.items(): resolved(key); resolved(val)
        elif isinstance(item, list):
            for val in item: resolved(val)
    resolved(value)
    return value


def _json(path):
    try:
        return json.loads(_bytes(path))
    except (ValueError, UnicodeError) as error:
        raise ValueError(f'Invalid JSON: {path.name}') from error


def _platform_metadata(info):
    for key, value in [('CFBundleSupportedPlatforms', ['iPhoneOS']), ('DTPlatformName', 'iphoneos')]:
        if key in info:
            _require(info[key] == value, f'Non-device {key}')
    if 'DTSDKName' in info:
        _require(isinstance(info['DTSDKName'], str) and re.fullmatch(r'iphoneos\d+\.\d+(?:\.\d+)?', info['DTSDKName']), 'Non-device SDK')
    if 'MinimumOSVersion' in info:
        _require(_version(info['MinimumOSVersion']) <= (15, 0, 0), 'Embedded resource requires newer iOS')


def _inventory(app):
    directories, files, blobs = ['.'], [], {}
    entries = sorted(app.rglob('*'))
    _require(len(entries) <= MAX_ENTRIES, 'Bundle has too many entries')
    for entry in entries:
        relative = _safe_path(entry.relative_to(app).as_posix())
        metadata = entry.lstat()
        if stat.S_ISLNK(metadata.st_mode):
            target = os.readlink(entry)
            _require(not Path(target).is_absolute() and '\\' not in target and '\x00' not in target, 'Unsafe symlink target')
            try:
                resolved = entry.resolve(strict=True)
                _require(resolved.is_relative_to(app) and resolved != entry, 'Escaping symlink')
                data = target.encode('utf-8')
            except (OSError, RuntimeError, UnicodeError) as error:
                raise ValueError('Broken/cyclic symlink') from error
            record = {'path': relative, 'type': 'symlink', 'size': len(data),
                      'sha256': hashlib.sha256(data).hexdigest(), 'mode': stat.S_IMODE(metadata.st_mode), 'target': target}
        elif stat.S_ISDIR(metadata.st_mode):
            directories.append(relative)
            continue
        else:
            _require(stat.S_ISREG(metadata.st_mode) and metadata.st_size <= MAX_FILE_SIZE, 'Unsupported/oversize bundle entry')
            data = entry.read_bytes()
            record = {'path': relative, 'type': 'file', 'size': len(data),
                      'sha256': hashlib.sha256(data).hexdigest(), 'mode': stat.S_IMODE(metadata.st_mode)}
            blobs[relative] = data
        files.append(record)
    return sorted(directories), files, blobs


def validate_bundle(app: Path, *, expected_version: str, expected_build: str) -> dict:
    """Validate a complete logical Runner.app and return a deterministic inventory."""
    app = Path(app)
    _require(app.name == 'Runner.app' and app.is_dir() and not app.is_symlink(), 'Expected a real Runner.app directory')
    app = app.resolve()
    directories, files, blobs = _inventory(app)
    info = _plist(app / 'Info.plist')
    exact = {'CFBundleIdentifier': 'com.beaudevcode.steadyThrough', 'CFBundleDisplayName': 'Steady Through',
             'CFBundleName': 'Steady Through', 'CFBundleExecutable': 'Runner', 'CFBundlePackageType': 'APPL',
             'CFBundleShortVersionString': expected_version, 'CFBundleVersion': expected_build,
             'CFBundleSupportedPlatforms': ['iPhoneOS'], 'DTPlatformName': 'iphoneos', 'MinimumOSVersion': '15.0'}
    for key, expected in exact.items():
        _require(info.get(key) == expected, f'Wrong main app {key}')
    _platform_metadata(info)
    _require('DTSDKName' in info, 'Missing main SDK name')
    _require(not (app / '_CodeSignature').exists() and not (app / 'embedded.mobileprovision').exists(),
             'Unsigned gate rejects root signing/provisioning artifacts')
    _bytes(app / 'Runner')
    _require((app / 'Runner').stat().st_mode & 0o111, 'Main executable lacks execute permission')
    required_images = {'Runner': 2, 'Frameworks/App.framework/App': 6, 'Frameworks/Flutter.framework/Flutter': 6}
    for framework in sorted(app.rglob('*.framework')):
        _require(framework.is_dir(), 'Invalid framework directory')
        framework_info = _plist(framework / 'Info.plist')
        _platform_metadata(framework_info)
        executable = _safe_path(framework_info.get('CFBundleExecutable'))
        _require('/' not in executable and framework_info.get('CFBundlePackageType') == 'FMWK', 'Invalid framework executable identity')
        required_images[(framework / executable).relative_to(app).as_posix()] = 6
    for path in required_images:
        _bytes(app / path)
    required_resources = ['Assets.car', ASSETS + 'AssetManifest.bin', ASSETS + 'NOTICES.Z',
                          ASSETS + 'assets/brand/steady-through-icon.png', ASSETS + 'assets/fonts/Manrope.ttf',
                          ASSETS + 'fonts/MaterialIcons-Regular.otf']
    icons = info.get('CFBundleIcons')
    _require(isinstance(icons, dict), 'Invalid app icon metadata')
    icon = icons.get('CFBundlePrimaryIcon')
    _require(isinstance(icon, dict) and icon.get('CFBundleIconName') == 'AppIcon' and
             isinstance(icon.get('CFBundleIconFiles'), list) and icon['CFBundleIconFiles'], 'Missing declared app icon')
    for name in icon['CFBundleIconFiles']:
        _safe_path(name)
        _require('/' not in name and any(p.stat().st_size for p in app.glob(name + '*.png') if p.is_file()), 'Missing declared app icon PNG')
    for key, expected in [('UIMainStoryboardFile', 'Main'), ('UILaunchStoryboardName', 'LaunchScreen')]:
        _require(info.get(key) == expected, 'Missing declared storyboard')
        storyboard = app / f'Base.lproj/{expected}.storyboardc'
        _plist(storyboard / 'Info.plist')
        _require(any(p.is_file() and p.stat().st_size for p in storyboard.glob('*.nib')), 'Missing compiled storyboard NIB')
    for path in required_resources:
        _bytes(app / path)
    fonts = _json(app / (ASSETS + 'FontManifest.json'))
    _require(isinstance(fonts, list), 'Invalid font manifest')
    families = {}
    for family in fonts:
        _require(isinstance(family, dict) and isinstance(family.get('fonts'), list), 'Invalid font family')
        for font in family['fonts']:
            _require(isinstance(font, dict), 'Invalid font declaration')
            asset = _safe_path(font.get('asset'))
            _bytes(app / ASSETS / asset)
        families[family.get('family')] = [font['asset'] for font in family['fonts']]
    _require('assets/fonts/Manrope.ttf' in families.get('Manrope', []) and
             'fonts/MaterialIcons-Regular.otf' in families.get('MaterialIcons', []), 'Missing declared Manrope/MaterialIcons')
    for path in PRIVACY_RESOURCES:
        privacy = _plist(app / path)
        _require(privacy.get('NSPrivacyTracking') is False and privacy.get('NSPrivacyTrackingDomains') == [] and
                 privacy.get('NSPrivacyCollectedDataTypes') == [] and privacy.get('NSPrivacyAccessedAPITypes', []) == [], 'Unexpected pinned plugin privacy declarations')
        _platform_metadata(_plist(app / PurePosixPath(path).parent / 'Info.plist'))
    manifest = _json(app / (ASSETS + 'NativeAssetsManifest.json'))
    _require(isinstance(manifest, dict) and manifest.get('format-version') == [1, 0, 0], 'Unsupported native asset manifest')
    native = manifest.get('native-assets')
    _require(isinstance(native, dict) and isinstance(native.get('ios_arm64'), dict) and
             native['ios_arm64'].get(NATIVE_KEY) == NATIVE_MAPPING, 'Missing active objective_c native asset mapping')
    for architecture, mappings in native.items():
        _require(isinstance(architecture, str) and isinstance(mappings, dict), 'Invalid native architecture metadata')
        for key, mapping in mappings.items():
            _require(isinstance(key, str) and isinstance(mapping, list) and len(mapping) == 2 and mapping[0] == 'absolute', 'Unsupported native asset mapping')
            target = _safe_path(mapping[1])
            _bytes(app / 'Frameworks' / target)
    macho = []
    for record in files:
        path = record['path']
        _require(PurePosixPath(path).name not in ('kernel_blob.bin', 'vm_snapshot_data', 'isolate_snapshot_data', 'flutter_tester'), 'Debug snapshot/test binary in bundle')
        data = blobs.get(path, b'')
        _require(not any(marker in data for marker in FIXTURE_MARKERS), 'Native fixture marker in production bundle')
        binary_required = path in required_images or path.endswith('.dylib') or (record['type'] == 'file' and record['mode'] & 0o111)
        if data[:4] in MACHO_MAGICS or binary_required:
            data = _bytes(app / path)
            slices = read_macho(data)
            for image in slices:
                _require(image.cputype == 0x100000c and image.platform == 2, f'Non-device arm64 image: {path}')
                _require(_version(image.minimum_os) <= (15, 0, 0), f'Image requires newer iOS: {path}')
                if path == 'Runner':
                    _require(_version(image.minimum_os) == (15, 0, 0), 'Main Mach-O minimum must be iOS 15.0')
                expected_type = required_images.get(path, 6 if path.endswith('.dylib') else None)
                if expected_type is not None:
                    _require(image.filetype == expected_type, f'Wrong Mach-O filetype: {path}')
            macho.append({'path': path, 'slices': [asdict(s) for s in slices]})
    return {'schemaVersion': 1, 'kind': 'ios-device-release',
            'app': {name: info[key] for name, key in (
                ('bundleIdentifier', 'CFBundleIdentifier'), ('displayName', 'CFBundleDisplayName'), ('name', 'CFBundleName'),
                ('version', 'CFBundleShortVersionString'), ('build', 'CFBundleVersion'), ('executable', 'CFBundleExecutable'),
                ('supportedPlatforms', 'CFBundleSupportedPlatforms'), ('platformName', 'DTPlatformName'),
                ('sdkName', 'DTSDKName'), ('minimumOSVersion', 'MinimumOSVersion'))},
            'directories': directories, 'files': files, 'machO': macho,
            'privacyResources': list(PRIVACY_RESOURCES), 'nativeAssets': native,
            'installable': False, 'physicalDeviceExecution': 'not-run', 'distributionSigning': 'not-validated'}


def verify_archive(archive: Path, report: dict) -> dict:
    """Check exact ZIP membership, types, modes, sizes and hashes without extraction."""
    archive = Path(archive)
    expected = {'Runner.app/' if path == '.' else f'Runner.app/{_safe_path(path)}/': None for path in report['directories']}
    for record in report['files']:
        name = f"Runner.app/{_safe_path(record['path'])}"
        _require(name not in expected, 'Duplicate report path')
        expected[name] = record
    try:
        with zipfile.ZipFile(archive) as zipped:
            members = zipped.infolist()
            _require(len(members) == len(expected) <= MAX_ENTRIES + 1, 'ZIP member count differs from validated bundle')
            seen = set()
            for member in members:
                name = member.filename
                _require(member.orig_filename == name, 'ZIP filename was normalized before validation')
                _safe_path(name[:-1] if name.endswith('/') else name)
                _require(name not in seen and name in expected and not member.flag_bits & 1, 'Duplicate/unexpected/encrypted ZIP member')
                seen.add(name)
                mode = member.external_attr >> 16
                record = expected[name]
                if record is None:
                    _require(member.is_dir() and stat.S_ISDIR(mode) and member.file_size == 0, 'ZIP directory type differs')
                    continue
                _require(not member.is_dir() and member.file_size == record['size'] and stat.S_IMODE(mode) == record['mode'], 'ZIP file size/mode differs')
                _require(stat.S_ISLNK(mode) if record['type'] == 'symlink' else stat.S_ISREG(mode), 'ZIP file type differs')
                digest = hashlib.sha256()
                with zipped.open(member) as stream:
                    while chunk := stream.read(1024 * 1024): digest.update(chunk)
                _require(digest.hexdigest() == record['sha256'], 'ZIP bytes differ from validated bundle')
            _require(seen == set(expected), 'Missing ZIP members')
    except (zipfile.BadZipFile, RuntimeError, OSError) as error:
        raise ValueError(f'Invalid ZIP: {error}') from error
    digest = hashlib.sha256()
    with archive.open('rb') as stream:
        while chunk := stream.read(1024 * 1024): digest.update(chunk)
    return {'filename': archive.name, 'size': archive.stat().st_size, 'sha256': digest.hexdigest(), 'memberCount': len(expected)}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    parser.add_argument('--pubspec', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--archive', type=Path)
    args = parser.parse_args(argv)
    try:
        versions = re.findall(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*(?:#.*)?$', args.pubspec.read_text(), re.MULTILINE)
        _require(len(versions) == 1, 'Expected one explicit pubspec version+build')
        version, build = versions[0]
        if args.archive:
            _require(args.report.is_file(), '--archive requires a prior validated report')
            baseline = json.loads(args.report.read_text())
            report = validate_bundle(args.app, expected_version=version, expected_build=build)
            _require({key: value for key, value in baseline.items() if key != 'archive'} == report, 'Directory differs from prior validated report')
            report['archive'] = verify_archive(args.archive, report)
            temporary = args.report.with_name(args.report.name + '.tmp')
            try:
                with temporary.open('x') as output: json.dump(report, output, indent=2, sort_keys=True); output.write('\n')
                os.replace(temporary, args.report)
            finally:
                if temporary.exists(): temporary.unlink()
        else:
            _require(not args.report.exists(), 'Refusing to overwrite a prior report')
            report = validate_bundle(args.app, expected_version=version, expected_build=build)
            with args.report.open('x') as output: json.dump(report, output, indent=2, sort_keys=True); output.write('\n')
        return 0
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(f'iPhoneOS release validation failed: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
