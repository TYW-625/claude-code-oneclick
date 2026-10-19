# 设计说明

## 目标

把 B 站木子不写代码的 Claude Code 安装流程，做成 Windows 上双击即用的脚本：

Git → VS Code → Claude Code 扩展 → CC Switch

## 关键决定

| 问题 | 决定 | 原因 |
|---|---|---|
| 平台 | 只做 Windows | 作者本机是 Windows，能实测；macOS/Linux 差异大，先不做 |
| Claude Code 形态 | 默认装 VS Code 扩展，`-WithCLI` 才装原生 CLI | 作者日常使用扩展；扩展自带 CLI，不依赖 Node |
| 供应商配置 | 交给 CC Switch 界面 | 脚本不碰 API Key，避免密钥泄露风险 |
| 安装来源 | winget 优先，官方安装包兜底 | winget 是 Windows 自带的包管理器，失败时仍有退路 |
| GitHub 下载 | 直连 → gh-proxy → ghproxy.net | 国内网络环境下 GitHub 经常不可达 |
| 管理员权限 | 尽量用户级安装，不主动提权 | 降低门槛，避免误改系统 |
| 幂等 | 每步先检测，已安装就跳过 | 重复运行安全 |
| 失败处理 | 单个组件失败不中断，最后汇总 | 用户能一次看到所有问题 |

## 不做的事

- 不安装 Node.js（扩展和原生 CLI 都不需要）
- 不写入 `~/.claude/settings.json`
- 不读取、不打印、不上传任何 API Key
- 不自动登录 Anthropic 账号

## 验证

- `-DryRun` 在本机跑通：Git / VS Code / 扩展 / CC Switch 均被正确识别为已安装
- `-WithCLI -DryRun` 能识别 npm 版 `claude`（2.1.152）
- GitHub API 直连与 gh-proxy 镜像均返回 `v4.0.16`
- `winget` 支持 `--disable-interactivity`

## 未验证

- 干净机器上的完整安装路径（本机组件已齐全，无法在不卸载的前提下验证）
- MSI 兜底路径（本机走的是便携版）
