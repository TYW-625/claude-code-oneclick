#Requires -Version 5.1
<#
.SYNOPSIS
    Claude Code 一键安装脚本（Windows）

.DESCRIPTION
    复刻 B 站「木子不写代码」安装教程的流程：
        Git -> VS Code -> Claude Code 扩展 -> CC Switch

    默认安装 VS Code 扩展（脚本作者本人常用的方式）。
    如果还需要在任意终端里使用 claude 命令，请加 -WithCLI。

    本脚本是非官方工具，与 Anthropic 没有任何隶属关系。

.PARAMETER DryRun
    只检测，不安装、不下载、不写文件。

.PARAMETER Yes
    跳过开始前的确认提示。

.PARAMETER WithCLI
    额外安装官方原生 CLI，让终端也能直接运行 claude。

.PARAMETER NoPause
    结束后不等待按键（适合自动化调用）。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -DryRun

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -WithCLI -Yes
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Yes,
    [switch]$WithCLI,
    [switch]$NoPause
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch { }

$script:LogPath = Join-Path $env:TEMP ("claude-code-oneclick-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
$script:Results = New-Object System.Collections.ArrayList
$script:HasFailure = $false

# CC Switch 最低可用版本。低于此版本的已安装副本会被升级，而不是跳过。
# 3.x 与 4.x 配置格式不兼容，装错版本会在最后一步接不上。
$script:MinCCSwitchVersion = [version]'4.0.0'

# ---------------------------------------------------------------- 输出与日志

function Write-Ui {
    param(
        [string]$Message,
        [string]$Color = 'Gray',
        [string]$Level = 'INFO'
    )
    Write-Host $Message -ForegroundColor $Color
    try {
        Add-Content -Path $script:LogPath -Value ("[{0:HH:mm:ss}] [{1}] {2}" -f (Get-Date), $Level, $Message) -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch { }
}

function Write-Step {
    param([int]$Index, [int]$Total, [string]$Text)
    Write-Ui ""
    Write-Ui ("[{0}/{1}] {2}" -f $Index, $Total, $Text) 'Cyan'
}

function Write-Info { param([string]$Text) Write-Ui ("      " + $Text) 'Gray' }
function Write-Ok   { param([string]$Text) Write-Ui ("  OK  " + $Text) 'Green' }
function Write-Warn { param([string]$Text) Write-Ui ("  !!  " + $Text) 'Yellow' 'WARN' }
function Write-Err  { param([string]$Text) Write-Ui ("  XX  " + $Text) 'Red' 'ERROR' }

function Add-Result {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Version = '',
        [string]$Path = ''
    )
    [void]$script:Results.Add([pscustomobject]@{
        Component = $Name
        Status    = $Status
        Version   = $Version
        Location  = $Path
    })
}

# ---------------------------------------------------------------- 基础工具

function Test-DryRun {
    return [bool]$DryRun
}

function Update-SessionPath {
    # 把注册表里的 Machine/User PATH 合并进当前会话，
    # 否则刚装完的程序在本窗口里仍然“找不到”。
    $parts = @()
    foreach ($scope in @('Machine', 'User')) {
        try {
            $value = [Environment]::GetEnvironmentVariable('Path', $scope)
            if ($value) { $parts += ($value -split ';') }
        } catch { }
    }

    $known = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin'),
        (Join-Path $env:USERPROFILE '.local\bin')
    )
    $parts += $known

    $current = @($env:Path -split ';')
    foreach ($p in $parts) {
        $p = $p.Trim()
        if ($p -and ($current -notcontains $p)) {
            $env:Path = $env:Path.TrimEnd(';') + ';' + $p
            $current += $p
        }
    }
}

function Get-ToolVersion {
    param([string]$Name, [string]$VersionArg)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cmd) { return $null }
    try {
        $out = & $cmd.Source $VersionArg 2>$null | Select-Object -First 1
        if ($out) { return ([string]$out).Trim() }
    } catch { }
    return $null
}

