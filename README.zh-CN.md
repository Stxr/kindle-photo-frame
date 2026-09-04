# Kindle Photo Frame

[English](README.md) | [简体中文](README.zh-CN.md)

将越狱 Kindle 变成低功耗的锁屏相框。照片会在设备端预处理，通过 Kindle 原生屏保流程显示，并可按小时、按天或由 RTC 从深度休眠中定时唤醒后循环切换。

项目保持轻量：Kindle 端只运行 POSIX Shell，电脑端使用无第三方依赖的 Python 命令行工具，通过现有的 `linkss`、powerd 和 FBInk 完成屏保、休眠唤醒与墨水屏刷新。

> [!WARNING]
> 这是面向自有设备的非官方修改。越狱和修改系统行为可能影响官方支持，也可能在固件升级后失效。请先备份，并优先在非关键设备上测试。

## 项目优势

- **真正使用锁屏显示**：不需要让阅读器应用一直在前台运行。
- **兼顾续航**：普通模式保留 Kindle 的正常休眠；RTC 模式仅在需要换图时短暂唤醒。
- **稳定循环**：RTC 每次唤醒严格推进一张，最后一张之后自动回到第一张。
- **适配墨水屏**：输出匹配屏幕尺寸的 PNG8 灰度图，并使用 FBInk GC16 完整刷新。
- **批量处理**：支持上传文件或整个文件夹，自动旋转、居中裁切、缩放、灰度转换和清理元数据。
- **远程投送**：通过 SSH/SFTP 添加照片，不必切换 USB 存储模式。
- **可恢复**：安装时备份原有 `linkss` 屏保，卸载时恢复。
- **隐私优先**：照片只在本地电脑和 Kindle 之间传输，`photos/` 默认不会进入 Git。

## 已测试环境

参考设备为 Kindle Paperwhite 3：

- 1072×1448、300 DPI 屏幕；
- ARMv7 Kindle 5.x 固件；
- NiLuJe `linkss` 0.25.N；
- FBInk 1.24；
- 支持 SFTP v3 的 Dropbear。

其他 Kindle 5.x 机型如果具备 `linkss`、FBInk、LIPC 电源事件和本项目使用的 powerd 属性，也可能运行，但尚未验证。不同分辨率需要调整 `device/import.sh`。

## 工作原理

```text
电脑中的照片
      │  SSH/SFTP
      ▼
/mnt/us/photo-frame/inbox
      │  自动旋转 → 裁切 → 灰度 → PNG8
      ▼
/mnt/us/photo-frame/prepared
      │  时间槽选择 / RTC 顺序循环
      ▼
/mnt/us/linkss/screensavers/bg_ss00.png
      │
      ├─ linkss 原生锁屏显示
      └─ RTC 唤醒后由 FBInk 执行 GC16 刷新

powerd: readyToSuspend → 设置 rtcWakeup
        深度休眠       → 应用不占用 CPU
        RTC 唤醒       → 推进一张、刷新、再次休眠
```

监听器会关注 `readyToSuspend` 和 `wakeupFromSuspend`。RTC 闹钟必须在 powerd 短暂的 `readyToSuspend` 窗口中设置；闹钟触发后，程序从当前照片推进一张，末尾回到第一张，刷新锁屏后再次进入休眠。

## 前置条件

### Kindle 端

