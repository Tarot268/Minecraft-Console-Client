# Agent 全流程部署：Windows Server 2019 x64 + MCC 2.0 四插件控制台

版本：部署修订 `0.2.0-ws2019.2-lock-service`，生成日期 2026-10-16。此文件是本 Windows 完整包的部署入口，可独立交给另一位 Agent 执行。

## 1. 目标、边界与完成标准

目标是在全新 Windows Server 2019 x64 上，通过一个启动入口运行中继及网页，管理 1–10 台 MCC 终端。第一台为协调者，加载 bot-room、AutoResponder、ETPBot、TweakMCC；其它台加载 bot-room、ETPBot、TweakMCC。

包内包含应用及启动依赖，无须编译或安装全局开发工具。账号、实际服务器、业务白名单/传送点及首次 Microsoft 授权属于部署输入。只有完成相应层级验证，才能记录为通过：

| 层级 | 必须取得的证据 |
| --- | --- |
| 文件与 Windows 运行时 | ZIP SHA-256、清单检查、包内 dotnet 能列出两种 10.0.13 框架 |
| 控制台与中继 | 本机网页/`api/state` 可访问，`relay.connected=true` |
| 每台 MCC | 进程 running、relayOnline=true、gameOnline=true，真实游戏名匹配 |
| 插件 | 首台四插件、其它三插件均成功加载，etp 与 coordinator 执行器符合角色；TweakMCC 需另核对 `/plugins list` |
| 业务 | 在真实限制下逐项测试查询、权限、锁定、A/B、宝库、Tweak 操作及共存 |

不能因 PID、HTTP 200、中继在线或“Loaded plugin”单独出现就标记全部通过。没有账号持有者授权或测试场地时，将对应项目记录为待完成，并具体说明所缺输入。

本次构建和配置转换在 Linux 验证；四插件已有隔离 Minecraft 26.1.2 服务器证据。**Windows Server 2019 原生启动、此服务器的 Microsoft 授权与实际服务端行为尚需部署时验证。** 不要把历史 Linux 证据写成已通过 Windows 验收。

本修正另外完成 11 组实际 Luminol 26.1.2 验收：三个真实客户端、两台业务机器人、两轮原生宝库，详见 [锁定修正验收](VERIFICATION-LOCK-SERVICE.md) 与 `verification/lock-service-results.json`。已验证四类长任务跨锁定、真实中继拒绝请求、A 路线优先权恢复、队列新增任务继续延期，以及四把钥匙消耗和安全回位后才锁定；这仍不是十机器人或 Windows 原生验收。

## 2. 需要用户提供的输入

优先从用户已有配置读取，避免重复询问或重填：

| 输入 | 来源及校验 |
| --- | --- |
| 固定部署目录 | 如 `D:\MCC2`；本地磁盘，有读写权限，不能在 ZIP/网络临时目录直接运行 |
| 1–10 个真实机器人游戏名及顺序 | 每个 1–16 位字母/数字/下划线，不重复；首台是协调者，不可用邮箱代替 |
| 认证方式与旧配置 | Microsoft / offline；旧 INI/TOML 优先使用迁移工具；Yggdrasil 不自动转换 |
| 每台账号持有者 | Microsoft 首次授权需要持有者操作，不要求用户把密码交给 Agent |
| 主服务器地址/端口/版本 | 从旧配置迁移；确认旧固定版本是否仍适用 |
| 至少一位实际管理员 | 插件管理员与游戏内 OP 无关；不要沿用示例管理员 |
| 旧业务数据 | 普通/管理员/宝库名单、额度、传送点、位置收藏、译名映射及当前锁定状态 |
| 实服规则 | TrChat 私聊格式、消息长度与冷却，HuskHomes 指令、请求有效期、预热时长，B 所用 `/die` 是否存在 |
| 测试区域及物品 | 可用于传送、钥匙/宝库、放置、挖掘测试的授权区域与测试物品 |

已知本项目要求：遵循实际服务器聊天冷却，不允许使用冷却豁免；聊天最长 100 字符，当前发送间隔是服务端 2 秒加 0.5 秒余量。宝库期间仅允许已经完成相应开库并回位的机器人穿插 A；B 等待所有未完宝库任务结束。宝库运行中申请锁定须等全部已接收宝库任务及安全回位结束，新任务持续加入时继续等，并向操作者说明任务发起人。

