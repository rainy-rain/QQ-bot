# QQbot — 让小号变成一个会聊天的角色

把 QQ 小号接成一个"虚拟人物"：扫码登录 → 收到消息 → 由 DSH Agent 按人设回复（支持看图）。
全部本机运行，不经过任何第三方托管。

```
你的 QQ / 群友
   ↕
小号（NapCat 独立实例，网页扫码登录）
   ↕ OneBot 11 WebSocket
dsh-onebot-qq 插件（挂在 DSH 宿主里）
   ↕
DSH Agent（工作区 = 本目录，人设 = AGENTS.md，模型 = deepseek-flash 多模态）
```

---

## 目录说明

| 路径 | 作用 | 进 git |
|---|---|---|
| `AGENTS.md` | **人设**。改这个文件就换角色，下一轮对话生效 | ✅ |
| `config/cordis.patch.snippet.yml` | 插件配置片段，复制进 DSH profile 的 patch 文件 | ✅ |
| `config/onebot11.example.json` | NapCat 的 OneBot 网络配置模板 | ✅ |
| `scripts/` | NapCat 启动 / 停止 / 状态脚本 | ✅ |
| `PATCHES.md` | 对插件源码打的本地补丁记录（升级后要重打） | ✅ |
| `media/onebot/` | 运行时媒体（收到的图片、语音、会话映射） | ❌ 忽略 |
| `data/`（未使用） | 预留 | ❌ 忽略 |

## 关键约束：NapCat 不能放在本目录里

DSH 工作区（`D:\DSHfile`）里的**可执行文件**带低完整性标签，进程只能写工作区、写不了 `C:\Users\...`。
NapCat 登录后必须往 `Documents\Tencent Files\NapCat\` 写账号数据，放在工作区里会直接崩（`EPERM: mkdir`）。

所以运行时目录固定在工作区外：

```
D:\NapCatRun\        NapCat v4.18.41 + 自带 QQ 内核
D:\NapCatRun\app\    实际程序（napcat.bat 在这里…见脚本）
```

> 同理：**不要**把任何需要运行的可执行文件放进 `D:\DSHfile` 下。

## 一、环境

| 依赖 | 版本 |
|---|---|
| DSH | ≥ 0.1.5（本机桌面版） |
| NapCat | v4.18.41（Windows 便携包 `NapCat.Shell.Windows.Node.zip`） |
| 插件 | `dsh-onebot-qq` 0.9.6（DSH 插件市场安装） |
| 模型 | `deepseek-account / deepseek-flash`（多模态，识图直接可用） |

## 二、部署步骤

### 1. 装 NapCat（工作区外）

1. 下载 `NapCat.Shell.Windows.Node.zip` 并解压到 `D:\NapCatRun`（**解压，不要从工作区移动过来**，否则继承低完整性标签）。安装包用完可删，重装时从 [NapCat Releases](https://github.com/NapNeko/NapCatQQ/releases) 重新下载（当前版本 v4.18.41）
2. 双击 `D:\NapCatRun\napcat.bat`
3. 打开 WebUI，用**小号**手机 QQ 扫码登录
   - WebUI：`http://127.0.0.1:6099/webui?token=<看启动日志>`
   - 二维码 2 分钟过期，过期后刷新页面重新扫，扫完立刻在手机上点确认

### 2. 配 NapCat 的 OneBot 网络

编辑 `D:\NapCatRun\napcat\config\onebot11_<小号UIN>.json`，照 `config/onebot11.example.json` 填：

```json
"websocketServers": [
  {
    "name": "dsh-onebot",
    "enable": true,
    "host": "127.0.0.1",
    "port": 3001,
    "messagePostFormat": "array",
    "token": "<自定义，与插件一致>",
    "enableForcePushEvent": true
  }
]
```

改完重启 NapCat（登录态会保留，但可能需要再扫一次码，QQ 的"快速登录"会要求手Q验证）。

### 3. 装并配插件

```sh
dsh plugin --profile desktop add dsh-onebot-qq
```

把 `config/cordis.patch.snippet.yml` 的内容合并进
`C:\Users\rzy_r\.dsh\profiles\desktop\cordis.patch.yml`，然后重启 DSH。

## 三、日常维护

| 我要… | 怎么做 |
|---|---|
| 换人设 | 改 `AGENTS.md` |
| 换模型 / 加白名单 / 开群聊 | 改 `cordis.patch.yml` 的 `dsh-onebot` 段（改完自动热重载） |
| 清图片占空间 | 删 `media/onebot/media_*`（保留 `chat-sessions.json`） |
| 看日志 | `C:\Users\rzy_r\.dsh\logs\desktop-next.log`，搜 `[dsh-onebot]` |
| 查最近图片 | QQ 里发 `/ocr` |
| 体检 | QQ 里发 `/doctor` |
| 重装插件补丁 | 按 `PATCHES.md` 操作，然后重启 DSH |

