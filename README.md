# ChatGPT Windows 中文启动器

**通过固定入口启动 ChatGPT，让 Windows 桌面客户端默认显示内置的简体中文界面。**

Windows 10/11 · PowerShell 5.1+ · Experimental

> 这是一个非官方实验性项目，与 OpenAI 没有关联。
>
> 本项目不提供修改版 ChatGPT，不替换安装目录，也不会上传聊天记录或账号信息。
> 它只保证通过本项目提供的启动入口打开 ChatGPT 时启用中文界面；直接使用原版快捷方式不受本项目管理。

## 项目简介

Windows 版 ChatGPT 桌面客户端已经包含简体中文资源，但在部分版本或环境中，即使在设置中选择“简体中文”：

- 用户配置已经写入 `localeOverride = "zh-CN"`；
- 客户端中也能找到简体中文资源；
- 重启后界面仍然恢复为英文。

问题不在语言包缺失，而是客户端内部的界面语言功能开关没有正常加载。

本项目通过固定的启动流程启用该开关，并提供诊断日志，方便确认补丁是否成功应用。它适合需要反复使用中文界面的 Windows 用户，也适合希望继续适配新版 ChatGPT 的开发者。

## 功能特点

- 提供可双击运行的 `Start-ChatGPT-zh-CN.cmd` 启动入口。
- 自动查找 Windows 版 ChatGPT 的 MSIX 安装位置和用户数据目录。
- 使用用户原有的 ChatGPT 数据目录，不创建独立账号环境。
- 检测无法连接调试接口的旧进程，并重新启动客户端。
- 应用中文界面补丁后读取功能开关和页面语言，便于验证结果。
- 将启动与错误信息写入本地诊断日志。
- 附带经过整理的问题排查对话记录，方便其他 AI 或开发者理解背景。

## 工作原理

项目采用“启动时补丁”，不修改 ChatGPT 安装包：

1. 使用现有用户数据目录启动 `ChatGPT.exe`。
2. 仅在 `127.0.0.1` 上开启本机调试连接。
3. 连接 ChatGPT 的渲染页面，启用客户端内置的 `enable_i18n` 界面语言开关。
4. 等待界面更新，并验证开关状态和页面语言。

详细说明见 [docs/how-it-works.md](docs/how-it-works.md)。

## 仓库内容

| 文件 | 用途 |
| --- | --- |
| `Start-ChatGPT-zh-CN.cmd` | 推荐的 Windows 双击启动入口 |
| `launch-chatgpt-zh-cn-cdp.ps1` | 查找客户端、启动进程并应用运行时补丁 |
| `ChatGPT中文界面对话记录.txt` | 精简后的问题分析与解决过程 |
| `ChatGPT中文界面对话记录.zip` | 上述对话记录的压缩副本 |
| `docs/how-it-works.md` | 技术原理、限制与故障点说明 |
| `CONTRIBUTING.md` | 问题反馈和代码贡献方式 |
| `SECURITY.md` | 安全边界与漏洞报告方式 |
| `CHANGELOG.md` | 项目变更记录 |

## 环境要求

- Windows 10 或 Windows 11。
- 从 OpenAI 官方渠道安装的 Windows 版 ChatGPT 桌面客户端（MSIX）。
- Windows PowerShell 5.1 或更高版本。
- 已能正常登录和启动 ChatGPT。

本项目不会绕过 ChatGPT 的网络要求、账号限制或地区限制，也不提供语言模型服务。

## 快速开始

1. 下载或克隆本仓库，并放到一个固定目录。
2. 关闭已经打开的 ChatGPT。
3. 双击 `Start-ChatGPT-zh-CN.cmd`。
4. 等待 ChatGPT 启动并显示简体中文界面。
5. 以后需要中文界面时，通过这个入口启动 ChatGPT。

首次启动需要等待客户端加载、补丁应用和界面刷新。如果失败，脚本会保留诊断日志并显示提示。

### 手动运行

需要在 PowerShell 中调试或指定端口时，可以运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\launch-chatgpt-zh-cn-cdp.ps1
```

指定其他本机调试端口：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\launch-chatgpt-zh-cn-cdp.ps1 -Port 9331
```

## 诊断日志

启动、目标页面、补丁结果和验证信息会写入：

```text
%LOCALAPPDATA%\Codex\locale-patch\chatgpt-zh-cn-cdp.log
```

日志可能包含本机安装路径和页面地址。提交到公开 Issue 前，请先删除用户名、账号标识、聊天内容和其他不希望公开的信息。

## 常见问题

### 双击后没有变成中文

先关闭 ChatGPT，再重新运行 `Start-ChatGPT-zh-CN.cmd`。如果仍然失败，请检查诊断日志中的最后一条错误。

### 提示找不到 ChatGPT

项目当前按 MSIX 应用 `OpenAI.Codex` 和可执行文件 `app\ChatGPT.exe` 查找客户端。请确认使用的是官方 Windows 桌面客户端，而不是网页版、浏览器快捷方式或其他第三方封装版本。

### 提示找不到用户数据目录

不同版本的 ChatGPT 可能使用不同的 MSIX 虚拟化路径。请提交客户端版本、安装方式和不包含隐私信息的目录结构。

### 补丁成功，但直接打开 ChatGPT 又变成英文

这是当前方案的预期行为。补丁在 ChatGPT 进程内生效，必须通过本项目的启动入口打开客户端。本项目不会永久修改 ChatGPT 安装包。

### ChatGPT 更新后失效

运行时页面、功能开关或调试接口可能随客户端更新而变化。反馈时请提供以下信息：

```powershell
(Get-AppxPackage -Name "OpenAI.Codex" | Sort-Object Version -Descending | Select-Object -First 1).Version
$PSVersionTable.PSVersion
```

并附上完整诊断日志和错误提示。

## 使用 AI 继续适配

仓库保留了精简版对话记录和运行时补丁脚本。需要针对新版本或新环境调整时，可以把以下两个文件交给 AI：

- `ChatGPT中文界面对话记录.txt`
- `launch-chatgpt-zh-cn-cdp.ps1`

然后说明 Windows 版本、ChatGPT 安装方式和具体报错。对话记录是经过整理的上下文，不包含脚本、命令、工具日志或内部诊断数据。

## 兼容性与限制

- 项目目前处于实验阶段，只记录在原作者环境中完成过验证。
- 不同 ChatGPT 版本、安装渠道和 Windows 环境可能需要额外适配。
- 通过启动入口再次运行后，如果检测到可用的本机调试接口，脚本会认为现有实例已经打过补丁并直接退出。
- 如果 ChatGPT 已在运行但没有可用调试接口，脚本会终止现有进程后重新启动。运行前请保存未提交的聊天或输入内容。
- 项目不会修改回答语言；它只处理客户端界面语言。
- 项目不会修改系统区域或系统显示语言。

## 安全与隐私

运行时补丁需要开启本机调试端口。请只运行来自本仓库并经过检查的脚本，不要使用来源不明的修改版。

项目不会主动上传聊天记录或账号信息。更多信息见 [SECURITY.md](SECURITY.md)。

## 参与贡献

欢迎提交兼容性报告、错误日志、修复和文档改进。开始前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

本项目使用 [MIT License](LICENSE)。