本包接入 `lock-service-20261016` 修正，插件版本仍为 1.3.0；以 bundle-manifest 的补丁标识及文件 SHA-256 区分初版。四插件需一起更新。不要重复应用 source patch，也不要继续使用“手动锁定会暂停 Tweak”的旧断言。

| 状态 | TweakMCC 长任务与新操作 | ETPBot |
| --- | --- | --- |
| 未锁定 | 正常；ETP 请求到来后安全让出资源 | 保持优先权 |
| 手动锁定已生效 | 已有长任务继续，白名单用户仍可提交新操作 | 拒绝新任务且不申请抢占；锁前已开始的流程安全收尾 |
| 宝库待锁定 / 整队列预留 | 暂停冲突操作，查询和允许的停止仍可用 | 完成宝库整队列并安全回位后才正式锁定 |

解锁恢复 ETP 优先权，不自动取消 Tweak 长任务。死亡、断线、授权过期、白名单与库存异常保护继续生效。

## 3. 固定组件组合

| 组件 | 本包版本与位置 |
| --- | --- |
| 网页 + 中继 | Console 0.2.0，根目录 `MccConsole.dll` |
| MCC | EA Build 13，commit `add1cc842bf66a229bbf98065216445654710774`，本项目 `chatbots.2` 兼容构建 |
| MCC 入口 | `runtime\mcc-build13-chatbots\Mcc.Cli.dll` |
| DMCBK | `0.1.0-preview.8` |
| UMPK Client / Protocol.Java | 两者都为 `0.9.0-beta.7-chatbots.2` |
| 四插件 | bot-room / autoresponder / etpbot / tweakmcc，全部 1.3.0，位于 `assets\plugins` |
| 私有运行时 | .NET + ASP.NET Core 10.0.13 Windows x64，`runtime\dotnet\dotnet.exe` |
| 浏览器 | `installers\googlechromestandaloneenterprise64.msi`，Google 官方离线 x64 MSI，按需安装 |

MCC 是公开 Build 13 源码加本项目兼容补丁的构建，**不是官方未修改发布件**。来源、补丁、NuGet、许可证保留在 `compat\build13`。不可替换为官方 EA13 原 exe、beta.7 原库、chatbots.1 或其它版本来绕过插件校验。宿主入口是 DLL，私有 dotnet.exe 才是启动器。

官方来源：

