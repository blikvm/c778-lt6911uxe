# C778 / LT6911UXE Linux 驱动

[English](README.md) | [简体中文](README.zh-CN.md)

用于 **BliCube C778 HDMI 转 MIPI CSI-2 模块与树莓派 5 Model B** 的开发驱动和 CSI0 设备树。本仓库整理了 2026-10-29 实机调试使用的源码，以及构建和复现脚本。

**当前状态：**已在 CSI0 单路采集到完整的 **3840×2160 UYVY、约 60fps** 画面，完成 600 帧、约 10 秒短测。但内核仍报告 **`DPHY: Datarate 2495 Mbps out of range`**。这是带有已知问题的开发快照，不代表已达到正式产品或长期稳定的 4K60 兼容性要求。

## 支持范围与实测环境

| 项目 | 本轮实测配置 |
| --- | --- |
| 主机 | Raspberry Pi 5 Model B Rev 1.0，ARM64 |
| 系统 | Debian 13.7，使用树莓派内核软件包 |
| 内核 | `6.18.50+rpt-rpi-2712` |
| 内核构建 | `#1 SMP PREEMPT Debian 1:6.18.50-1+rpt1 (2026-09-11)` |
| 模块 | C778，LT6911UXE 芯片 ID `0x2102` |
| 控制路径 | CAM/DISP 0 相机 I²C 总线，地址 `0x2b` |
| 视频路径 | 一条四 Lane CSI0 路径，使用系统自带 RP1-CFE 驱动 |
| 输入源 | 将 Pi 的 HDMI-A-1 输出接回 C778 HDMI 输入 |
| 采集格式 | 3840×2160，UYVY，每帧 16,588,800 字节 |
| 实测结果 | 600 帧，时间戳帧率约 59.9992fps，序号连续、帧长度完整 |

源码基于 Linux v6.18 的官方 LT6911UXE 驱动，来源见 [provenance](docs/provenance.md)。本仓库不是旧的 `anran_*` 厂测驱动栈，也不是厂家固件烧写示例的直接移植。

当前未验证 CSI1、双路同时输出、左右半幅、同步、1080p120、I²S 音频、取流中热插拔及其他内核。这个首版 Pi 5 快照暂不包含 RV1126B 驱动。

## 1. 硬件连接

