# MCC 2.0 多终端控制台 Windows Server 2019 x64 完整交付包

发行修订：`0.2.0-ws2019.2-lock-service`，锁定修正：`lock-service-20261016`。

[下载完整交付 ZIP](https://github.com/Tarot268/Minecraft-Console-Client/archive/refs/heads/mcc2-console-downloads.zip)

[已下载旧包：只下载解压修复补丁](https://github.com/Tarot268/Minecraft-Console-Client/raw/refs/heads/mcc2-console-downloads/mcc2-extraction-fix-20261016.zip)，无需重新下载五个分段。操作见 [解压故障修复](REPAIR-EXTRACTION.zh-CN.md)。

## Windows 使用步骤

1. 下载上方 ZIP，并完整解压到一个新的目录。建议至少预留 1 GB 磁盘空间。
2. 打开解压后的目录，双击 `Extract-Complete-Package.cmd`。不要在压缩包预览窗口内直接运行。
3. 脚本会校验五个分段文件、还原原始完整 ZIP、核对原包 SHA256，并默认解压到 `%USERPROFILE%\MCC2`，例如 `C:\Users\Administrator\MCC2`。原始 ZIP 已存在时会校验并复用，不会因之前解压失败而要求重新下载。脚本使用系统自带的 PowerShell 和 .NET，无需下载依赖。
4. 以脚本最后显示的 `Ready:` 路径为准，打开对应目录，按 Agent 部署指南完成配置，再运行 `start-console.cmd`。默认目标目录已存在时会安全停止；如需新部署，请指定另一个短目录。

如需指定目标位置，在本下载目录的 PowerShell 中执行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Expand-CompletePackage.ps1 -DestinationPath 'C:\MCC2'
```

目标目录应不存在。不要在双层 GitHub 长名称目录下继续部署；脚本会提前检查最长输出路径，并使用短临时目录、.NET ZIP 解压器和完整性检查，避免依赖 Windows PowerShell 5.1 的 `Expand-Archive` 模块。无需修改注册表或全局执行策略。

GitHub 对普通 Git 文件大小有限制，公开 fork 仓库还拒绝新增 LFS 对象，因此下载分支用五个分段保存原包。不要单独下载 `parts` 中的某一个文件；上方 ZIP 包含全部分段、校验数据和还原工具。

## 完整包内容

包括私有 .NET / ASP.NET Core 10.0.13 Windows x64 运行时、MCC 2.0 EA Build 13 兼容宿主、BotRoom / AutoResponder / ETPBot / TweakMCC 四插件、离线浏览器安装包、MCC 1.x 配置迁移工具和教程、Agent 全流程部署指南。

插件版本为 1.3.0，以 `lock-service-20261016` 标识和文件哈希区分之前的包。锁定后，已获授权的 TweakMCC 长任务持续执行，新 ETPBot 请求不会抢占；解锁后恢复 ETPBot 优先权。宝库执行期间的锁定会等待已接收的整条任务队列及安全返回完成，包括待锁定期间新加入的任务。

原始 ZIP 文件名：`mcc2-console-0.2.0-windows-server-2019-x64-complete-lock-service.zip`。

原始 ZIP 大小：227,888,945 字节。SHA256：

```text
83c8a966c599b86060fb3130bb5aa68ce8c2edad2dd77aeded061f607ca2b994
```

上面的 SHA256 对应还原后的原始 ZIP；GitHub 生成的外层下载 ZIP 具有不同的校验值。

## 验证范围

原始包已完成 193 项自动化场景和 11 项隔离实服验收；实服使用 3 个真实 MCC 客户端，其中 2 个业务机器人，保持实际聊天和传送等待限制。未在原生 Windows Server 2019 上执行，也未验证真实 Microsoft 账号登录。

本分支是本项目的兼容交付包，并非 MCCTeam 官方 MCC 发布。账号持有人仍需完成首次 Microsoft 授权；包中不含账号密码或登录缓存。源码默认分支不受本下载分支影响。
