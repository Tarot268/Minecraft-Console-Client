# 从 MCC 1.x 迁移账号和服务器配置

适用本完整包 `0.2.0-ws2019.2-lock-service`。转换工具已经编译，使用包内 .NET；目标机只需 Windows 自带的 64 位 PowerShell 5.1。

## 迁移结果

工具支持早期 `[Main] Login=...` INI，以及后期 `[Main.General]`、`[Main.Advanced]` TOML。后者即使扩展名是 `.ini`，仍按 TOML 解析。每个源文件迁移当前主账号和主服务器：

| MCC 1.x 内容 | MCC 2.0 结果 |
| --- | --- |
| `Login` / `Main.General.Account.Login` | `accounts.toml` 的 `Account.Login`，保留原邮箱或登录提示 |
| 你指定的实际机器人游戏名 | `Active`、`Account.Name`、终端名称；不会把邮箱当成游戏名 |
| `Password=-` 或明确的离线类型 | `Kind="offline"`；原 Login 必须与 BotName 一致 |
| 明确 Microsoft 类型 / `-Auth microsoft` | 设备码授权；旧 Microsoft 密码不复制 |
| Microsoft `Method=browser` | 保留 `microsoft-browser` 方式；不能完成浏览器回调时可显式选设备码 |
| 主服务器 Host/ServerIP、Port | `servers.toml` 的 `main`；缺省端口 25565；支持 IPv6 |
| 固定 Minecraft 版本 | 默认保留；可用 `-Version auto` 或新版本明确覆盖 |
| 已启用的 HTTP/SOCKS 代理及认证 | 私有 `accounts.toml` 的 `[Proxy]`；不会在报告中打印代理密码 |
| `AutoRespawn` | `client.toml` 同名功能开关（存在时保留） |
| 旧地形、背包、实体开关 | 为四插件启用 Terrain、Inventory、Entity、Physics、Pathfinding 五项 |
| 聊天限制 | 本项目按 100 字符、2.5 秒设置；保留真实服务端冷却约束 |

不会自动转换备用账号/服务器列表、第三方 Yggdrasil、Realms、旧 `.cs` ChatBot、旧脚本配置、聊天显示、日志、自定义变量、自动重连或所有者名单。不能识别的认证方式、非法地址、重复 INI 键、损坏 TOML 会报错并拒绝生成该机器人的结果；不会猜测为离线。

只转换账号配置不能自动迁移原插件业务数据。白名单、宝库额度、传送点及实体译名需另按 Agent 指南导入；Microsoft 邮箱密码也不同于 AuthMe 等服务器内 `/login` 密码，工具不会自动发送 `/login`。

## 一、准备文件

完整解压到 `D:\MCC2`。把旧配置放在独立私有目录，例如：

```text
D:\MCC1-private\EclipseAlpha.ini
D:\MCC1-private\EclipseBeta.ini
```

旧文件含密码，不要粘贴到聊天、公共仓库或部署报告，也不要直接覆盖新版本 TOML。机器人游戏名必须使用实际账号对应的游戏名，不能从 Microsoft 邮箱可靠推导；原文件名是正确游戏名时可直接沿用。

在 64 位 Windows PowerShell 内运行：

```powershell
Set-Location 'D:\MCC2'
Set-ExecutionPolicy -Scope Process Bypass -Force
& .\tools\Test-Deployment.ps1
```

## 二、转换单个账号

```powershell
& .\tools\Convert-Mcc1Config.ps1 `
  -InputFile 'D:\MCC1-private\EclipseAlpha.ini' `
  -BotName 'EclipseAlpha' `
  -Auth microsoft `
  -OutputDirectory 'D:\MCC2-migration'
```

`-Auth auto` 是默认值：后期配置有明确认证类型，或旧 Password 是 `-` 时能直接识别；早期 INI 只有邮箱/密码时，需要像示例一样明确 `microsoft`。离线服使用原游戏名及 `-Auth offline`，这不是跳过正版服务器验证。

如果服务器已经由 1.21.4 更新到 26.1.2，不能继续强制旧版本；可加 `-Version auto`，或 `-Version 26.1.2`。默认 `preserve` 是有意保留旧值，不会擅自替你升级协议。

输出结构：

```text
D:\MCC2-migration\EclipseAlpha\
  configurations\accounts.toml
  configurations\servers.toml
  configurations\client.toml
  migration-report.json
```

转换不会修改旧文件，不会读取旧令牌缓存，不会连接服务器，也不会覆盖已有同名输出目录。重复运行请用新目录。报告列出迁移范围、认证类型、协议版本和注意事项，不包含邮箱、密码或令牌。若文件原来是 GBK/GB18030，增加 `-Encoding gb18030`；不要在解码失败时继续使用乱码。