function Get-CodeCommand {
    $cmd = Get-Command 'code' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin\code.cmd'),
        (Join-Path $env:ProgramFiles 'Microsoft VS Code\bin\code.cmd')
    )
    if (${env:ProgramFiles(x86)}) {
        $candidates += (Join-Path ${env:ProgramFiles(x86)} 'Microsoft VS Code\bin\code.cmd')
    }
    foreach ($p in $candidates) {
        if ($p -and (Test-Path $p)) { return $p }
    }
    return $null
}

function Get-GitHubRelease {
    param([string]$Repo)

    $api = "https://api.github.com/repos/$Repo/releases/latest"
    # 镜像优先：GitHub 直连在受限网络下会挂满超时，放在最后快速失败。
    $urls = @(
        "https://gh-proxy.com/$api",
        "https://ghproxy.net/$api",
        $api
    )
    foreach ($u in $urls) {
        try {
            $r = Invoke-RestMethod -Uri $u -Headers @{ 'User-Agent' = 'claude-code-oneclick' } -TimeoutSec 20 -UseBasicParsing
            if ($r -and $r.tag_name) { return $r }
        } catch { }
    }
    return $null
}

function Get-AssetUrls {
    param($Asset)
    $base = $Asset.browser_download_url
    # 镜像优先：受限网络下 GitHub 直连会长时间挂起，放最后。
    return @(
        "https://gh-proxy.com/$base",
        "https://ghproxy.net/$base",
        $base
    )
}

function Save-FileWithMirrors {
    param([string[]]$Urls, [string]$Destination)

    foreach ($u in $Urls) {
        try {
            Write-Info ("下载: " + $u)
            Invoke-WebRequest -Uri $u -OutFile $Destination -UseBasicParsing -TimeoutSec 30
            if ((Test-Path $Destination) -and ((Get-Item $Destination).Length -gt 1024)) {
                return $true
            }
        } catch {
            Write-Warn ("下载失败: " + $_.Exception.Message)
        }
    }
    return $false
}

function Invoke-WingetInstall {
    param([string]$Id, [string]$Scope)

    $winget = Get-Command 'winget' -ErrorAction SilentlyContinue
    if (-not $winget) { return $false }

    $arguments = @(
        'install', '--id', $Id, '-e',
        '--source', 'winget',
        '--accept-package-agreements',
        '--accept-source-agreements',
        '--disable-interactivity'
    )
    if ($Scope) { $arguments += @('--scope', $Scope) }

    Write-Info ("winget install " + $Id + $(if ($Scope) { " (scope=" + $Scope + ")" } else { "" }))
    & $winget.Source @arguments 2>&1 | ForEach-Object { Write-Info ([string]$_) }

    Update-SessionPath
    return ($LASTEXITCODE -eq 0)
}

# ---------------------------------------------------------------- Git

function Install-Git {
    $version = Get-ToolVersion 'git' '--version'
    if ($version) {
        Write-Ok ("已安装，跳过: " + $version)
        Add-Result 'Git' '已安装' $version (Get-Command git).Source
        return $true
    }

    if (Test-DryRun) {
        Write-Info '未检测到 Git，将尝试安装'
        Add-Result 'Git' '待安装' '' ''
        return $true
    }

    $ok = Invoke-WingetInstall 'Git.Git' 'user'
    if (-not $ok) { $ok = Invoke-WingetInstall 'Git.Git' $null }

    $version = Get-ToolVersion 'git' '--version'
    if (-not $version) {
        Write-Warn 'winget 没有装上，尝试从 GitHub 下载安装包（走镜像）'
        $release = Get-GitHubRelease 'git-for-windows/git'
        $asset = $null
        if ($release) {
            $asset = $release.assets | Where-Object { $_.name -match '^Git-.*64-bit\.exe$' } | Select-Object -First 1
        }
        if ($asset) {
            $installer = Join-Path $env:TEMP $asset.name
            if (Save-FileWithMirrors -Urls (Get-AssetUrls $asset) -Destination $installer) {
                Write-Info '运行 Git 安装程序（可能弹出 UAC）...'
                Start-Process -FilePath $installer -ArgumentList '/VERYSILENT', '/NORESTART', '/NOCANCEL', '/SP-' -Wait
                Update-SessionPath
            }
        }
    }

    $version = Get-ToolVersion 'git' '--version'
    if ($version) {
        Write-Ok ("安装成功: " + $version)
        Add-Result 'Git' '安装成功' $version (Get-Command git).Source
        return $true
    }

    Write-Err 'Git 安装失败'
    Write-Info '手动安装: https://git-scm.com/download/win'
    Add-Result 'Git' '失败' '' ''
    $script:HasFailure = $true
    return $false
}