- [MCC EA Build 13](https://github.com/MCCTeam/Minecraft-Console-Client/releases/tag/v2.0.0-early-access.13)
- [MCC 固定源码](https://github.com/MCCTeam/Minecraft-Console-Client/tree/add1cc842bf66a229bbf98065216445654710774)
- [UMPK 固定源码](https://github.com/MCCTeam/UMPK/tree/a1e743b48d526f5a7645b47ec48c10b65237edf9)
- [.NET 10 Windows Server 2019 x64 支持表](https://github.com/dotnet/core/blob/main/release-notes/10.0/supported-os.md)
- [.NET 10 官方发布元数据](https://builds.dotnet.microsoft.com/dotnet/release-metadata/10.0/releases.json)
- [Google Chrome 官方离线 x64 MSI](https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi)

`provenance` 内保存本次选定的发布元数据、官方 SHA-512 与原生 DLL 导入检查。ASP.NET Core 官方 ZIP 已含基础 .NET Runtime，本包不重复放两套。17 个原生 PE 文件没有额外 VC redistributable DLL 导入；使用 Windows Server 2019 自带 UCRT/系统 DLL，未捆绑单独 VC 安装器。若目标系统文件损坏，先修复系统，不从不明网站下载 DLL。

## 4. 解压与原生预检

以 `D:\MCC2` 为例；其它路径在全流程统一替换。先与随附 `SHA256SUMS` 比较整个 ZIP：

```powershell
Get-FileHash -LiteralPath 'D:\Downloads\mcc2-console-0.2.0-windows-server-2019-x64-complete-lock-service.zip' -Algorithm SHA256
Expand-Archive -LiteralPath 'D:\Downloads\mcc2-console-0.2.0-windows-server-2019-x64-complete-lock-service.zip' -DestinationPath 'D:\MCC2'
Set-Location 'D:\MCC2'
Set-ExecutionPolicy -Scope Process Bypass -Force
& .\tools\Test-Deployment.ps1
```

必须使用系统 64 位 PowerShell（`C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`）；从 32 位管理程序调用时使用 `Sysnative` 路径。预检验证 Windows Server Build >=17763、x64 进程、交付文件 SHA-256、私有运行时可执行及两种框架、MCC 兼容依赖版本。哈希校验失败时重新解压原包，不直接编辑 `bundle-manifest.json` 来让校验通过。

部署文件可放在带空格或中文的目录。PS 文件以带 BOM 的 UTF-8 打包，适用于 PowerShell 5.1；TOML 是 UTF-8。不要把启动脚本保存为 ANSI。若系统策略要求额外签名或管理员批准，只处理具体被阻止的项目，不修改全局执行策略或关闭安全软件。

确认存在 Edge/Chrome；IE 无法运行本网页。若没有，在**管理员** PowerShell 执行：

```powershell
& .\tools\Install-Browser.ps1
```

它先验证 MSI 哈希与 Google Authenticode 签名，再安装系统级 Chrome；不必安装 SDK。签名验证失败须检查系统时钟、证书和吊销检查网络，不能跳过验证。3010 仅表示安装完成且需要安排系统重启，工具不会自动重启服务器。已有现代浏览器无需重复安装。Server Core 无浏览器图形环境，可跳过安装，并用 `Start-Console.ps1 -NoBrowser`。

## 5. 创建配置：优先迁移旧文件

有旧 INI/TOML 时先完整阅读 [MCC 1.x 配置迁移教程](MCC1-TO-MCC2-MIGRATION.zh-CN.md)，执行转换并核对无敏感信息报告。例如：

```powershell
& .\tools\Convert-Mcc1Config.ps1 -InputFile 'D:\MCC1-private\EclipseAlpha.ini' -BotName 'EclipseAlpha' -Auth microsoft -OutputDirectory 'D:\MCC2-migration' -Version auto
& .\tools\Convert-Mcc1Config.ps1 -InputFile 'D:\MCC1-private\EclipseBeta.ini' -BotName 'EclipseBeta' -Auth microsoft -OutputDirectory 'D:\MCC2-migration' -Version auto
& .\tools\Initialize-Deployment.ps1 -BotNames @('EclipseAlpha','EclipseBeta') -AdminPlayers @('YourGameName') -MigrationRoot 'D:\MCC2-migration'
```

无旧配置时：

```powershell
& .\tools\Initialize-Deployment.ps1 -BotNames @('EclipseAlpha','EclipseBeta') -AdminPlayers @('YourGameName') -ServerAddress 'play.example.net:25565' -Authentication microsoft -MinecraftVersion auto
```

离线服明确使用 `-Authentication offline`；这不能连接需要正版认证的服务器。工具为新部署生成以下内容，不覆盖任何已存在的 data：

- `data\console.json`：绝对兼容宿主路径，实际 botNames，saved/main/suite，autoStart=false。
- 每台独立 `configurations\accounts.toml`、`servers.toml`、`client.toml`。
- 首台四插件、其它台三插件的 `plugins\userdata\插件名\settings.toml`。
- 协调者 `AdminWhitelist.txt` / `Whitelist.txt` 用输入管理员初始化；宝库额度初始为每人 10。
- 中继密钥及 bot-room 连接设置；不得把令牌写入部署报告。
- 十个唯一的 `TreasureRoleOrder`，不足十台用未上线的默认角色补足，BotWhitelist 与之对应。

**不要把 BotWhitelist 简化为当前在线的两台**，同时却保留十角色顺序。调度器通过中继可用性过滤未上线角色。修改 botNames、首台顺序或已有部署时，工具不会自动改写已有设置，应逐项同步角色、路由、身份与共享名单。

初始化后运行模式为 `saved`，因此邮箱等提示来自账号文件，而不是命令行重新填账号。用户授权后返回的游戏名必须与 botNames 一致。客户端账户 `Name` 是本地条目标签，`Login` 是邮箱或登录提示；它们不代替实际 Microsoft 个人资料身份。

迁移时若各台原服务器不同，先确认它们确实连接同一个可协作的游戏环境；共享中继不能让处于不同服务器的角色完成同一宝库/传送任务。

## 6. 导入业务数据并核对实服设置

正常停止控制台后，导入旧文件前先备份，不能把整个 1.x plugins 或 `.cs` 复制进新插件目录。协调者业务数据路径：

```text
data\bots\EclipseAlpha\plugins\userdata\autoresponder\data\
  AdminWhitelist.txt
  Whitelist.txt
  TreasureWhitelist.txt
  BotWhitelist.txt
  TeleportPoints.txt
  LocationCollection.txt
  entity_translations.txt
  missing_translations.txt
  lockedlist.txt
  PendingTreasureLocks.json
```

前三份分别是每行管理员、每行普通允许玩家、每行 `玩家名=剩余次数`；普通白名单合法空表在旧行为中意味着允许所有人，不要拿空文件表示拒绝所有人。管理员名单与普通名单分开核对。BotWhitelist 保留完整十角色登记。锁定记录不是每行一个名字，`lockedlist.txt` 使用 JSON 行记录，延期锁定使用 JSON；旧格式先查看 [四插件手册](DEPLOYMENT-FOUR-PLUGINS.zh-CN.md) 的导入规则再导入，不能粗暴转换为名字列表。

不识别的数据不要猜测；先保留原件并记录待迁移项。没有旧白名单时保留初始化名单，勿退回缺省示例玩家。TweakMCC 与 ETPBot 使用协调者的共享授权与锁定状态，不另建冲突名单。

重点核对：

| 文件 / 区段 | 必须确认 |
| --- | --- |
| AutoResponder `[Identity]`、每台 ETPBot `[Identity]`、bot-room `[Coordination]` | 同一个首台协调者；本机 BotName 与游戏名相同 |
| AutoResponder 与每台 ETPBot `[Deployment]` | 十角色顺序一致、无重复；路由 Bot 属于此顺序 |
| AutoResponder `[Deployment.Routes]` | A/B 目标、路由编号、玩家使用的传送点一致 |
| AutoResponder 与 TweakMCC 的私聊正则 | 从真实私聊确认，保留 sender/receiver/message 三个命名组；不要把公告当授权 |
| ETPBot `[ServerCommands]` | 实服 `/home`、`/back`、`/tpa`、`/tpahere`、`/tpaccept`；B 需 `/die` |
| 两业务插件 `[RouteQueue]` | 请求有效期、5 秒预热等与真实 HuskHomes 一致，Accepted/OperationComplete/Failed 正则匹配实服文本 |
| 所有 bot-room `[Chat]` | MaximumMessageCharacters=100，ServerCooldownMilliseconds=2000 + SafetyMarginMilliseconds=500 |
| 两业务插件 `[TreasureTasks]` | 同步配置，StartNextAfterReturnedBots=3（可改2）、RequireKeyConsumptionConfirmation=true、ProtectKeysFromDeath=false |
| ETPBot `[WorldInteraction]` | TreasureKeyItem 缺省为旧服绊线钩；如实际使用原版 trial_key/ominous_trial_key，按物品 ID 配置 |

读取 `assets\plugins\bot-room\defaults\settings.toml` 可核对本包真实配置键。若实服改了聊天冷却，只调整合理发送间隔，不能给机器人冷却豁免。手动服务器命令通过网页 `/send ...` 进入同一发送队列；未加 `/send` 的 `/room`、`/plugins` 等为 MCC 本地命令。

宝库流程模式名“普通/特殊”只是旧流程称呼，不代表本功能按原版普通宝库/不祥宝库自动分类。需以实际目标状态及钥匙配置验收。旧快速宝库功能已经删除，不恢复。

## 7. 启动、授权与真实上线

双击根目录 `start-console.cmd`，或在 PowerShell：

```powershell
& .\tools\Start-Console.ps1
```

后台包含中继，无需再开一个 BotRoom.Server，不要争抢同一端口。启动脚本只改变本进程的 DOTNET_ROOT 等变量，使用 `runtime\dotnet\dotnet.exe`；控制台会用同一程序启动每台 MCC。无全局 dotnet 也应可运行。默认地址是 `http://127.0.0.1:8787` / `ws://127.0.0.1:8787/room`。

先启动首台，不要一开始启动十台并混淆设备码。Microsoft 登录显示的验证码及网址交由账号持有者完成；不要在账号 TOML 或命令参数中写 Microsoft 密码。缓存位于每台 configurations 下的 cache。MCC 1.x SessionCache.db 与新 auth-tokens 不是可直接复制的格式。

若浏览器回调方式不适合远程部署，停机后把对应账号 Kind 改为 microsoft（设备码），保留 Login。若网页中无法完成交互，可仅停止这一台，使用同一 profile 和包内运行时单独登录：

```powershell
Set-Location 'D:\MCC2\data\bots\EclipseAlpha'
& 'D:\MCC2\runtime\dotnet\dotnet.exe' 'D:\MCC2\runtime\mcc-build13-chatbots\Mcc.Cli.dll' --configurations '.\configurations' --connection.auto-connect=false
# MCC 本地终端：/connect main
# 根据提示完成授权，核对账号；完成后输入 /exit，再回网页启动该台。
```

不能同时用网页和手工终端操作同一 profile。不要把设备码、令牌或完整 accounts.toml 附在报告中。

逐台完成后在另一窗口执行：

```powershell
Set-Location 'D:\MCC2'
& .\tools\Test-Deployment.ps1 -Online
```

核对每台 `processState=running`、`relayOnline=true`、`gameOnline=true`，etp=Ready；首台 coordinator=Ready。Busy 表示实际任务占用，不应靠强制停机来让它变成 Ready。网页终端输入 `/plugins list` 检查首台四个插件、其它三插件均为 1.3.0，特别是 TweakMCC。`api/state` 本身不能证明 TweakMCC 所有能力可用。

Windows 进程路径可私下用 CIM 核对：受管 dotnet.exe 应来自本包 runtime/dotnet，命令行应指向本包 Mcc.Cli.dll。只在报告写路径及版本结论，不打印任意其它进程的完整命令行。

## 8. 业务验收顺序

在获准的实服区域执行，保留每项操作者、时间、期望/实际结果及经过脱敏的相关日志。若 `/die`、测试钥匙或可测试宝库不存在，标为阻塞原因，不安装/修改服务端插件或赋 OP 来假装通过。

1. **只读查询与权限**：允许玩家查询，未授权玩家被拒绝；管理员名单正确；真实私聊正则工作。多用户同时查询，确认轮转与队列回复，100 字符、2.5 秒发送节奏可见，无丢单/串回复。
2. **单台 A 路线及排队**：完成回家、邀请、接受、预热、回位和结果反馈；两个用户排同一机器人按队列执行；拒绝、过期、用户离线的结果可解释，不误发给下一位。不能把预热调成 0。
3. **B 路线**：仅在无未完宝库任务且允许死亡的测试场景，确认 `/die`、复活、邀请、接受、回位。ProtectKeysFromDeath 默认关闭是用户选择；首次测试自行先保管贵重物品，不偷偷改配置来假称默认流程通过。
4. **锁定**：锁部分非首台、末台、仅余 1–2 台时仍正确接力/收尾。首台承担中枢功能，不要求测试锁住首台后宝库可运行。执行中发锁定：告知正处于宝库任务及发起人；当该机器人队列全部清空才生效，新增排队任务继续延迟；解锁可取消延期锁。
5. **宝库单轮及流水**：真实开启一个宝库并回位；钥匙消耗确认按配置检查。再测试两处邻近宝库，最近一轮有 3 台成功开库且回位后才允许下一轮；参与不足3台时门槛取实际数量。公告只显示“宝库开启任务已开始”，角色锁定信息由认证中继传输。
6. **宝库与传送共存**：已完成对应轮次并回位、当前空闲机器人可接 A；未完成/尚未回位的不抢占；B 在全部宝库任务结束前等待。配置关闭 B 钥匙保护也不能突破宝库期间的 B 禁止规则。
7. **TweakMCC**：共享白名单继续生效；分别在 Print、PeriodAttack、PeriodUse、AutoDig 启动后手动锁定，以新移除方块被补回、新出现实体被攻击、拉杆继续切换和真实挖掘完成证明任务仍执行。锁定后白名单用户的新操作应可用，未授权用户仍被拒绝。核对物品查询/换槽/副手/使用/丢弃与视角。持续放置默认不停，测试结束显式 `tweak.StopPrint`；挖掘显式停止。
8. **ETP 与 Tweak 共存及生命周期**：锁定已生效时提交 ETP 请求，确认既不执行也不抢占 Tweak；解锁后重发 A，确认 Tweak 安全让出资源、实服传送及回位后继续。宝库申请锁定后仍暂停 Tweak，后来加入队列的任务也计入等待；全部安全回位、待锁定正式生效后才恢复 Tweak。死亡/掉线/重启不重放旧任务。验证退出服务器后终端与中继可仍在线，但 gameOnline=false、游戏执行器不可用，不误认已能执行游戏动作。
9. **停止与再次启动**：任务结束后先逐台停止，日志为正常退出；再 Ctrl+C 停止控制台。再次启动使用原账号缓存、白名单、锁定/延期记录，不重放未完任务；异常中断的任务先人工核对后恢复服务。

十台全链验收只有实际十台均参与且取得证据才能写通过；用两台结果不能替代十台。可先完成两台基础验收，再按实际账号数量扩展。完整用户命令和配置意义见 `DEPLOYMENT-FOUR-PLUGINS.zh-CN.md` 与 `TWEAKMCC.md`，坐标示例不能直接用于生产区。

## 9. 运行、远程访问与维护

默认仅监听 loopback。通常通过服务器 RDP 打开浏览器；要从工作站访问，可在已有 SSH 服务上本地转发：

```text
ssh -L 8787:127.0.0.1:8787 user@your-windows-server
```

然后在工作站访问 `http://127.0.0.1:8787`。不要把监听改为 0.0.0.0 或直接放行 8787 公网端口；当前网页没有为公网提供独立账号登录。SSH 服务/外部反向代理不属于本包默认部署，不应为此擅改服务器网络策略。

启动窗口应保留；关闭浏览器不停止机器人。普通 RDP 断开通常保留进程，但注销、会话清理策略及服务器重启会结束它们。本包不自带 Windows 服务；不要声称已具备无人值守自动重启。用户要求长期托管时，再按其会话/服务方案处理，先完成交互授权和验收。

从初版 1.3.0 升级本修正：先停全部 MCC 及控制台，备份 data 和 assets/plugins，完整替换本包运行文件，再用原 data 启动；四插件一起换，账号与业务数据不重置。不要在已加载 DLL 的目录内直接覆盖再热重载。部署后运行预检并核对 manifest 的 `pluginHotfix=lock-service-20261016` 及 `assets/plugin-build.json` 的文件哈希，防止混入同版本初版。

停机后整体备份 `data`；其中包含账号缓存、私聊业务数据和中继令牌，仅限运行账户及授权管理员访问。更新时停止旧包、备份、解压完整新包、迁移 data，并在网页点击“使用随附兼容宿主”或修正 `console.json` 的绝对 mccPath。搬目录不会自动修正已有绝对路径。不可把旧 runtime 覆盖到新包，不混用四插件版本。

`Test-Deployment.ps1` 校验交付文件，不校验可变 data。用户可调 settings 应改 data 下对应副本，别改 assets defaults 来绕过完整性检查。启动时 ProfileBuilder 会管理 bot-room 连接/协调者段并保留其它段，业务 settings 已存在时不覆盖。

## 10. 故障处理与交付报告

| 现象 | 排查与处理 |
| --- | --- |
| 文件缺失/哈希失败 | 从原 ZIP 完整解压；检查杀毒隔离及磁盘，不拼凑单 DLL |
| 无全局 dotnet 命令 | 正常，本包使用私有 runtime/dotnet/dotnet.exe；不要因此要求装 SDK |
| dotnet.exe 本身不能执行 | x64、OS Build、系统更新/UCRT、文件权限；保存错误码，不下载来路不明系统 DLL |
| 端口占用/console.lock | 确认是否同一包已有实例，正常停止；不按端口直接杀死不明进程 |
| 初始化拒绝覆盖 data | 保留现有数据，停机备份；选择新 data，不能直接删除账号缓存 |
| 网页空白 | 使用 Edge/Chrome；检查本机地址、静态文件及浏览器控制台；不要用 IE |
| 无法远程访问 | 默认 loopback；RDP 或已有 SSH 转发，非默认公开服务 |
| 中继在线、游戏离线 | Microsoft 授权、真实账号、服务器版本、网络、服务器内登录、封禁/限流；插件离线存活不是游戏连接 |
| 兼容库版本报错 | 本包 chatbots.2 宿主和四插件整体一致，不能删除 VerifyRuntime |
| 用户无权限 | 真实私聊 sender、AdminWhitelist/Whitelist/宝库额度、共享政策同步 |
| 任务超时 | 原聊天/传送/宝库状态文本与正则、真实预热、排队资源；不能用冷却豁免或缩短服务端限制 |
| 钥匙检测停住 | 核对物品 ID、背包同步及宝库实际消耗；是否关闭确认由部署输入决定并同步两业务插件，不隐式更改默认 |
| Tweak 暂停/拒绝 | ETP 占用、宝库待锁定/预留、白名单/授权、背包不确定态、死亡/掉线；单纯手动锁定不应暂停，先核对是否四包均已更新 |

交付时写一份脱敏 Markdown 报告，包括：OS/架构/Build、部署路径、包 SHA-256 和组件版本、实际 BotName 与协调者、运行时与文件预检结果、每台进程/中继/游戏/插件状态、业务逐项通过或阻塞及证据文件、运行中的启动窗口/端口、备份位置及尚待账号持有者处理的事项。不要收录邮箱全文、密码、授权设备码、刷新令牌、room-secrets 内容或 accounts.toml 全文。
