"""Bounded, dependency-free Mach-O metadata parsing (never invokes Apple tools)."""
from dataclasses import dataclass
import struct


@dataclass(frozen=True)
class MachOSlice:
    cputype: int
    cpusubtype: int
    filetype: int
    platform: int
    minimum_os: str
    sdk: str


THIN_MAGICS = {b'\xce\xfa\xed\xfe': ('<', False), b'\xcf\xfa\xed\xfe': ('<', True),
               b'\xfe\xed\xfa\xce': ('>', False), b'\xfe\xed\xfa\xcf': ('>', True)}
FAT_MAGICS = {b'\xca\xfe\xba\xbe': ('>', False), b'\xbe\xba\xfe\xca': ('<', False),
              b'\xca\xfe\xba\xbf': ('>', True), b'\xbf\xba\xfe\xca': ('<', True)}
MACHO_MAGICS = frozenset(THIN_MAGICS) | frozenset(FAT_MAGICS)


def _version(encoded):
    major, minor, patch = encoded >> 16, (encoded >> 8) & 255, encoded & 255
    if not major:
        raise ValueError('Mach-O OS/SDK version is missing')
    return f'{major}.{minor}' + (f'.{patch}' if patch else '')


def _thin(data):
    encoding = THIN_MAGICS.get(bytes(data[:4]))
    if encoding is None:
        raise ValueError('Fat slice is not a thin Mach-O image')
    endian, wide = encoding
    header_size = 32 if wide else 28
    if len(data) < header_size:
        raise ValueError('Truncated Mach-O header')
    _, cpu, subtype, filetype, count, size, _ = struct.unpack_from(endian + '7I', data)
    if bool(cpu & 0x01000000) != wide:
        raise ValueError('Mach-O header width disagrees with CPU ABI')
    end = header_size + size
    if count > 65536 or count > size // 8 or end > len(data):
        raise ValueError('Invalid Mach-O load command range')
    cursor, build = header_size, None
    for _ in range(count):
        if cursor + 8 > end:
            raise ValueError('Truncated Mach-O load command')
        command, command_size = struct.unpack_from(endian + 'II', data, cursor)
        if command_size < 8 or command_size % (8 if wide else 4) or cursor + command_size > end:
            raise ValueError('Invalid Mach-O load command size')
        if command == 0x32:  # LC_BUILD_VERSION: platform, minos, sdk, ntools
            if build is not None or command_size < 24:
                raise ValueError('Duplicate or truncated LC_BUILD_VERSION')
            platform, minimum, sdk, tools = struct.unpack_from(endian + '4I', data, cursor + 8)
            if tools > (command_size - 24) // 8 or command_size != 24 + tools * 8:
                raise ValueError('Invalid LC_BUILD_VERSION tool range')
            build = (platform, _version(minimum), _version(sdk))
        # A legacy minimum command alongside LC_BUILD_VERSION is ambiguous.
        if command in (0x24, 0x25, 0x2f, 0x30):
            raise ValueError('Legacy/ambiguous platform declaration')
        cursor += command_size
    if cursor != end or build is None:
        raise ValueError('Missing platform declaration or unclaimed load command bytes')
    return MachOSlice(cpu, subtype, filetype, *build)


def read_macho(data: bytes) -> list[MachOSlice]:
    """Read thin or fat metadata, rejecting malformed headers, commands and slices."""
    if not isinstance(data, bytes):
        raise ValueError('Mach-O input must be bytes')
    magic = data[:4]
    if magic in THIN_MAGICS:
        return [_thin(memoryview(data))]
    if magic not in FAT_MAGICS or len(data) < 8:
        raise ValueError('Not a Mach-O image')
    endian, wide = FAT_MAGICS[magic]
    count = struct.unpack_from(endian + 'I', data, 4)[0]
    stride = 32 if wide else 20
    table_end = 8 + count * stride
    if not 1 <= count <= 64 or table_end > len(data):
        raise ValueError('Invalid fat Mach-O slice count/table')
    slices, ranges = [], []
    for index in range(count):
        position = 8 + index * stride
        if wide:
            cpu, subtype, offset, size, alignment, reserved = struct.unpack_from(endian + 'IIQQII', data, position)
            if reserved:
                raise ValueError('Nonzero fat64 reserved field')
        else:
            cpu, subtype, offset, size, alignment = struct.unpack_from(endian + '5I', data, position)
        if alignment > 31 or offset % (1 << alignment) or size < 28 or offset < table_end or size > len(data) - offset:
            raise ValueError('Invalid fat Mach-O slice range/alignment')
        end = offset + size
        if any(offset < previous_end and previous_start < end for previous_start, previous_end in ranges):
            raise ValueError('Overlapping fat Mach-O slices')
        image = _thin(memoryview(data)[offset:end])
        if (image.cputype, image.cpusubtype) != (cpu, subtype):
            raise ValueError('Fat table CPU disagrees with slice header')
        ranges.append((offset, end))
        slices.append(image)
    return slices
