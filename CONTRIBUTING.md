# 参与贡献

感谢你帮助改进 ChatGPT Windows 中文启动器。

## 反馈问题

提交 Issue 时，请尽量提供：

- Windows 版本；
- ChatGPT 客户端版本；
- ChatGPT 的安装方式；
- PowerShell 版本；
- 使用的启动命令；
- 完整错误提示；
- 删除隐私信息后的诊断日志；
- 问题是否可以通过重新启动入口复现。

获取 ChatGPT 版本：

```powershell
(Get-AppxPackage -Name "OpenAI.Codex" | Sort-Object Version -Descending | Select-Object -First 1).Version
```

诊断日志位置：

```text
%LOCALAPPDATA%\Codex\locale-patch\chatgpt-zh-cn-cdp.log
```

请勿提交 GitHub 令牌、OpenAI 登录凭据、Cookie、聊天内容或其他私人数据。

## 提交代码

1. 从最新 `main` 创建分支。
2. 保持修改聚焦，并为兼容性修复补充说明或测试。
3. 更新 `CHANGELOG.md` 中未发布部分的变更记录。
4. 提交 Pull Request，描述问题、修改方式和验证环境。

分支名称建议：

```text
fix/<short-description>
feat/<short-description>
docs/<short-description>
```

## 验证要求

至少执行 PowerShell 语法检查：

```powershell
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path .\launch-chatgpt-zh-cn-cdp.ps1),
    [ref]$null,
    [ref]$errors
) | Out-Null
if ($errors.Count -gt 0) { $errors; exit 1 }
```

涉及启动、路径探测或页面注入的改动，还应说明实际验证的 Windows 和 ChatGPT 版本。