# ---------------------------------------------------------------- VS Code

function Install-VSCode {
    $codeCmd = Get-CodeCommand
    if ($codeCmd) {
        $version = Get-ToolVersion 'code' '--version'
        Write-Ok ("已安装，跳过: VS Code " + $version)
        Add-Result 'VS Code' '已安装' $version $codeCmd
        return $true
    }

    if (Test-DryRun) {
        Write-Info '未检测到 VS Code，将尝试安装'
        Add-Result 'VS Code' '待安装' '' ''
        return $true
    }

    $ok = Invoke-WingetInstall 'Microsoft.VisualStudioCode' 'user'

    Update-SessionPath
    $codeCmd = Get-CodeCommand
    if (-not $codeCmd) {
        Write-Warn 'winget 没有装上，改为官方安装包'
        $installer = Join-Path $env:TEMP 'vscode-user-setup.exe'
        $urls = @(
            'https://update.code.visualstudio.com/latest/win32-x64-user/stable',
            'https://update.code.visualstudio.com/latest/win32-user/stable'
        )
        if (Save-FileWithMirrors -Urls $urls -Destination $installer) {
            Write-Info '运行 VS Code 安装程序...'
            Start-Process -FilePath $installer -ArgumentList '/VERYSILENT', '/NORESTART', '/MERGETASKS=!runcode' -Wait
            Update-SessionPath
        }
    }

    Update-SessionPath
    $codeCmd = Get-CodeCommand
    $version = Get-ToolVersion 'code' '--version'
    if ($codeCmd -and $version) {
        Write-Ok ("安装成功: VS Code " + $version)
        Add-Result 'VS Code' '安装成功' $version $codeCmd
        return $true
    }

    Write-Err 'VS Code 安装失败'
    Write-Info '手动安装: https://code.visualstudio.com/'
    Add-Result 'VS Code' '失败' '' ''
    $script:HasFailure = $true
    return $false
}

# ---------------------------------------------------------------- Claude Code 扩展

function Install-ClaudeExtension {
    $codeCmd = Get-CodeCommand
    if (-not $codeCmd) {
        Write-Err '找不到 code 命令，无法安装扩展'
        Add-Result 'Claude Code 扩展' '失败' '' ''
        $script:HasFailure = $true
        return $false
    }

    try {
        $installed = & $codeCmd --list-extensions --show-versions 2>$null
    } catch {
        $installed = @()
    }

    $match = @($installed) | Where-Object { $_ -match '^anthropic\.claude-code@' } | Select-Object -First 1
    if ($match) {
        $version = ($match -split '@')[-1]
        Write-Ok ("已安装，跳过: Claude Code 扩展 " + $version)
        Add-Result 'Claude Code 扩展' '已安装' $version 'VS Code'
        return $true
    }

    if (Test-DryRun) {
        Write-Info '未检测到 Claude Code 扩展，将尝试安装'
        Add-Result 'Claude Code 扩展' '待安装' '' ''
        return $true
    }

    Write-Info 'code --install-extension anthropic.claude-code'
    & $codeCmd --install-extension 'anthropic.claude-code' --force 2>&1 | ForEach-Object { Write-Info ([string]$_) }

    try {
        $installed = & $codeCmd --list-extensions --show-versions 2>$null
    } catch {
        $installed = @()
    }
    $match = @($installed) | Where-Object { $_ -match '^anthropic\.claude-code@' } | Select-Object -First 1

    if ($match) {
        $version = ($match -split '@')[-1]
        Write-Ok ("安装成功: Claude Code 扩展 " + $version)
        Add-Result 'Claude Code 扩展' '安装成功' $version 'VS Code'
        return $true
    }

    Write-Err 'Claude Code 扩展安装失败'
    Write-Info '也可以在 VS Code 扩展市场搜索 "Claude Code" 手动安装'
    Add-Result 'Claude Code 扩展' '失败' '' ''
    $script:HasFailure = $true
    return $false
}

