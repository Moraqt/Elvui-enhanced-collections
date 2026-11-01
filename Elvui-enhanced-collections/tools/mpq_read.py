"""Small read-only MPQ reader for inspecting this client's UI sources.

Development helper only; not installed with the addon. Never opens an archive
for writing. Supports the zlib/bzip2 sectors used by the client's Lua/XML files.
"""
from pathlib import Path
import bz2
import math
import re
import struct
import sys
import zlib

MASK = 0xFFFFFFFF
CRYPT = [0] * 0x500
seed = 0x100001
for first in range(256):
    for group in range(5):
        seed = (seed * 125 + 3) % 0x2AAAAB
        high = (seed & 0xFFFF) << 16
        seed = (seed * 125 + 3) % 0x2AAAAB
        CRYPT[first + group * 256] = high | (seed & 0xFFFF)


def hash_name(name, kind):
    a, b = 0x7FED7FED, 0xEEEEEEEE
    for ch in name.replace('/', '\\').upper().encode('ascii'):
        a = (CRYPT[(kind << 8) + ch] ^ ((a + b) & MASK)) & MASK
        b = (ch + a + b + (b << 5) + 3) & MASK
    return a


def decrypt(data, key):
    result = bytearray(data)
    b = 0xEEEEEEEE
    for offset in range(0, len(data) - 3, 4):
        b = (b + CRYPT[0x400 + (key & 255)]) & MASK
        word = struct.unpack_from('<I', data, offset)[0] ^ ((key + b) & MASK)
        struct.pack_into('<I', result, offset, word)
        key = ((((~key & MASK) << 21) + 0x11111111) | (key >> 11)) & MASK
        b = (word + b + (b << 5) + 3) & MASK
    return bytes(result)


def decompress(data, expected):
    if len(data) == expected:
        return data
    mode, payload = data[0], data[1:]
    if mode == 2:
        result = zlib.decompress(payload)
    elif mode == 16:
        result = bz2.decompress(payload)
    else:
        raise ValueError(f'Unsupported MPQ compression {mode:#x}')
    if len(result) != expected:
        raise ValueError(f'Decompressed length {len(result)} != {expected}')
    return result


class Archive:
    def __init__(self, path):
        self.path = Path(path)
        self.file = self.path.open('rb')
        header = self.file.read(44)
        signature, size, archive_size, version, shift, hashes, blocks, hash_count, block_count = struct.unpack_from('<4sIIHHIIII', header)
        if signature != b'MPQ\x1a' or version > 1:
            raise ValueError('Unsupported archive header')
        self.sector_size = 512 << shift
        self.file.seek(hashes)
        raw_hashes = decrypt(self.file.read(hash_count * 16), hash_name('(hash table)', 3))
        self.hashes = list(struct.iter_unpack('<IIHHI', raw_hashes))
        self.file.seek(blocks)
        self.blocks = list(struct.iter_unpack('<IIII', decrypt(self.file.read(block_count * 16), hash_name('(block table)', 3))))

    def read(self, name):
        match_a, match_b = hash_name(name, 1), hash_name(name, 2)
        start = hash_name(name, 0) % len(self.hashes)
        index = None
        for step in range(len(self.hashes)):
            a, b, locale, platform, block = self.hashes[(start + step) % len(self.hashes)]
            if block == MASK:
                break
            if a == match_a and b == match_b and block < len(self.blocks):
                index = block
                if locale == 0:
                    break
        if index is None:
            raise KeyError(name)
        position, packed, length, flags = self.blocks[index]
        if length > 16 * 1024 * 1024:
            raise ValueError('Only small UI sources are supported')
        self.file.seek(position)
        data = self.file.read(packed)
        key = hash_name(name.replace('/', '\\').split('\\')[-1], 3)
        if flags & 0x20000:
            key = ((key + position) ^ length) & MASK
        encrypted = flags & 0x10000
        if flags & 0x1000000:
            if encrypted:
                data = decrypt(data, key)
            return decompress(data, length) if flags & 0x200 else data
        if not flags & 0x200:
            return decrypt(data, key) if encrypted else data
        sectors = math.ceil(length / self.sector_size)
        table = data[:(sectors + 1) * 4]
        if encrypted:
            table = decrypt(table, (key - 1) & MASK)
        offsets = struct.unpack('<' + 'I' * (sectors + 1), table)
        result = bytearray()
        for i in range(sectors):
            sector = data[offsets[i]:offsets[i + 1]]
            if encrypted:
                sector = decrypt(sector, (key + i) & MASK)
            result.extend(decompress(sector, min(self.sector_size, length - len(result))))
        return bytes(result)

    def names(self):
        return self.read('(listfile)').decode('utf-8-sig').splitlines()


if __name__ == '__main__':
    archive = Archive(sys.argv[1])
    pattern = re.compile(sys.argv[2], re.I)
    names = [name for name in archive.names() if pattern.search(name)]
    for name in names:
        print(name)
    if len(sys.argv) > 3:
        destination = Path(sys.argv[3]).resolve()
        for name in names:
            target = destination.joinpath(*name.replace('\\', '/').split('/')).resolve()
            if not target.is_relative_to(destination):
                raise ValueError('Unsafe archive path')
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.read(name))
        print(f'Extracted {len(names)} source files into {destination}')
