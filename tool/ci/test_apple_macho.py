"""Semantic, portable Mach-O fixtures; no Apple tools or real binaries required."""
import dataclasses
import struct
import unittest

from apple_macho import read_macho


def thin(*, platform=2, cpu=0x100000c, subtype=0, filetype=2,
         minimum=0x000f0000, sdk=0x001a0500, commands=None, endian='<'):
    if commands is None:
        commands = [struct.pack(endian + '6I', 0x32, 24, platform, minimum, sdk, 0)]
    body = b''.join(commands)
    return struct.pack(endian + '8I', 0xfeedfacf, cpu, subtype, filetype,
                       len(commands), len(body), 0, 0) + body


def fat(images, *, wide=False, endian='>'):
    entry_size = 32 if wide else 20
    offset = 8 + entry_size * len(images)
    entries, payload = [], bytearray()
    for binary in images:
        cpu, subtype = struct.unpack_from('<II', binary, 4)
        if wide:
            entries.append(struct.pack(endian + 'IIQQII', cpu, subtype, offset, len(binary), 0, 0))
        else:
            entries.append(struct.pack(endian + '5I', cpu, subtype, offset, len(binary), 0))
        payload.extend(binary)
        offset += len(binary)
    return struct.pack(endian + 'II', 0xcafebabf if wide else 0xcafebabe, len(images)) + b''.join(entries) + payload


class MachOTests(unittest.TestCase):
    def test_device_fields_are_decoded_and_immutable(self):
        slices = read_macho(thin())
        self.assertEqual(len(slices), 1)
        self.assertEqual(dataclasses.asdict(slices[0]), {
            'cputype': 0x100000c, 'cpusubtype': 0, 'filetype': 2,
            'platform': 2, 'minimum_os': '15.0', 'sdk': '26.5'})
        with self.assertRaises(dataclasses.FrozenInstanceError):
            slices[0].platform = 7

    def test_big_endian_thin_and_all_fat_encodings_preserve_platform(self):
        self.assertEqual(read_macho(thin(endian='>'))[0].platform, 2)
        for wide in [False, True]:
            for endian in ['<', '>']:
                with self.subTest(wide=wide, endian=endian):
                    result = read_macho(fat([thin(), thin(platform=7)], wide=wide, endian=endian))
                    self.assertEqual([s.platform for s in result], [2, 7])

    def test_parser_retains_simulator_and_x86_for_policy_layer(self):
        self.assertEqual(read_macho(thin(platform=7))[0].platform, 7)
        self.assertEqual(read_macho(thin(cpu=0x1000007))[0].cputype, 0x1000007)

    def test_truncation_unknown_magic_and_load_command_bounds_fail(self):
        valid = thin()
        cases = [b'', b'hello', valid[:31], valid[:-1],
                 thin(commands=[]),
                 thin(commands=[struct.pack('<II', 0x32, 0)]),
                 thin(commands=[struct.pack('<II', 0x32, 80)]),
                 thin(commands=[struct.pack('<6I', 0x32, 24, 2, 0xf0000, 0x1a0500, 1)]),
                 thin(commands=[struct.pack('<II', 0x99, 8)]),
                 thin(commands=[struct.pack('<6I', 0x32, 24, 2, 0xf0000, 0x1a0500, 0)] * 2)]
        # Header claims a command count or byte size inconsistent with the real body.
        for offset, value in [(16, 2), (20, 25), (20, 0xffffffff)]:
            damaged = bytearray(valid)
            struct.pack_into('<I', damaged, offset, value)
            cases.append(bytes(damaged))
        for data in cases:
            with self.subTest(data=data[:40]):
                with self.assertRaises(ValueError):
                    read_macho(data)

    def test_header_width_must_match_cpu_abi(self):
        command = struct.pack('<6I', 0x32, 24, 2, 0xf0000, 0x1a0500, 0)
        header32_arm64 = struct.pack('<7I', 0xfeedface, 0x100000c, 0, 2, 1, 24, 0)
        for binary in [header32_arm64 + command, thin(cpu=12)]:
            with self.subTest(binary=binary[:12]):
                with self.assertRaises(ValueError):
                    read_macho(binary)

    def test_fat_ranges_cannot_overlap_headers_each_other_or_end(self):
        base = fat([thin(), thin()])
        cases = [base[:20], struct.pack('>II', 0xcafebabe, 0),
                 struct.pack('>II', 0xcafebabe, 0xffffffff)]
        for entry, field, value in [(0, 8, 0), (0, 12, 0xffffffff), (1, 8, 48), (0, 16, 32), (0, 0, 0x1000007)]:
            damaged = bytearray(base)
            struct.pack_into('>I', damaged, 8 + entry * 20 + field, value)
            cases.append(bytes(damaged))
        for data in cases:
            with self.subTest(data=data[:50]):
                with self.assertRaises(ValueError):
                    read_macho(data)


if __name__ == '__main__':
    unittest.main()