1. 一台属于你的、已经越狱的 Kindle。
2. 推荐安装 [KUAL](https://www.mobileread.com/forums/showthread.php?t=203326) 和 MobileRead Package Installer，用于菜单操作。
3. 已安装并启用 NiLuJe 的 [`linkss` 屏保插件](https://www.mobileread.com/forums/showthread.php?t=195474)，且 `/mnt/us/linkss/auto` 存在。
4. `/usr/bin/fbink` 可用。
5. `/mnt/us/linkss/bin/convert` 可用。
6. 可通过 SSH 密钥以 root 登录，通常由 USBNetwork 和 Dropbear 提供。请只在可信网络使用。

### 电脑端

- Python 3.10 或更高版本；
- OpenSSH 的 `ssh` 和 `sftp`；
- 能访问处于唤醒状态的 Kindle；
- Git。

Python 工具不需要安装第三方包。

## 安装与部署

```sh
git clone https://github.com/Stxr/kindle-photo-frame.git
cd kindle-photo-frame

KINDLE_HOST=root@KINDLE_IP
ssh -o BatchMode=yes "$KINDLE_HOST" 'hostname && uname -m'

python3 host/photo_frame.py deploy --host "$KINDLE_HOST"
ssh "$KINDLE_HOST" /mnt/us/photo-frame/bin/install.sh
```

安装程序会备份原屏保、创建托管屏保文件、向用户存储区的 `linkss` 启动脚本加入带标记的自启动段，并启动监听器。

上传单张、多张照片或整个文件夹，然后正常锁屏：

```sh
python3 host/photo_frame.py push --host "$KINDLE_HOST" photo1.jpg photo2.png
python3 host/photo_frame.py push --host "$KINDLE_HOST" /path/to/photo-folder
```

## 照片批处理

`push` 接受任意数量的 JPEG/PNG 文件和文件夹，并递归查找文件夹内容。每张新照片会：

1. 根据 EXIF 自动纠正方向；
2. 等比例放大或缩小到覆盖 1072×1448；
3. 居中裁切到屏幕比例，不拉伸；
4. 转为灰度和最多 256 色；
5. 删除元数据并输出 PNG8。

处理后的文件名包含校验值，未变化的照片会直接复用。运行时照片位于 `/mnt/us/photo-frame/`，不会被仓库跟踪。

## 为照片添加一句文案

项目提供了一套受 InkTime 启发、重新编写的[中文锁屏文案提示词](prompts/caption.zh-CN.md)：强调不复述画面、不虚构背景，以克制幽默或含蓄观察写一句 8～24 字的旁白。

将视觉模型生成或自己写好的文案保存为 JSON：

```json
[
  {
    "image": "photos/example.jpg",
    "caption": "今天的会议，主要讨论罐头怎么开",
    "subtitle": "可选的小字信息"
  }
]
```

安装可选的排版依赖并生成 1072×1448 Kindle 成品图：

```sh
python3 -m pip install -r requirements-caption.txt
python3 host/render_captions.py captions.json \
  --font /path/to/chinese-font.otf \
  --output photos/rendered
python3 host/photo_frame.py push --host "$KINDLE_HOST" photos/rendered
```

排版脚本会给照片底部保留白色文字区，文案最多两行，并输出 256 级灰度 PNG。字体须由用户自行提供；推荐使用许可允许的中文字体，如 Noto Sans CJK。

## 切换模式

### 每小时或每天

这两种模式根据当前时间槽选择照片，并保留正常深度休眠，功耗最低。若边界时设备正在深度休眠，新照片会在下次唤醒并重新锁屏时出现。

```sh
ssh "$KINDLE_HOST" /mnt/us/photo-frame/bin/set-mode.sh hourly
ssh "$KINDLE_HOST" /mnt/us/photo-frame/bin/set-mode.sh daily
```

### 每分钟测试

分钟模式通过 `suspendGrace`/`deferSuspend` 暂缓深度休眠，在锁屏状态每分钟刷新。它明显更耗电，只用于快速测试。

```sh
ssh "$KINDLE_HOST" /mnt/us/photo-frame/bin/set-mode.sh minute
```

切回每小时、每天或卸载后，会恢复正常休眠行为。

### RTC 深度休眠模式

RTC 模式允许 CPU 正常休眠。到达间隔后，powerd 唤醒 Kindle，监听器推进并刷新下一张照片，再在下次休眠前预约闹钟。

KUAL → **Photo Frame → Auto-wake rotation interval** 将换图周期与 RTC 自动唤醒绑定，并提供：

- 5 分钟（测试）；
- 15 分钟；
- 30 分钟；
- 1 小时；
- 1 天。

也可通过 SSH 设置 60～86400 秒的任意间隔：

```sh
ssh "$KINDLE_HOST" /mnt/us/photo-frame/bin/set-rtc.sh 300
```

参考 PW3 已验证：设备可进入深度休眠，在 Wi-Fi 未唤醒的情况下由 RTC 唤醒、切换锁屏图片并再次休眠。具体定时精度和功耗仍取决于固件；正式使用建议选择每小时或每天。

## KUAL 菜单与状态

**Photo Frame** 菜单包含安装/修复、导入、立即刷新、分钟测试、自动唤醒换图周期、状态和卸载恢复。普通的每小时/每天非唤醒模式仅为兼容旧配置而保留在 SSH 命令中，不再作为 KUAL 菜单选项。

```sh
python3 host/photo_frame.py status --host "$KINDLE_HOST"
# 或
ssh "$KINDLE_HOST" /mnt/us/photo-frame/bin/status.sh
```

状态会显示当前模式、RTC 间隔、下次唤醒时间戳、照片数量和当前照片。

## 卸载与恢复

卸载会恢复首次安装时备份的屏保，并只移除本项目加入的自启动段；照片库会保留。

```sh
ssh "$KINDLE_HOST" /mnt/us/photo-frame/bin/uninstall.sh
```

如需同时移除 KUAL 菜单：

```sh
ssh "$KINDLE_HOST" 'rm -rf /mnt/us/extensions/photo-frame'
```

该命令只针对本扩展。除非也想删除照片、状态和日志，否则不要删除 `/mnt/us/photo-frame/`。

## 常见问题

### 仍然显示旧的 linkss 图片

- 确认 `/mnt/us/linkss/auto` 存在；
- 运行 `device/import.sh`，再运行 `device/pick.sh`；
- 确认 `/mnt/us/linkss/screensavers/bg_ss00.png` 存在；
- 唤醒后重新锁屏一次。

### 文件已变化但屏幕没刷新

`linkss` 不会在后台文件替换后自动重绘。分钟和 RTC 模式使用 FBInk 刷新；请确认 `/usr/bin/fbink` 存在，监听器以 root 运行。

### RTC 模式没有唤醒

- 确认 `lipc-probe com.lab126.powerd` 包含 `rtcWakeup`；
- 在 `/mnt/us/photo-frame/photo-frame.log` 查找 `readyToSuspend`、`scheduled RTC wake` 和 `wakeupFromSuspend`；
- `rtcWakeup` 只能在 `readyToSuspend` 阶段成功设置；
- RTC 成功唤醒时 Wi-Fi 可能仍关闭，所以 SSH 超时不能单独证明唤醒失败。

### KUAL 失败，但 root SSH 正常

部分 KUAL 环境缺少 KMC/Gandalf 权限。可改用 root SSH 安装和诊断，不要永久放宽 `/dev/fb0` 权限。

## 项目结构与开发

```text
device/                     Kindle 端 POSIX Shell 脚本
extension/photo-frame/      KUAL 扩展
host/photo_frame.py         SSH/SFTP 部署和批量上传工具
host/render_captions.py     文案版锁屏图片排版工具
prompts/                    可复用的文案提示词
tests/                      标准库单元测试
```

运行测试：

```sh
python3 -m unittest discover -s tests -v
```

脚本面向旧 Kindle 上的 BusyBox/POSIX `sh`，请保留 Unix LF 换行，并避免 Bash 专属语法。

## 隐私与安全

- 使用 SSH 密钥，不要把密码或私钥写进脚本或 Git；
- 只在可信网络开放 Kindle SSH；
- 照片、预览、日志和运行状态不会进入版本库；
- 远程投送是主动推送，不会在 Kindle 上开放公网上传服务。

## 许可证与致谢

项目采用 [MIT 许可证](LICENSE)。感谢 [InkTime](https://github.com/dai-hongtao/InkTime) 提供“回忆相框 + 短旁白”的产品灵感；本项目面向 Kindle 独立编写提示词与排版器。也感谢 NiLuJe、MobileRead、[FBInk](https://github.com/NiLuJe/FBInk) 和 [KOReader](https://github.com/koreader/koreader) 社区提供的 Kindle 工具与电源管理实践。
