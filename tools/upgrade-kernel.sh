#!/bin/sh
# 荣月 E5 OpenWrt 专用内核一键升级脚本
# 从 GitHub Releases 下载预编译的 64MB CMA 内核并安全刷入 boot_b

set -e

REPO="i6941/rongyue-e5-kernel"
TAG="${1:-latest}"

if [ "$TAG" = "latest" ]; then
    BASE_URL="https://github.com/$REPO/releases/latest/download"
else
    BASE_URL="https://github.com/$REPO/releases/download/$TAG"
fi

BOOT_URL="$BASE_URL/boot-cma64.img"
MODULES_URL="$BASE_URL/modules-6.18.54-e5.tar.gz"
SHA256_URL="$BASE_URL/SHA256SUMS"

# 1. 检查设备型号
if ! grep -q "UMS9621" /proc/cpuinfo 2>/dev/null && ! grep -q "ums9621" /sys/firmware/devicetree/base/compatible 2>/dev/null; then
    echo "错误：当前设备不是荣月 E5 (Unisoc UMS9621)！中止升级。" >&2
    exit 1
fi

BOOT_DEV="/dev/block/by-name/boot_b"
if [ ! -b "$BOOT_DEV" ]; then
    BOOT_DEV="/dev/mmcblk0p37"
fi
if [ ! -b "$BOOT_DEV" ]; then
    echo "错误：未找到 boot_b 分区！" >&2
    exit 1
fi

TMP_DIR="/tmp/kernel-upgrade"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

echo "=== 1. 正在下载新内核镜像与驱动模块包 ==="
wget -q --show-progress -O boot-cma64.img "$BOOT_URL" || curl -L -o boot-cma64.img "$BOOT_URL"
wget -q --show-progress -O modules-6.18.54-e5.tar.gz "$MODULES_URL" || curl -L -o modules-6.18.54-e5.tar.gz "$MODULES_URL"
wget -q -O SHA256SUMS "$SHA256_URL" || curl -L -o SHA256SUMS "$SHA256_URL"

echo "=== 2. 校验文件完整性 (SHA-256) ==="
sha256sum -c SHA256SUMS

echo "=== 3. 正在刷入 boot_b 分区 ==="
dd if=boot-cma64.img of="$BOOT_DEV" bs=1M
sync

echo "=== 4. 正在解压安装新驱动模块 ==="
mkdir -p /lib/modules/6.18.54-e5
cd /lib/modules/6.18.54-e5
tar -xzf "$TMP_DIR/modules-6.18.54-e5.tar.gz"
sync

rm -rf "$TMP_DIR"

echo "================================================="
echo " 内核升级完成！"
echo " 已激活：64MB CMA 专用显存池、ZRAM 压缩、"
echo "         TCP BBR、手柄驱动与驱动空指针安全修复。"
echo " 请执行 reboot 重启设备生效！"
echo "================================================="
