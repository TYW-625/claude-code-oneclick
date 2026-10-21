# Claude Code 一键安装（Windows）

一个把 Claude Code 的 Windows 安装流程打包成“双击即装”的脚本。

- GitHub（主仓库）：<https://github.com/TYW-625/claude-code-oneclick>
- Gitee（国内镜像）：<https://gitee.com/tyw-0625/claude-code-oneclick>

流程参考 B 站 UP 主 **木子不写代码** 的
[《Claude Code 零基础终极教程》](https://www.bilibili.com/video/BV1TTR8BaEnL)：
Git → VS Code → Claude Code → CC Switch（换第三方模型）。

> 非官方项目，与 Anthropic 没有任何隶属关系。脚本只负责安装，不收集任何数据。

## 装什么

| 组件 | 作用 | 来源 |
|---|---|---|
| Git | Claude Code 用它做版本管理、回退改动 | 华为云镜像（MinGit 便携版，免管理员） |
| VS Code | 写代码和运行 Claude Code 扩展的编辑器 | winget / 官方安装包 |
| Claude Code 扩展 | 你日常使用的 Claude Code 界面 | VS Code 扩展市场 |
| CC Switch | 可视化切换 DeepSeek、Kimi、MiniMax 等供应商 | GitHub Release（便携版优先，需 4.0.0+） |

默认装的是 **VS Code 扩展**。扩展自带一份 Claude Code，不需要 Node.js。
如果你还想在任意终端里直接敲 `claude`，运行脚本时加 `-WithCLI`。

## 怎么用

### 方式一：双击

1. 下载本仓库（`Code` → `Download ZIP`，或 `git clone`）。
2. 双击 `install.bat`。
3. 按提示确认。

### 方式二：PowerShell

```powershell
git clone https://github.com/TYW-625/claude-code-oneclick.git
cd claude-code-oneclick
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

国内网络访问 GitHub 慢时，改用 Gitee 镜像：

```powershell
git clone https://gitee.com/tyw-0625/claude-code-oneclick.git
```

### 常用参数

| 参数 | 说明 |
|---|---|
| `-DryRun` | 只检查，不安装、不下载、不写文件 |
| `-Yes` | 跳过开始前的确认 |
| `-WithCLI` | 额外安装官方原生 CLI，让终端也能用 `claude` |
| `-NoPause` | 结束后不等待按键，适合自动化 |

示例：

```powershell
# 先看看自己缺什么
powershell -ExecutionPolicy Bypass -File .\install.ps1 -DryRun

# 装扩展 + 终端 CLI，无人值守
powershell -ExecutionPolicy Bypass -File .\install.ps1 -WithCLI -Yes
```

## 装完之后

1. 打开开始菜单里的 **CC Switch**。
2. 点右上角 `+`，选择供应商，填入自己的 API Key，点“启用”。
3. 重启 VS Code，点击侧边栏的 Claude 图标即可使用。
4. 如果装了 CLI：新开一个终端，运行 `claude` 或 `claude doctor` 自检。

## 扩展版和 CLI 版有什么区别

| | VS Code 扩展（默认） | 原生 CLI（`-WithCLI`） |
|---|---|---|
| 装在哪 | `.vscode\extensions\anthropic.claude-code-*\resources\native-binary\claude.exe` | `%USERPROFILE%\.local\bin\claude.exe` |
| 终端能敲 `claude` 吗 | 不能 | 能 |
| 怎么更新 | 跟着 VS Code 扩展自动更新 | 安装器自动后台更新 |
| 依赖 Node.js | 不需要 | 不需要 |

两者可以共存，配置文件都在 `%USERPROFILE%\.claude` 下。
如果两边的版本不一致，遇到“扩展里有、终端里没有”的功能时，先看版本。

> 旧教程里的 `npm install -g @anthropic-ai/claude-code` 属于遗留方式，
> 官方已推荐改用原生安装器。

## 国内网络

- 仓库本身在 Gitee 有镜像，克隆慢时可以从 <https://gitee.com/tyw-0625/claude-code-oneclick> 拉。
- GitHub 直连失败时，脚本会自动尝试 `gh-proxy.com` 和 `ghproxy.net` 镜像。
- winget 下载慢属于正常现象，脚本会在失败后改用官方安装包。
- CC Switch 只从 GitHub Release 下载，不信任任何第三方下载站。

## 常见问题

**Q：提示“无法加载文件，因为在此系统上禁止运行脚本”**
双击 `install.bat` 即可，它已经带上 `-ExecutionPolicy Bypass`。
或者在 PowerShell 里手动加同样参数。

**Q：`winget` 找不到**
需要 Windows 10 1809+，并从 Microsoft Store 更新“应用安装程序”。
没有 winget 时脚本会退回到官方安装包；Git 仍失败就按提示手动安装。

**Q：装完终端里还是没有 `claude`**
默认装的是扩展，扩展不写 PATH。重新运行并加 `-WithCLI`。

**Q：CC Switch 打不开 / 提示不安全**
只从 [官方 Releases](https://github.com/farion1231/cc-switch/releases) 下载。
Windows 首次运行可能被 SmartScreen 拦截，点“更多信息 → 仍要运行”。

**Q：脚本会不会上传我的 API Key**
不会。脚本不读取、不写入、不上传任何密钥；供应商配置请在 CC Switch 界面里自己填。

## 卸载

| 组件 | 卸载方式 |
|---|---|
| Git / VS Code | 设置 → 应用 → 已安装的应用 |
| Claude Code 扩展 | VS Code 扩展面板 → 卸载 |
| Claude Code CLI | 删除 `%USERPROFILE%\.local\bin\claude.exe` 及同目录相关文件 |
| CC Switch | 删除 `%LOCALAPPDATA%\Programs\CC Switch` 和开始菜单快捷方式 |

## 更新日志

### v1.0.2（2026-10-21）

**全流程改为免管理员安装**，并修掉一个必然装错架构的硬伤。

- **Git 改走华为云镜像 + MinGit 便携版**。此前从 GitHub Release 下载安装包，国内普遍失败，而且安装程序需要管理员权限。现在下载 `MinGit-*-64-bit.zip`，解压到 `%LOCALAPPDATA%\Programs\Git` 并写入用户 PATH，全程不弹 UAC。
- **修复 CC Switch 在 x64 电脑上下 ARM64 包**。此前用 `Windows.*Portable` 通配后取第一个匹配项，而发布页里 arm64 排在最前，所以 x64 机器必定下到 arm64 版本，装了也跑不起来。现在按 `PROCESSOR_ARCHITECTURE` 精确匹配架构。
- **修复 VS Code 已装成功却报失败**。winget 显示安装成功后，`code.cmd` 落盘还有延迟，脚本立刻判断就找不到命令，还误报成「winget 没有装上」。现在会重试约 12 秒，文案也改成「未找到 code 命令」。
- 安装 CC Switch 便携版、VS Code 用户安装、VS Code 扩展安装均不需要管理员权限。

### v1.0.1（2026-10-21）

修复「电脑上已经装过旧版 CC Switch」时最后一步接不上的问题。

- **CC Switch 增加最低版本要求 4.0.0**。此前脚本只要发现电脑上装了 CC Switch 就直接跳过，只把版本号打印出来，从不比对；3.x 与 4.x 配置格式不兼容，装旧版会导致最后一步配不通。现在低于 4.0.0 会自动升级，版本号读不出来也会重装。
- **下载改为镜像优先**。此前 GitHub 直连排在最前，受限网络下要挂满 180 秒才轮到镜像，表现就是「卡住不动」。现在 gh-proxy / ghproxy 优先，直连放到最后。
- **下载超时从 180 秒降到 30 秒**，网络不通时快速失败并换下一个源。
- **修复开始菜单快捷方式路径不一致**。创建时写到 `Programs\CC Switch.lnk`，查找时读的却是 `Programs\CC Switch\CC Switch.lnk`；升级后旧快捷方式仍指向旧版本。现在两个位置都会更新。

### v1.0.0（2026-10-19）

首个版本：Git → VS Code → Claude Code 扩展 → CC Switch。

## 许可

[MIT](LICENSE)

## English

A Windows one-click installer for Claude Code, following a Chinese Bilibili
tutorial. It installs Git, VS Code, the Claude Code extension, and CC Switch.
Use `-WithCLI` if you also want the `claude` command in your terminal.
Unofficial project; not affiliated with Anthropic.
