# dsh-onebot-qq 本地补丁记录

插件被升级或重装后，下面的改动会丢失，需要重新打一遍。

## 补丁 1：关闭「排队提示」消息

**需求**：任务运行中新消息仍按 queue 策略排队处理，但不要回「⏳ 当前任务运行中，新消息已排队，将在当前任务结束后依次处理。」

**文件**：`C:\Users\rzy_r\.dsh\profiles\desktop\node_modules\dsh-onebot-qq\lib\bridge.js`

**位置**：方法 `interceptBusyTurn()` 尾部，把原本这段删掉：

```js
if (!this.queueNoticeChats.has(chatId)) {
    this.queueNoticeChats.add(chatId);
    this.sendToChat(chatId, QUEUE_NOTICE_TEXT).catch((error) => {
        this.deps.log('debug', '排队提示发送失败: ' + describeError(error));
        currentTrace()?.emit('notice', { ok: false, reason: '排队提示发送失败: ' + describeError(error) });
    });
}
```

**替换为**：

```js
// [dsh-local-patch 2026-10-28] 用户要求：不发送「当前任务运行中，新消息已排队」提示。
this.deps.log('debug', 'queue notice suppressed (local patch)');
```

另外在文件顶部 import 之后加了一行加载标记，便于确认补丁是否真的生效：

```js
console.log('[dsh-onebot][local-patch] bridge.js loaded with queue-notice disabled');
```

**生效条件**：插件是宿主进程内的 ESM 模块，改文件后**热重载不会重新加载 JS**，必须重启 DSH 桌面应用。重启后宿主日志出现上面那行 `[local-patch]` 即说明生效。

**备份**：同目录 `bridge.js.bak-*`（原始文件）。