# ---------------------------------------------------------------- 可选：原生 CLI

function Install-ClaudeCLI {
    $version = Get-ToolVersion 'claude' '--version'
    if (-not $version) {
        $exe = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
        if (Test-Path $exe) {
            try { $version = (& $exe --version 2>$null | Select-Object -First 1) } catch { }
        }
    }

    if ($version) {
        Write-Ok ("已安装，跳过: " + $version)
        Add-Result 'Claude Code CLI' '已安装' ([string]$version).Trim() 'PATH'
        return $true
    }

    if (Test-DryRun) {
        Write-Info '未检测到 Claude Code CLI，将尝试安装'
        Add-Result 'Claude Code CLI' '待安装' '' ''
        return $true
    }

    Write-Info '运行官方安装脚本: https://claude.ai/install.ps1'
    try {
        $script = Invoke-RestMethod -Uri 'https://claude.ai/install.ps1' -UseBasicParsing -TimeoutSec 60
        Invoke-Expression $script
    } catch {
        Write-Warn ("官方脚本失败: " + $_.Exception.Message)
        Write-Info '尝试 winget 安装 Anthropic.ClaudeCode'
        [void](Invoke-WingetInstall 'Anthropic.ClaudeCode' $null)
    }

    Update-SessionPath
    $version = Get-ToolVersion 'claude' '--version'
    if (-not $version) {
        $exe = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
        if (Test-Path $exe) {
            try { $version = (& $exe --version 2>$null | Select-Object -First 1) } catch { }
        }
    }

    if ($version) {
        Write-Ok ("安装成功: " + ([string]$version).Trim())
        Add-Result 'Claude Code CLI' '安装成功' ([string]$version).Trim() 'PATH'
        return $true
    }

    Write-Err 'Claude Code CLI 安装失败'
    Write-Info '手动安装: https://claude.ai/install.ps1'
    Add-Result 'Claude Code CLI' '失败' '' ''
    $script:HasFailure = $true
    return $false
}

# ---------------------------------------------------------------- CC Switch

function Get-CCSwitchExe {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\CC Switch\cc-switch.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\cc-switch\cc-switch.exe'),
        (Join-Path $env:ProgramFiles 'CC Switch\cc-switch.exe')
    )
    if (${env:ProgramFiles(x86)}) {
        $candidates += (Join-Path ${env:ProgramFiles(x86)} 'CC Switch\cc-switch.exe')
    }

    foreach ($p in $candidates) {
        if ($p -and (Test-Path $p)) { return $p }
    }

    # 兜底：读开始菜单快捷方式
    $lnk = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\CC Switch\CC Switch.lnk'
    if (Test-Path $lnk) {
        try {
            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut($lnk)
            if ($shortcut.TargetPath -and (Test-Path $shortcut.TargetPath)) {
                return $shortcut.TargetPath
            }
        } catch { }
    }

    return $null
}