## 四、常见问题

| 症状 | 原因 / 处理 |
|---|---|
| 发消息没反应 | 先看 3001 是否在监听；再看日志有没有 `OneBot connected`；白名单里必须有你的 QQ |
| 登录后立刻又出二维码 | NapCat 崩溃重启。看日志有无 `EPERM`，多半是可执行文件在 `D:\DSHfile` 下 |
| WebUI 报 `Unauthorized` | NapCat 重启后旧页面会话失效，刷新页面重新输 token |
| 图片看不懂 | 确认模型是多模态的；媒体目录里有对应 `media_*` 文件说明下载成功 |
| 回复很慢 | 默认 `reasoningEffort: high`，可下调；或换更快的模型 |

## 五、风险提示

- 第三方协议登录有风控风险，**只用小号**，前三天别进群刷屏、别秒回、别复读
- WebUI / OneBot 端口只绑 `127.0.0.1`，不要暴露到公网
- 群聊默认关闭（`groupPolicy: disabled`），要开的话建议配合 `requireMention: true`

## 六、启动与停止：双击 `QQbot.bat`

**不做开机自启**（已把启动目录的快捷方式删掉），什么时候开这个聊天服务由你决定。

```
D:\DSHfile\QQbot\QQbot.bat         ← 双击启动（自检 + 拉起服务，全在这一个文件里）
D:\DSHfile\QQbot\QQbot-stop.bat    ← 双击停止（只停 QQ，不关 DSH，不碰你主号）
```

`QQbot.bat` 做的事：

0. **环境自检**（纯 batch 内联，无额外文件）：逐项检查，有缺的直接说缺什么；缺关键组件就中止启动
   - NapCat 主程序（`napcat.bat` / `node.exe` / `wrapper.node` / `index.js`）
   - 小号登录配置 `onebot11_<UIN>.json`
   - DSH 桌面应用
   - `dsh-onebot-qq` 插件及其在 `cordis.patch.yml` 里的配置段
   - 端口 3001 / 6099（`[--]` 表示已被占用，通常是 NapCat 自己在跑，不算错误）
   - 可选：ffmpeg / whisper（语音转写，缺了不影响文字和图片）
1. 查 NapCat 是否在跑，没跑就用 **WMI `Win32_Process.Create`** 拉起（父进程是 `WmiPrvSE`，脱离 DSH 命令的 job object —— 这样关掉黑窗口、重启 DSH 都不会把 QQ 一起带走）
2. 查 DSH 桌面应用是否在跑，没跑就启动它（插件跑在宿主里）
3. 等 QQ 上线 + 插件连上，最多 90 秒
4. 打印状态表；如果 QQ 登录态失效需要扫码，**自动打开 WebUI 扫码页**

自检标记含义：`[OK]` 通过、`[WARN]` 可选组件缺失（照常启动）、`[FAIL]` 关键缺失（中止并说明缺什么）、`[--]` 仅提示（如端口已被 NapCat 占用）。

> 改 `.bat` 的注意事项：文件必须是 **UTF-8 无 BOM + CRLF 换行**，开头有 `chcp 65001` 才能正确显示中文；用 LF 会让 cmd 把多行拼成一行报错。`.ps1` 相反，必须是 **UTF-8 with BOM**，否则 PowerShell 5.1 读中文会乱码并语法报错。

判断逻辑（省得你等 90 秒）：刚启动的 NapCat 给 30 秒做快速登录；已经在跑却只有 WebUI 6099、没有 OneBot 3001，就直接判定「需要扫码」并打开浏览器。

扫描用的是**小号**的手机 QQ，扫完立刻点允许登录；然后再双击一次 `QQbot.bat`，看到「OK QQbot 已就绪」即可。

> 为什么不做开机自启：启动时机由你控制更可控（比如你本机关机、或者不想让 QQ 一直挂着）；而且 `schtasks /sc onlogon /rl highest` 在这台机器上没有管理员权限被拒绝过。

## 七、每天的常规流程

| 场景 | 操作 |
|---|---|
| 想用聊天服务了 | 双击 `QQbot.bat`，等它说「已就绪」 |
| 提示需要扫码 | 它会自动弹 WebUI，用**小号**扫码，扫完再双击一次 |
| 不想挂了 | 双击 `QQbot-stop.bat`（或直接关掉 QQ 那个窗口） |
| 出问题 | 双击 `scripts\status.ps1` 看进程/端口/连接/登录号 |

> 快速登录偶尔会要求「手Q验证」。遇到时 NapCat 退回二维码，去 WebUI 扫一次即可；扫过之后一段时间内通常能直接快速登录。
