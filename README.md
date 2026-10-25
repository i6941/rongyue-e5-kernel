# 荣月 E5 定制内核 · 64MB CMA 显存池与增强特性版

专为 **荣月 E5 手机终端**（`Unisoc UMS9621`，6nm 8核 A55，OpenWrt 25.12.5，物理屏 320×480）深度定制的高级 Linux 6.18 内核。

彻底解决出厂内核在长时间运行、高频切换游戏或播放高画质流媒体视频时，因连续物理内存碎片导致的 **DRM 显存分配失败（`sprd_gem_dumb_create failed to allocate buffer with size 626688`）全局黑屏与图形合成器闪退** 故障。

---

## 一、核心特性与修复清单

1. **64MB CMA 专属连续显存池** (`CONFIG_CMA=y`, `CONFIG_DMA_CMA=y`)：
   - 为 Wayland/DRM 屏幕图形渲染单独保留 64MB 绝对连续的物理显存通道；
   - 常驻显示仅占用约 16MB，池内长留 48MB 余量，彻底根治模拟器退回列表、长视频边下边播时的黑屏顽疾。
2. **内核级内存规整** (`CONFIG_COMPACTION=y`, `CONFIG_MIGRATION=y`)：
   - 暴露 `/proc/sys/vm/compact_memory` 接口，赋予内核在内存压力下动态挪动页面、实时重整连续内存的能力。
3. **ZRAM 内存压缩** (`CONFIG_ZRAM=y`, `CONFIG_ZRAM_BACKEND_LZ4=y`, `CONFIG_ZRAM_BACKEND_ZSTD=y`)：
   - 原生支持极速 LZ4 / ZSTD 内存压缩算法，可在 1.5GB 物理 RAM 上划出 512MB~1GB 的高速压缩 Swap，多任务不再被 OOM 强杀。
4. **Google TCP BBR 拥塞控制** (`CONFIG_TCP_CONG_BBR=y`)：
   - 支持动态切换 BBR 拥塞控制算法，显著降低网络弱网与高吞吐流媒体播放的排队延迟。
5. **主流游戏手柄原生即插即用 + 震动力反馈** (`CONFIG_JOYSTICK_XPAD=y`, `CONFIG_JOYSTICK_XPAD_FF=y`)：
   - 内置 Xbox 360 / Xbox One / PS4 / PS5 / Switch / 北通 / 八位堂等通用手柄驱动，支持通过 Type-C OTG 转接线免驱直连，支持手柄马达震动力反馈。
6. **ARM64 CE 硬件加密加速** (`CONFIG_CRYPTO_AES_ARM64_CE=y`)：
   - 激活 ARMv8 Crypto Extensions 指令集，大幅提升 SSH、HTTPS 与代理隧道的加密解密吞吐。
7. **展锐平台私有驱动空指针缺陷彻底修复**：
   - 包含 7 个关键驱动修复补丁，消除上游源码树在 `sprd_iommu.c`、`qogirn6pro/global_dpu.c` 及复位控制器调用中遗漏判空触发的 Kernel Panic 崩溃。

---

## 二、一键升级安装（老用户无痛升级）

手机通过 USB 连电脑（设备地址 `192.168.9.1`），在电脑终端执行：

```sh
ssh root@192.168.9.1 'wget -O- https://raw.githubusercontent.com/i6941/rongyue-e5-kernel/main/tools/upgrade-kernel.sh | sh'
```

脚本将全自动从 GitHub Releases 下载预编译的 64MB 镜像、校验 SHA-256 哈希、安全写入 `boot_b` 分区并解压安装驱动模块。升级完成后执行 `reboot` 重启生效。

> **双槽位安全保证**：本升级**仅写入 Slot B**（OpenWrt 所在分区），**完全不触动 Slot A 原厂 Android 13 槽位**。如遇意外，长按音量下开机或通过 `misc` 分区即可无痛回退原厂安卓。

---

## 三、从源码编译指南（WSL2 / Ubuntu）

如果你希望自行定制或二次开发，可按以下标准流程在 WSL2 或 Ubuntu 环境构建：

### 1. 准备交叉编译工具链
```bash
sudo apt-get update
sudo apt-get install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu make bc bison flex libssl-dev lz4
```

### 2. 拉取内核源码与打补丁
```bash
git clone --depth 1 -b e5-6.18 https://github.com/sprd-linux-devs/linux.git e5-kernel
cd e5-kernel

# 应用本仓库的所有修复补丁
git am /path/to/rongyue-e5-kernel/patches/*.patch
```

### 3. 应用配置并编译
```bash
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

cp /path/to/rongyue-e5-kernel/configs/e5_cma64_defconfig .config
make olddefconfig
make -j$(nproc) Image modules
```

### 4. 组装 Android Boot Image v4
```bash
python3 /path/to/rongyue-e5-kernel/tools/assemble-exact-boot.py
```
生成的 `new_boot_exact.img`（64MB）即为可刷入设备的最终启动镜像。

---

## 四、License
- Linux 内核源码遵守 GPL-2.0 协议。
- 展锐平台驱动补丁与组装工具按 MIT 协议开源。
