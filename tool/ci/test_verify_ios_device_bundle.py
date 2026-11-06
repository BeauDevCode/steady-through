"""Owned, fictional iPhoneOS fixture tree; byte-level validation is portable."""
import contextlib
import copy
import hashlib
import io
import json
from pathlib import Path
import plistlib
import stat
import tempfile
import unittest
import warnings
import zipfile

from test_apple_macho import fat, thin
from verify_ios_device_bundle import main, validate_bundle, verify_archive

ASSETS = 'Frameworks/App.framework/flutter_assets/'
PRIVACY = ['file_picker_darwin_file_picker_darwin.bundle/PrivacyInfo.xcprivacy',
           'url_launcher_ios_url_launcher_ios.bundle/PrivacyInfo.xcprivacy']


def write(app, path, data):
    target = app / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    return target


def plist(app, path, value):
    return write(app, path, plistlib.dumps(value))


def fixture(parent):
    app = parent / 'Runner.app'
    app.mkdir()
    plist(app, 'Info.plist', {
        'CFBundleIdentifier': 'com.beaudevcode.steadyThrough',
        'CFBundleDisplayName': 'Steady Through', 'CFBundleName': 'Steady Through',
        'CFBundleExecutable': 'Runner', 'CFBundlePackageType': 'APPL',
        'CFBundleShortVersionString': '1.2.1', 'CFBundleVersion': '6',
        'CFBundleSupportedPlatforms': ['iPhoneOS'], 'DTPlatformName': 'iphoneos',
        'DTSDKName': 'iphoneos26.5', 'MinimumOSVersion': '15.0',
        'UIMainStoryboardFile': 'Main', 'UILaunchStoryboardName': 'LaunchScreen',
        'CFBundleIcons': {'CFBundlePrimaryIcon': {'CFBundleIconName': 'AppIcon', 'CFBundleIconFiles': ['AppIcon60x60']}},
    })
    write(app, 'Runner', thin()).chmod(0o755)
    for name in ['App', 'Flutter', 'objective_c']:
        binary = f'Frameworks/{name}.framework/{name}'
        write(app, binary, thin(filetype=6)).chmod(0o755)
        plist(app, f'Frameworks/{name}.framework/Info.plist', {
            'CFBundleExecutable': name, 'CFBundlePackageType': 'FMWK', 'MinimumOSVersion': '15.0'})
    for path in ['Assets.car', 'AppIcon60x60@2x.png',
                 ASSETS + 'AssetManifest.bin', ASSETS + 'NOTICES.Z',
                 ASSETS + 'assets/brand/steady-through-icon.png',
                 ASSETS + 'assets/fonts/Manrope.ttf', ASSETS + 'fonts/MaterialIcons-Regular.otf']:
        write(app, path, b'fictional-resource')
    for storyboard in ['Main', 'LaunchScreen']:
        plist(app, f'Base.lproj/{storyboard}.storyboardc/Info.plist', {'UIStoryboardVersion': 1})
        write(app, f'Base.lproj/{storyboard}.storyboardc/view.nib', b'fictional-nib')
    write(app, ASSETS + 'FontManifest.json', json.dumps([
        {'family': 'Manrope', 'fonts': [{'asset': 'assets/fonts/Manrope.ttf'}]},
        {'family': 'MaterialIcons', 'fonts': [{'asset': 'fonts/MaterialIcons-Regular.otf'}]},
    ]).encode())
    write(app, ASSETS + 'NativeAssetsManifest.json', json.dumps({
        'format-version': [1, 0, 0], 'native-assets': {
            'ios_arm64': {'package:objective_c/objective_c.dylib': ['absolute', 'objective_c.framework/objective_c']}}}).encode())
    for path in PRIVACY:
        plist(app, path, {'NSPrivacyTracking': False, 'NSPrivacyTrackingDomains': [], 'NSPrivacyCollectedDataTypes': []})
        plist(app, str(Path(path).parent / 'Info.plist'), {
            'CFBundleSupportedPlatforms': ['iPhoneOS'], 'DTPlatformName': 'iphoneos', 'DTSDKName': 'iphoneos26.5'})
    return app


def archive(app, path):
    with zipfile.ZipFile(path, 'w') as zipped:
        for entry in [app] + sorted(app.rglob('*')):
            name = entry.relative_to(app.parent).as_posix()
            if entry.is_symlink():
                info = zipfile.ZipInfo(name)
                info.create_system = 3
                info.external_attr = entry.lstat().st_mode << 16
                zipped.writestr(info, str(entry.readlink()).encode())
            else:
                zipped.write(entry, name)
    return path


class BundleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.app = fixture(self.root)

    def check(self):
        return validate_bundle(self.app, expected_version='1.2.1', expected_build='6')

    def mutate_plist(self, path, key, value):
        data = plistlib.loads((self.app / path).read_bytes())
        data[key] = value
        plist(self.app, path, data)

    def test_complete_device_report_records_all_files_and_explicit_limits(self):
        report = self.check()
        self.assertIsInstance(report, dict)
        self.assertEqual(report['schemaVersion'], 1)
        self.assertEqual(report['kind'], 'ios-device-release')
        self.assertEqual(report['app'], {
            'bundleIdentifier': 'com.beaudevcode.steadyThrough', 'displayName': 'Steady Through',
            'name': 'Steady Through', 'version': '1.2.1', 'build': '6', 'executable': 'Runner',
            'supportedPlatforms': ['iPhoneOS'], 'platformName': 'iphoneos', 'sdkName': 'iphoneos26.5',
            'minimumOSVersion': '15.0'})
        self.assertIs(report['installable'], False)
        self.assertEqual(report['physicalDeviceExecution'], 'not-run')
        self.assertEqual(report['distributionSigning'], 'not-validated')
        self.assertEqual(report['directories'], sorted(['.'] + [str(p.relative_to(self.app)) for p in self.app.rglob('*') if p.is_dir()]))
        self.assertEqual([p['path'] for p in report['files']], sorted(str(p.relative_to(self.app)) for p in self.app.rglob('*') if p.is_file()))
        runner = next(p for p in report['files'] if p['path'] == 'Runner')
        self.assertEqual(runner, {'path': 'Runner', 'type': 'file', 'size': 56,
            'sha256': hashlib.sha256((self.app / 'Runner').read_bytes()).hexdigest(), 'mode': 0o755})
        self.assertEqual([x['path'] for x in report['machO']], ['Frameworks/App.framework/App', 'Frameworks/Flutter.framework/Flutter', 'Frameworks/objective_c.framework/objective_c', 'Runner'])
        self.assertEqual(report['privacyResources'], PRIVACY)
        self.assertEqual(report['nativeAssets']['ios_arm64']['package:objective_c/objective_c.dylib'], ['absolute', 'objective_c.framework/objective_c'])

    def test_main_identity_version_platform_and_substitutions_reject(self):
        for key, wrong in [('CFBundleIdentifier', 'wrong'), ('CFBundleDisplayName', 'Wrong'),
                ('CFBundleName', 'Runner'), ('CFBundlePackageType', 'FMWK'),
                ('CFBundleExecutable', '../Runner'), ('CFBundleShortVersionString', '1.2.0'),
                ('CFBundleVersion', '5'), ('CFBundleSupportedPlatforms', ['iPhoneSimulator']),
                ('DTPlatformName', 'iphonesimulator'), ('DTSDKName', 'iphonesimulator26.5'),
                ('MinimumOSVersion', '14.0'), ('Unresolved', '$(PRODUCT_NAME)')]:
            with self.subTest(key=key):
                original = (self.app / 'Info.plist').read_bytes()
                self.mutate_plist('Info.plist', key, wrong)
                with self.assertRaises(ValueError): self.check()
                (self.app / 'Info.plist').write_bytes(original)

    def test_all_actual_images_require_device_arm64_and_compatible_minimum(self):
        for path in ['Runner', 'Frameworks/App.framework/App', 'Frameworks/Flutter.framework/Flutter', 'Frameworks/objective_c.framework/objective_c', 'Frameworks/extra.dylib']:
            original = (self.app / path).read_bytes() if (self.app / path).exists() else None
            for binary in [thin(platform=7), fat([thin(), thin(platform=7)]), thin(cpu=0x1000007),
                           thin(platform=6), thin(minimum=0x00100000), thin()[:20], b'not-macho']:
                with self.subTest(path=path, binary=binary[:16]):
                    write(self.app, path, binary)
                    with self.assertRaises(ValueError): self.check()
            if original is None: (self.app / path).unlink()
            else: (self.app / path).write_bytes(original)

    def test_main_and_required_framework_filetypes_are_enforced(self):
        for path, wrong in [('Runner', 6), ('Frameworks/App.framework/App', 2), ('Frameworks/Flutter.framework/Flutter', 2)]:
            original = (self.app / path).read_bytes()
            write(self.app, path, thin(filetype=wrong))
            with self.assertRaises(ValueError): self.check()
            (self.app / path).write_bytes(original)

    def test_older_embedded_minimum_and_extra_arch_metadata_are_accepted(self):
        write(self.app, 'Frameworks/objective_c.framework/objective_c', thin(filetype=6, minimum=0xe0000))
        path = self.app / (ASSETS + 'NativeAssetsManifest.json')
        manifest = json.loads(path.read_text())
        manifest['native-assets']['ios_x64'] = copy.deepcopy(manifest['native-assets']['ios_arm64'])
        path.write_text(json.dumps(manifest))
        self.assertIsInstance(self.check(), dict)

    def test_required_resources_cannot_be_missing_or_empty(self):
        for path in ['Runner', 'Frameworks/App.framework/App', 'Frameworks/Flutter.framework/Flutter',
                ASSETS + 'AssetManifest.bin', ASSETS + 'FontManifest.json', ASSETS + 'NOTICES.Z',
                ASSETS + 'assets/fonts/Manrope.ttf', ASSETS + 'fonts/MaterialIcons-Regular.otf',
                ASSETS + 'assets/brand/steady-through-icon.png', 'Assets.car', 'AppIcon60x60@2x.png',
                'Base.lproj/Main.storyboardc/view.nib', 'Base.lproj/LaunchScreen.storyboardc/view.nib',
                ASSETS + 'NativeAssetsManifest.json'] + PRIVACY:
            with self.subTest(path=path):
                target = self.app / path
                original = target.read_bytes()
                target.unlink()
                with self.assertRaises(ValueError): self.check()
                target.write_bytes(b'')
                with self.assertRaises(ValueError): self.check()
                target.write_bytes(original)

    def test_privacy_shape_and_bundle_platform_reject(self):
        for key, value in [('NSPrivacyTracking', True), ('NSPrivacyTrackingDomains', ['example.test']),
                           ('NSPrivacyCollectedDataTypes', [{}]), ('NSPrivacyAccessedAPITypes', [{}])]:
            original = (self.app / PRIVACY[0]).read_bytes()
            self.mutate_plist(PRIVACY[0], key, value)
            with self.assertRaises(ValueError): self.check()
            (self.app / PRIVACY[0]).write_bytes(original)
        self.mutate_plist(str(Path(PRIVACY[0]).parent / 'Info.plist'), 'DTPlatformName', 'iphonesimulator')
        with self.assertRaises(ValueError): self.check()

    def test_native_mapping_format_arch_target_and_safe_existence_reject(self):
        target = self.app / (ASSETS + 'NativeAssetsManifest.json')
        original = target.read_bytes()
        valid = json.loads(original)
        bad = [dict(valid, **{'format-version': [2, 0, 0]}), dict(valid, **{'native-assets': {}})]
        for mapping in [[], ['absolute', '../Runner'], ['absolute', '/tmp/Runner'], ['absolute', 'absent'], ['relative', 'objective_c.framework/objective_c']]:
            changed = copy.deepcopy(valid)
            changed['native-assets']['ios_arm64']['package:objective_c/objective_c.dylib'] = mapping
            bad.append(changed)
        changed = copy.deepcopy(valid)
        changed['native-assets']['ios_x64'] = {'extra': ['absolute', '../../escape']}
        bad.append(changed)
        for manifest in bad:
            with self.subTest(manifest=manifest):
                target.write_text(json.dumps(manifest))
                with self.assertRaises(ValueError): self.check()
        target.write_bytes(original)

    def test_debug_test_fixture_and_signing_artifacts_reject(self):
        for path, data in [(ASSETS + 'kernel_blob.bin', b'kernel'), ('Tests.xctest/payload', b'test'),
                ('_CodeSignature/CodeResources', b'signature'), ('embedded.mobileprovision', b'profile'),
                ('Frameworks/extra.dylib', thin(filetype=6) + b'Fictional native test river garden'),
                (ASSETS + 'extra', b'Separate fictional backup meadow')]:
            with self.subTest(path=path):
                created = write(self.app, path, data)
                with self.assertRaises(ValueError): self.check()
                created.unlink()
                if created.parent.name in ['Tests.xctest', '_CodeSignature']: created.parent.rmdir()

    def test_symlink_inventory_and_escaping_or_unsafe_path_rejection(self):
        link = self.app / 'relative-link'
        link.symlink_to('Assets.car')
        report = self.check()
        self.assertIsInstance(report, dict)
        record = next(f for f in report['files'] if f['path'] == 'relative-link')
        self.assertEqual(record['type'], 'symlink')
        self.assertEqual(record['target'], 'Assets.car')
        self.assertEqual(record['size'], 10)
        link.unlink()
        for target in ['../outside', '/tmp/outside', 'missing', 'relative-link']:
            link.symlink_to(target)
            with self.assertRaises(ValueError): self.check()
            link.unlink()
        write(self.app, 'bad\\name', b'data')
        with self.assertRaises(ValueError): self.check()

    def test_archive_exact_members_hashes_types_modes_and_internal_symlinks(self):
        (self.app / 'relative-link').symlink_to('Assets.car')
        report = self.check()
        zipped = archive(self.app, self.root / 'device.zip')
        result = verify_archive(zipped, report)
        self.assertIsInstance(result, dict)
        self.assertEqual(result['filename'], 'device.zip')
        self.assertEqual(result['size'], zipped.stat().st_size)
        self.assertEqual(result['sha256'], hashlib.sha256(zipped.read_bytes()).hexdigest())
        self.assertEqual(result['memberCount'], len(report['directories']) + len(report['files']))
        for badname in ['__MACOSX/entry', '../escape', '/absolute', 'Runner.app/extra', 'Runner.app//bad', 'Runner.app/../bad']:
            with self.subTest(name=badname):
                archive(self.app, zipped)
                with zipfile.ZipFile(zipped, 'a') as handle: handle.writestr(badname, b'data')
                with self.assertRaises(ValueError): verify_archive(zipped, report)
        for mutation in ['duplicate', 'missing', 'hash', 'mode', 'type']:
            archive(self.app, zipped)
            with zipfile.ZipFile(zipped) as handle:
                members = [(i, handle.read(i)) for i in handle.infolist()]
            with zipfile.ZipFile(zipped, 'w') as handle:
                for info, data in members:
                    if info.filename == 'Runner.app/Runner':
                        if mutation == 'missing': continue
                        if mutation == 'hash': data += b'x'
                        if mutation == 'mode': info.external_attr = (stat.S_IFREG | 0o644) << 16
                        if mutation == 'type': info.external_attr = (stat.S_IFLNK | 0o755) << 16
                    handle.writestr(info, data)
                if mutation == 'duplicate':
                    with warnings.catch_warnings():
                        warnings.simplefilter('ignore')
                        handle.writestr(members[0][0], members[0][1])
            with self.subTest(mutation=mutation):
                with self.assertRaises(ValueError): verify_archive(zipped, report)

    def test_cli_emits_only_validated_json_and_archive_requires_unchanged_prior_report(self):
        pubspec = self.root / 'pubspec.yaml'
        pubspec.write_text('name: fixture\nversion: 1.2.1+6\n')
        output = self.root / 'report.json'
        def invoke(*extra):
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                return main([str(self.app), '--pubspec', str(pubspec), '--report', str(output), *extra])
        zipped = archive(self.app, self.root / 'device.zip')
        self.assertNotEqual(invoke('--archive', str(zipped)), 0)
        self.assertFalse(output.exists())
        self.assertEqual(invoke(), 0)
        baseline = output.read_bytes()
        self.assertNotEqual(invoke(), 0)
        self.assertEqual(output.read_bytes(), baseline)
        write(self.app, 'extra', b'changed')
        self.assertNotEqual(invoke('--archive', str(zipped)), 0)
        self.assertEqual(output.read_bytes(), baseline)
        (self.app / 'extra').unlink()
        self.assertEqual(invoke('--archive', str(zipped)), 0)
        self.assertIn('archive', json.loads(output.read_bytes()))

    def test_nested_framework_executable_is_validated_even_without_execute_bits(self):
        plist(self.app, 'Resources/Nested.framework/Info.plist', {
            'CFBundleExecutable': 'Nested', 'CFBundlePackageType': 'FMWK'})
        target = write(self.app, 'Resources/Nested.framework/Nested', b'not-a-MachO')
        target.chmod(0o644)
        with self.assertRaises(ValueError): self.check()
        target.write_bytes(thin(filetype=6))
        self.assertIsInstance(self.check(), dict)

    def test_malformed_xml_and_metadata_shapes_fail_as_validation_errors(self):
        target = self.app / 'Info.plist'
        original = target.read_bytes()
        for bad in [b'<?xml version="1.0"?><plist><dict>',
                    plistlib.dumps(dict(plistlib.loads(original), CFBundleIcons=[]))]:
            target.write_bytes(bad)
            with self.assertRaises(ValueError): self.check()
        target.write_bytes(original)

    def test_archive_rejects_nul_suffix_before_zip_normalization(self):
        report = self.check()
        zipped = archive(self.app, self.root / 'device.zip')
        with zipfile.ZipFile(zipped) as handle:
            members = [(info, handle.read(info)) for info in handle.infolist()]
        with zipfile.ZipFile(zipped, 'w') as handle:
            for info, data in members:
                if info.filename == 'Runner.app/Runner':
                    info.filename += '#####'
                handle.writestr(info, data)
        zipped.write_bytes(zipped.read_bytes().replace(b'Runner.app/Runner#####', b'Runner.app/Runner\x00evil'))
        with self.assertRaises(ValueError): verify_archive(zipped, report)

    def test_cli_failure_does_not_create_report(self):
        pubspec = self.root / 'pubspec.yaml'
        pubspec.write_text('version: 1.2.0+5\n')
        report = self.root / 'report.json'
        with contextlib.redirect_stderr(io.StringIO()):
            result = main([str(self.app), '--pubspec', str(pubspec), '--report', str(report)])
        self.assertNotEqual(result, 0)
        self.assertFalse(report.exists())


if __name__ == '__main__':
    unittest.main()
