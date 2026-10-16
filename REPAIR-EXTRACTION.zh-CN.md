# Windows Server 2019 解压故障修复

修复标识：`extraction-repair-20261016.1`。

## 适用情况

旧版 `Expand-CompletePackage.ps1` 在解压阶段报告 `assets\plugin-build.json` 路径不存在，或因 GitHub 下载目录层级太深而无法完成解压。

原始完整 ZIP 内确实包含该文件。用户报告目录下的最长运行时路径达到 310 字符；该包也没有显式 ZIP 目录条目。修复后的工具使用 .NET ZIP 解压器，提前检查输出路径长度，并检查全部 569 个文件是否已提取。具体的旧解压器失败点尚未在原生 Windows 系统复现。

## 已下载旧包时的操作

1. 下载 `mcc2-extraction-fix-20261016.zip`，解压其中的文件。
2. 将补丁中的 `Expand-CompletePackage.ps1` 和 `Extract-Complete-Package.cmd` 复制到原来含 `parts` 和 `package-parts.json` 的目录，替换同名脚本。保留已有分段、配置和还原出的原始 ZIP，不需要重新下载大包。
3. 重新双击 `Extract-Complete-Package.cmd`。默认目标为 `%USERPROFILE%\MCC2`，在 Administrator 账号下通常是 `C:\Users\Administrator\MCC2`。
4. 只有显示 `Ready:` 和 `Verified extracted files: 569` 后，才使用所显示的目录继续部署。之前中途失败的 `mcc2-console-complete` 目录不可作为完整部署使用。

目标目录已经存在时，脚本会停止，不覆盖文件。在原下载目录的地址栏输入 `powershell` 并回车，然后执行下列命令可选择新的短目录：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Expand-CompletePackage.ps1 -DestinationPath 'C:\MCC2-New'
```

原始 ZIP 已经移动到其它位置时，可以只使用修复脚本和这个 ZIP：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Expand-CompletePackage.ps1 -PackagePath 'D:\Downloads\mcc2-console-0.2.0-windows-server-2019-x64-complete-lock-service.zip' -DestinationPath 'D:\MCC2'
```

`-DestinationPath` 指向的目录必须不存在。脚本会先检查已有 ZIP 的大小和固定 SHA256；有效 ZIP 可直接复用，无需分段文件。无效 ZIP 不会被覆盖或删除。提取只在新建的临时目录执行，检查完成后才移动到最终目录。

该修复不需要修改注册表、安装 SDK、变更全局执行策略或更新任何 MCC / 插件二进制文件。原始 ZIP 的 SHA256 仍为：

```text
83c8a966c599b86060fb3130bb5aa68ce8c2edad2dd77aeded061f607ca2b994
```

Windows PowerShell 5.1 语法与 .NET Framework API 为兼容目标；本次自动测试在 Linux PowerShell 7.5.4 执行，不能代替 Windows Server 2019 原生验收。请以目标服务器实际运行结果为准。
