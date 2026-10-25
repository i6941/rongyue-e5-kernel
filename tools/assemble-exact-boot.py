import struct
import hashlib

ORIG_BOOT = '.secrets/device-backup/partition-snapshots/boot_b.img'
NEW_KERN = 'bundle/package/files/new_Image'
RAMDISK = 'bundle/package/files/new_extracted_ramdisk.img'
OUT = 'bundle/package/files/new_boot_exact.img'

orig = bytearray(open(ORIG_BOOT, 'rb').read())
kern = open(NEW_KERN, 'rb').read()
ram = open(RAMDISK, 'rb').read()

PAGE = 4096

k_size = len(kern)
r_size = len(ram)
print(f'新内核大小: {k_size} (0x{k_size:x})')
print(f'新内存盘大小: {r_size} (0x{r_size:x})')

# 1. 更新 Header 里的 kernel_size 和 ramdisk_size
struct.pack_into('<I', orig, 8, k_size)
struct.pack_into('<I', orig, 12, r_size)
cmdline = orig[44:44+16].decode('latin1', 'replace').strip('\x00')
print(f'保持母版 cmdline: {repr(cmdline)}')

# 2. 计算各部分在母版里的新布局
k_start = 4096
k_end = k_start + k_size
k_pad = ((-k_size) % PAGE)

r_start = k_end + k_pad
r_end = r_start + r_size
r_pad = ((-r_size) % PAGE)
payload_end = r_end + r_pad

# 构造新镜像前部
new_img = bytearray()
new_img.extend(orig[:4096])
new_img.extend(kern)
new_img.extend(b'\x00' * k_pad)
new_img.extend(ram)
new_img.extend(b'\x00' * r_pad)
assert len(new_img) == payload_end

# 3. 提取母版中的 AVB/vbmeta 块
footer = orig[-64:]
avb_magic = footer[:4]
original_size, avb_offset, avb_size = struct.unpack_from('>QQQ', footer, 12)

vbmeta_data = orig[avb_offset : avb_offset + avb_size]
assert len(vbmeta_data) == avb_size

new_img.extend(vbmeta_data)
PERSIST_LOG_OFFSET = 56 << 20
assert len(new_img) <= PERSIST_LOG_OFFSET

new_img.extend(b'\x00' * (len(orig) - 64 - len(new_img)))

new_footer = bytearray(footer)
struct.pack_into('>QQQ', new_footer, 12, payload_end, payload_end, avb_size)
new_img.extend(new_footer)

assert len(new_img) == len(orig)

with open(OUT, 'wb') as f:
    f.write(new_img)

print(f'成功生成最终 boot 镜像: {OUT} ({len(new_img)} 字节)')
