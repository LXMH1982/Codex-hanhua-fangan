# 工作原理与限制

## 问题背景

部分 Windows 版 ChatGPT 客户端可以在语言设置中选中简体中文，但界面仍显示英文。排查结果显示：

- 客户端安装包中已经存在简体中文资源；
- 用户配置中可能已经写入 `localeOverride = "zh-CN"`；
- 仅修改用户配置不足以让界面语言生效；
- 客户端运行时没有正确启用内部界面语言功能。

本项目不替换语言资源，而是在客户端启动后修正运行时状态。

## 启动流程

`launch-chatgpt-zh-cn-cdp.ps1` 执行以下步骤：

1. 查找最新的 `OpenAI.Codex` MSIX 应用及其中的 `app\ChatGPT.exe`。
2. 查找 ChatGPT 当前使用的用户数据目录。
3. 如果 ChatGPT 已经以未打补丁方式运行，则结束旧进程。
4. 使用原有用户数据目录和本机调试参数启动 ChatGPT。
5. 通过 `127.0.0.1` 调试接口查找应用页面。
6. 等待 ChatGPT 的 Statsig 客户端加载。
7. 在渲染页面中启用内部界面语言开关。
8. 读取功能开关和页面语言结果，写入诊断日志。

启动时使用的关键参数包括：

```text
--user-data-dir=<ChatGPT 现有用户数据目录>
--remote-debugging-address=127.0.0.1
--remote-debugging-port=9321
--remote-allow-origins=*
```

## 适用边界

这是进程级运行时补丁，不是客户端安装补丁。

- 通过项目启动入口启动的 ChatGPT 会应用补丁。
- 直接通过原版快捷方式启动的 ChatGPT 不受控制。
- 重新启动客户端后，需要再次通过项目入口启动。
- ChatGPT 更新可能改变页面结构、功能开关或调试接口，导致补丁失效。
- 项目只影响客户端界面语言，不改变模型回答语言、账号、聊天记录或网络配置。

## 故障定位

每次实际启动都会重建以下日志：

```text
%LOCALAPPDATA%\Codex\locale-patch\chatgpt-zh-cn-cdp.log
```

日志中的阶段包括：

- `launcher started`：启动流程已开始；
- `executable=` 和 `userData=`：实际找到的客户端与数据目录；
- `target=`：找到的应用页面；
- `patchResult=`：运行时补丁是否应用；
- `verification=`：功能开关和页面语言验证结果；
- `patch failed:`：补丁失败的具体异常。

## 已知安全边界

运行时补丁依赖本机 Chromium DevTools 调试接口。调试端口仅绑定到 `127.0.0.1`，但在 ChatGPT 运行期间仍然是一个本机调试入口。

因此：

- 只运行本仓库中经过检查的脚本；
- 不要在不可信环境中长期保留调试端口；
- 不要在 Issue 中公开令牌、Cookie、完整聊天内容或敏感路径；
- 如果对 Electron 调试接口的安全性有疑虑，请不要运行本项目。