1. 关闭树莓派与 C778 电源后，再连接 FPC。
2. 用匹配的四 Lane、22Pin 排线，将待测试的 C778 CSI 输出接到 **Pi 5 的 CAM/DISP 0**。按 [C778 硬件手册](https://blikvm.com/zh-CN/docs/device-guides/C778/)核对两端 Pin 1 和接点方向。
3. 使用独立 **5V 电源接口**给 C778 供电。不要将 5V 接到树莓派 CSI 的 3.3V 引脚。
4. 将 HDMI 视频源接入 C778 VIDEO-IN。本轮使用 Pi 自身 HDMI 输出回接，也可以使用独立视频源。
5. 启动 Pi，通过本地终端或 SSH 登录。

设备树固定面向 CAM/DISP 0，预期桥接芯片位于 I²C `10-002b`。它不会自动切换树莓派接口，也不会推断 C778 的 MIPI0/MIPI1 固件映射。识别失败时，应先核对供电、CSI 端口与排线，再考虑固件问题。同一主机采集路径不要同时接入其他相机。

## 2. 检查内核与准备编译工具

以下命令在**树莓派上执行**，不要在桌面电脑上直接运行：

```bash
uname -m
uname -r
uname -v
```

本轮架构为 `aarch64`，内核为 `6.18.50+rpt-rpi-2712`。加载脚本会拒绝其他内核版本；能够使用另一套头文件编译，不代表已验证另一版本的兼容性。

```bash
sudo apt update
sudo apt install build-essential git device-tree-compiler v4l-utils kmod
# 必须使用与正在运行的内核匹配的头文件。
sudo apt install "linux-headers-$(uname -r)"
test -d "/lib/modules/$(uname -r)/build"
```

如果软件源已经不提供该历史版本的头文件，应通过发行版取得匹配的内核／头文件组合；不要强制加载 `.ko`，也不要为了复用旧二进制盲目降级系统。不能保证历史软件包一直可下载。

加载内核模块和 overlay 需要 `sudo`，使用视频节点还需要相应设备权限。Raspberry Pi OS 通常会将桌面用户加入 `video` 组；如未加入，可添加后退出并重新登录。

## 3. 下载与构建

```bash
git clone https://github.com/blikvm/c778-lt6911uxe.git
cd c778-lt6911uxe
make -j4
```

生成：

- `c778_lt6911uxe.ko`：使用本机内核头文件构建的模块。
- `overlays/c778-csi0.dtbo`：CSI0 设备树。

仓库不提交通用预编译 `.ko`。构建不烧写固件，也不安装到系统模块目录。`make clean` 清理本地构建产物。

## 4. 临时加载

先停止其他相机或取流程序，然后执行：

```bash
./scripts/load.sh
```

脚本核对 Pi 型号、架构、内核和模块 vermagic，加载标准依赖，并在当前启动周期应用 overlay。它还会检查桥接芯片是否真正绑定；overlay 命令成功不代表驱动识别成功。

预期内核日志包含：

```text
C778 bridge identified: chip 0x2102, four lanes, polling; no firmware writes
Using sensor c778_lt6911uxe 10-002b for capture
```

查看媒体拓扑与 HDMI 输入时序：

```bash
./scripts/status.sh
```

未连接 HDMI 时，时序查询应报告 **no link／无信号**。默认 pad 格式只是占位配置，不是实际检测到的视频。驱动允许采集队列等待输入，但配套配置与采集脚本会在没有有效 HDMI 时拒绝继续。

## 5. 配置与取流

接好视频源，并等待输入时序稳定后执行：

```bash
./scripts/configure-capture.sh
./scripts/capture.sh 120
```

脚本会发现实际 media、桥接子设备和采集节点，不假定视频一定在 `/dev/video0`。随后将桥接输出格式配置到 CSI 接收端和视频队列。目前处理 `BGR888_1X24` → `RGB3`、`UYVY8_1X16` → `UYVY`；本轮记录的 4K60 采集使用 **UYVY**。

`capture.sh` 将帧写入 `/dev/null`，输出序号和时间戳，并设置 20 秒期限。超时或非零退出不代表帧数验收通过。视频源切换时序后，应在停止取流的情况下重新配置。脚本不会更改源端的分辨率或刷新率。

### 保存一帧：已测试的 4K UYVY 模式

仅在 `status.sh` 确认输入为 3840×2160，且配置结果为 UYVY 时使用下面示例：

```bash
sudo apt install ffmpeg
mkdir -p results
. ./scripts/find-path.sh
c778_find_path
timeout --signal=INT --kill-after=3s 10s v4l2-ctl -d "$C778_VIDEO" \
  --stream-mmap=4 --stream-skip=5 --stream-count=1 \
  --stream-to=results/frame-4k.uyvy
ffmpeg -f rawvideo -pixel_format uyvy422 -video_size 3840x2160 \
  -i results/frame-4k.uyvy -frames:v 1 -update 1 results/frame-4k.png
```

原始帧应为 16,588,800 字节。检查解码图像是否完整、颜色和方向是否正确。修改解码尺寸不会改变 HDMI 输入；当前色彩元数据仍需完善，该示例不能证明校准后的色彩准确性。

## 6. 重启与恢复

模块与 overlay 都是**临时加载**，没有设置开机自动启用。重启后需要重新执行 `load.sh` 和 `configure-capture.sh`。

恢复主机原有启动状态：

1. 先停止采集应用。
2. 正常重启树莓派。

运行时模块和 overlay 会随重启移除。本仓库不替换内核、不修改启动配置、不烧写芯片固件，因此不需要执行对应回滚；用户独立进行的系统修改不属于这一保证范围。


切换驱动版本前，请停止取流并重启，再加载新的构建产物；重新编译文件不会替换内核里已经加载的模块。

## 已知问题

- **D-PHY 警告：**本次成功短测仍报告 `Datarate 2495 Mbps out of range`。需要进一步核对 PHY 速率／时序设置和长期数据完整性，不能屏蔽该提示或据短测宣称无条件稳定支持 4K60。
- **色彩元数据：**当前采集仍报告 Raw／ITU-R 601／全范围，HDMI 色彩空间和量化范围传递尚未完整实现。
- **无信号失败路径：**早期已弃用版本在无输入 STREAMON 时返回错误，触发了系统 CFE 的错误清理 Oops。当前提交版改为上游式等待，并通过了限时无输入停止测试；系统 CFE 本身并未得到通用修复或完整验证。
- **未测试功能：**双路、左右半幅、1080p120、音频、长稳、反复模式切换、取流中热插拔、开机持久化。
- **固件来源：**本轮没有收集固件版本哈希；芯片 ID 不足以唯一确定可复现的固件版本。

详细来源和限制见 [provenance](docs/provenance.md)，原始测量见[测试 JSON](evidence/pi5-2026-10-29-summary.json)。短时原始帧采集不代表编码性能或端到端延迟。

## 问题反馈

请提供主机／C778 版本、`uname -a`、驱动源码 commit、已知的固件／模式信息、排线与接口、输入时序、`status.sh` 输出和相关内核日志。提交前移除凭据和无关日志。即使能收到帧，也应保留 D-PHY 警告。

## 许可证

[GPL 第 2 版](LICENSE)。保留原始驱动的版权和 SPDX 信息，来源及实测源码哈希见 [provenance](docs/provenance.md)。本仓库不分发厂家固件和烧写工具。