## 三、批量转换多个账号

用 UTF-8 保存 CSV：`D:\MCC1-private\migration.csv`。

```csv
BotName,InputFile,Auth
EclipseAlpha,EclipseAlpha.ini,microsoft
EclipseBeta,EclipseBeta.ini,microsoft
```

CSV 只有游戏名、路径、认证方式，不放密码。相对路径相对于 CSV 目录；带逗号的路径需要 CSV 双引号。然后：

```powershell
& .\tools\Convert-Mcc1Config.ps1 `
  -ManifestCsv 'D:\MCC1-private\migration.csv' `
  -OutputDirectory 'D:\MCC2-migration-batch' `
  -Version auto
```

每个账号使用各自的旧邮箱和服务器。转换会先检查批量名单和源文件是否存在。若中途遇到内容错误，已完成的转换保留在临时迁移目录，**不会自动应用到在线控制台**；修正后给失败项选择新的输出目录，核对所有结果后才初始化。

## 四、用转换结果初始化新控制台

先确认输出中的游戏名、协议版本和认证类型，私下核对主账号 Login 与旧文件相同。**不要把 accounts.toml 全文写入 Agent 报告。**

全新的 `D:\MCC2\data` 尚不存在时：

```powershell
& .\tools\Initialize-Deployment.ps1 `
  -BotNames @('EclipseAlpha','EclipseBeta') `
  -AdminPlayers @('YourGameName') `
  -MigrationRoot 'D:\MCC2-migration-batch'
```

工具会把每台转换结果放到 `data\bots\游戏名\configurations`，生成四插件配置、中继密钥和管理员初始名单，并设置：

```text
authentication = saved
serverAddress = main
pluginMode = suite
autoStart = false
```

`saved` 使 MCC 使用各自 accounts.toml；`main` 使每台使用自己的 servers.toml 及固定版本。这两个选择能防止启动参数覆盖旧邮箱/服务器选择。**不要在网页改成 microsoft 后继续期待控制台保留邮件 Login 提示**：该模式会传入机器人名，而 `saved` 才使用已有条目。

初始化不会覆盖已有 data，包括一个已启动过但尚无机器人的 data。若已经运行过控制台，先停机，完整备份并重命名 data；保留备份后再创建新 data。需要保留现有业务数据的成熟部署，不要重新初始化：正常停机并备份后，逐台只复制三个转换后的 TOML，再在网页设为 saved / main；这会替换相应新版本客户端设置，先检查差异，勿误覆盖已调好的 client.toml。

## 五、首次授权及确认

双击 `start-console.cmd`，先只启动首台。Microsoft 设备码登录会显示地址和验证码；由账号持有者在浏览器完成，确认登录的是该机器人所属账号。Login 是提示，不保证浏览器当前选中的账号正确。实际授权游戏名必须与控制台 BotName 一致，否则停止并改正名单。

原 MCC 1.x 的 `SessionCache.db` 使用旧会话结构；MCC 2.0 使用 `configurations\cache\auth-tokens`。本工具没有承诺转换两者的刷新令牌，**不要把旧缓存改名直接复制**。因此可以免于重填邮箱，但不能承诺免于一次 Microsoft 重新授权。完成后新缓存保存在每台独立目录，后续启动可复用，除非令牌被撤销或过期。

网页中看到中继与游戏在线后，继续 [Agent 部署指南](AGENT-DEPLOYMENT-WINDOWS-SERVER-2019.zh-CN.md) 的插件和业务验收。只出现微软登录链接、PID 或中继在线均不算迁移成功。

## 常见问题

| 情况 | 处理 |
| --- | --- |
| 无法判断认证方式 | 显式 `-Auth microsoft` 或 `offline`；Yggdrasil 另行适配 |
| 输出目录已存在 | 使用新的输出目录；工具不会强制覆盖 |
| 新 data 已存在 | 先停止并备份；不要清空旧缓存后再尝试 |
| 解码失败或中文乱码 | 确认源编码；必要时 `-Encoding gb18030` |
| 连接时版本不匹配 | 核对旧固定版本；转换时显式 `-Version auto` 或真实版本 |
| 原账号仍需要 `/login` | 这是服务器内认证，单独安全配置；Microsoft 密码不能用于它 |
| 首次仍让选择 Microsoft 账号 | 设备码网页允许选择账号；使用正确账号并核对返回游戏名 |
| 旧管理用户无权限 | 导入/确认插件 AdminWhitelist 和 Whitelist；旧 BotOwners 不自动映射 |