function New-CCSwitchShortcut {
    param([string]$ExePath)

    $menuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
    if (-not (Test-Path $menuDir)) {
        New-Item -ItemType Directory -Path $menuDir -Force | Out-Null
    }

    # 两个位置都写：
    #  1) Programs\CC Switch\CC Switch.lnk —— Get-CCSwitchExe 的兜底查找路径
    #  2) Programs\CC Switch.lnk         —— 老版本脚本留下的位置
    # 一并覆盖，避免升级后旧快捷方式还指向旧 exe。
    $targets = @(
        (Join-Path $menuDir 'CC Switch\CC Switch.lnk'),
        (Join-Path $menuDir 'CC Switch.lnk')
    )

    $shell = New-Object -ComObject WScript.Shell
    foreach ($lnkPath in $targets) {
        $dir = Split-Path -Parent $lnkPath
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        $shortcut = $shell.CreateShortcut($lnkPath)
        $shortcut.TargetPath = $ExePath
        $shortcut.WorkingDirectory = Split-Path -Parent $ExePath
        $shortcut.Description = 'CC Switch - Claude Code 供应商切换器'
        $shortcut.Save()
        Write-Ok ('已更新开始菜单快捷方式: ' + $lnkPath)
    }
}

function Install-CCSwitch {
    $exe = Get-CCSwitchExe
    $version = ''
    $installed = $null

    if ($exe) {
        try { $version = [string](Get-Item $exe).VersionInfo.ProductVersion } catch { }
        if ($version) {
            try { $installed = [version]$version } catch { $installed = $null }
        }

        if ($installed -and $installed -ge $script:MinCCSwitchVersion) {
            Write-Ok ('已安装且版本合格，跳过: CC Switch ' + $version)
            Add-Result 'CC Switch' '已安装' $version $exe
            return $true
        }

        if ($installed) {
            Write-Warn ('CC Switch ' + $version + ' 低于最低要求 ' + $script:MinCCSwitchVersion + '，将升级')
        } else {
            Write-Warn '无法识别已安装 CC Switch 的版本，将重新安装'
        }
    }

    if (Test-DryRun) {
        if ($exe) {
            Write-Info ('将升级 CC Switch ' + $version + ' -> 最新版')
            Add-Result 'CC Switch' '待升级' $version $exe
        } else {
            Write-Info '未检测到 CC Switch，将尝试安装'
            Add-Result 'CC Switch' '待安装' '' ''
        }
        return $true
    }

    Write-Info '查询 CC Switch 最新版本...'
    $release = Get-GitHubRelease 'farion1231/cc-switch'
    if (-not $release) {
        Write-Err '查询 GitHub Release 失败（网络被拦截）'
        Write-Info '手动下载: https://github.com/farion1231/cc-switch/releases'
        Add-Result 'CC Switch' '需手动' '' ''
        $script:HasFailure = $true
        return $false
    }

    $version = [string]$release.tag_name
    Write-Info ('最新版本: ' + $version)

    $zipAsset = $release.assets | Where-Object { $_.name -match 'Windows.*Portable.*\.zip$' -or $_.name -match 'portable.*windows.*\.zip$' } | Select-Object -First 1
    $msiAsset = $release.assets | Where-Object { $_.name -match 'Windows.*\.msi$' } | Select-Object -First 1

    $ok = $false

    if ($zipAsset) {
        $zipPath = Join-Path $env:TEMP $zipAsset.name
        if (Save-FileWithMirrors -Urls (Get-AssetUrls $zipAsset) -Destination $zipPath) {
            $installDir = Join-Path $env:LOCALAPPDATA 'Programs\CC Switch'
            New-Item -ItemType Directory -Path $installDir -Force | Out-Null
            Write-Info ('解压到: ' + $installDir)
            try {
                Expand-Archive -Path $zipPath -DestinationPath $installDir -Force
                $exeItem = Get-ChildItem -Path $installDir -Recurse -Filter 'cc-switch.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($exeItem) {
                    New-CCSwitchShortcut -ExePath $exeItem.FullName
                    $ok = $true
                    $exe = $exeItem.FullName
                }
            } catch {
                Write-Warn ('解压失败: ' + $_.Exception.Message)
            }
        }
    }

    if (-not $ok -and $msiAsset) {
        Write-Warn '便携版失败，改用 MSI（会弹出 UAC）'
        $msiPath = Join-Path $env:TEMP $msiAsset.name
        if (Save-FileWithMirrors -Urls (Get-AssetUrls $msiAsset) -Destination $msiPath) {
            try {
                $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/i', ('"' + $msiPath + '"'), '/qn', '/norestart') -Verb RunAs -Wait -PassThru
                if ($process.ExitCode -eq 0) {
                    $exe = Get-CCSwitchExe
                    $ok = [bool]$exe
                }
            } catch {
                Write-Warn ('MSI 安装失败: ' + $_.Exception.Message)
            }
        }
    }

    if ($ok) {
        Write-Ok ('安装成功: CC Switch ' + $version)
        Add-Result 'CC Switch' '安装成功' $version $exe
        return $true
    }

    Write-Err 'CC Switch 安装失败'
    Write-Info '手动下载: https://github.com/farion1231/cc-switch/releases'
    Add-Result 'CC Switch' '失败' $version ''
    $script:HasFailure = $true
    return $false
}

