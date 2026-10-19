# 仓库介绍

## 一句话版（填 Gitee / GitHub 的“仓库介绍”）

Windows 一键安装 Claude Code：自动装 Git、VS Code、Claude Code 扩展和 CC Switch，支持国内镜像兜底，不碰 API Key。

## 短介绍（发帖、群里分享）

做了个 Windows 版 Claude Code 一键安装脚本。双击 `install.bat`，自动装 Git、VS Code、Claude Code 扩展和 CC Switch；GitHub 下载失败会自动走镜像。默认装扩展版，需要终端 `claude` 命令就加 `-WithCLI`。脚本可以重复运行，支持 `-DryRun` 预检，不读取也不写入任何 API Key。

## 完整介绍

### 这是什么

一个 Windows 上的 PowerShell 安装脚本，把 Claude Code 的安装流程压缩成“双击一次”。

流程参考 B 站 UP 主 **木子不写代码** 的
[《Claude Code 零基础终极教程》](https://www.bilibili.com/video/BV1TTR8BaEnL)：
Git → VS Code → Claude Code → CC Switch（换第三方模型）。

### 为什么做

国内装 Claude Code 常见的坑：

- 不知道要先装 Git 和 VS Code
- 官方文档里 winget、扩展、CLI 几种方式分不清
- 从 GitHub 下载时好时坏
- 手动改 `settings.json` 配第三方模型容易出错

这个脚本把上面几步串起来，能跳过的跳过，该兜底的兜底。

### 它会做什么

1. 检测并安装 Git
2. 检测并安装 VS Code
3. 检测并安装 Claude Code 扩展
4. 检测并安装 CC Switch
   （GitHub 直连失败时自动尝试 `gh-proxy.com` 和 `ghproxy.net`）
5. 刷新当前会话的 PATH，打印安装结果和下一步

默认安装 **VS Code 扩展**。如果你还想在终端里直接敲 `claude`，运行时加 `-WithCLI`。

### 特点

- **幂等**：已经装好的组件会跳过，可以反复运行
- **可预检**：`-DryRun` 只检测，不安装、不下载、不写文件
- **可无人值守**：`-Yes -NoPause` 适合脚本化调用
- **不碰密钥**：不读取、不写入、不上传任何 API Key
- **少提权**：优先用户级安装，不主动请求管理员权限
- **国内网络友好**：GitHub 下载有镜像兜底

### 快速开始

```powershell
git clone https://gitee.com/tyw-0625/claude-code-oneclick.git
cd claude-code-oneclick
.\install.bat
```

或者：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
powershell -ExecutionPolicy Bypass -File .\install.ps1 -WithCLI
powershell -ExecutionPolicy Bypass -File .\install.ps1 -DryRun
```

### 适用范围

- Windows 10 1809+ / Windows 11
- PowerShell 5.1+
- 暂不支持 macOS / Linux

### 声明

非官方项目，与 Anthropic 没有任何隶属关系。
脚本只做安装，不提供任何账号、订阅或 API Key。

以 [MIT](LICENSE) 协议开源。