# ---------------------------------------------------------------- 汇总

function Show-Summary {
    Write-Ui ""
    Write-Ui '================ 安装结果 ================' 'Cyan'
    foreach ($item in $script:Results) {
        $line = '  - ' + $item.Component + '：' + $item.Status
        if ($item.Version) { $line += '（' + $item.Version + '）' }
        if ($item.Location) { $line += ' ' + $item.Location }
        Write-Ui $line
    }

    Write-Ui '================ 下一步 ================' 'Cyan'
    Write-Ui '1. 打开开始菜单里的 CC Switch，点右上角 + 添加供应商，填入 API Key 后点“启用”。'
    Write-Ui '2. 重启 VS Code，点击侧边栏的 Claude 图标开始使用。'
    if ($WithCLI) {
        Write-Ui '3. 打开一个新的终端，运行 claude 或 claude doctor 自检。'
    } else {
        Write-Ui '3. 如果以后需要在终端里用 claude，重新运行本脚本并加上 -WithCLI。'
    }
    Write-Ui ''
    Write-Ui ('完整日志: ' + $script:LogPath) 'DarkGray'
    Write-Ui ''
}

# ---------------------------------------------------------------- 主流程

Write-Ui ''
Write-Ui '  Claude Code 一键安装（Windows）' 'Cyan'
Write-Ui '  Git -> VS Code -> Claude Code 扩展 -> CC Switch' 'DarkGray'
Write-Ui ('  日志: ' + $script:LogPath) 'DarkGray'
if ($DryRun) {
    Write-Ui '  模式: 仅检测（DryRun），不会安装任何东西' 'Yellow'
}
Write-Ui ''

Update-SessionPath

if (-not $Yes -and -not $DryRun) {
    $answer = Read-Host '即将开始安装，是否继续？[Y/n]'
    if ($answer -match '^\s*[nN]') {
        Write-Ui '已取消。' 'Yellow'
        if (-not $NoPause -and [Environment]::UserInteractive) { [void](Read-Host '按 Enter 退出') }
        exit 0
    }
}

$total = 4
if ($WithCLI) { $total = 5 }

$index = 0
$index++; Write-Step $index $total '检查并安装 Git'
[void](Install-Git)

$index++; Write-Step $index $total '检查并安装 VS Code'
[void](Install-VSCode)

$index++; Write-Step $index $total '检查并安装 Claude Code 扩展'
[void](Install-ClaudeExtension)

if ($WithCLI) {
    $index++; Write-Step $index $total '检查并安装 Claude Code CLI'
    [void](Install-ClaudeCLI)
}

$index++; Write-Step $index $total '检查并安装 CC Switch'
[void](Install-CCSwitch)

Show-Summary

if ($script:HasFailure) {
    Write-Ui '有组件没有装成功，请按上面的提示手动处理。' 'Yellow'
}

if (-not $NoPause -and [Environment]::UserInteractive) {
    [void](Read-Host '按 Enter 退出')
}

if ($script:HasFailure) { exit 1 }
exit 0
