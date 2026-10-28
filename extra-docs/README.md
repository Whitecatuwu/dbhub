# DBHub 文件導覽

DBHub 讓 AI 助理（Claude、ChatGPT 等）用白話查詢公司資料庫。這個資料夾的文件依讀者分工，請先找到自己的角色。

## 我該讀哪一份？

| 我是… | 我想… | 請讀 |
|---|---|---|
| 一般同事（不懂程式） | 了解能問什麼、怎麼開始用 Claude Desktop | [給非技術人員的說明.md](給非技術人員的說明.md) |
| 管理者 | 製作安裝檔並發給同事用 Claude Desktop | [管理者發放指南（Claude Desktop）.md](管理者發放指南（Claude%20Desktop）.md) |
| 管理者 | 讓同事在 ChatGPT 使用 | 先讀 [ChatGPT連接說明.md](ChatGPT連接說明.md) 選方案，再照 [tunnel-client 安裝.md](tunnel-client%20安裝.md) 操作 |
| 工程師 | 用 Docker 讓 DBHub 常駐在一台電腦 | [Docker使用說明.md](Docker使用說明.md) |
| 工程師 | 了解 DBHub 的工具、啟動方式、連接各種 AI 工具 | [使用說明與介紹.md](使用說明與介紹.md) |
| 工程師 | 查 `.env`、`dbhub.toml` 每個參數 | [設定檔說明.md](設定檔說明.md) |

## 建議的整體流程

```text
1. 資料庫管理者建立「只能讀取」的專用帳號
2. 管理者選擇使用方式
   ├─ Claude Desktop → 製作 .mcpb 安裝檔 → 發給同事
   └─ ChatGPT        → Docker 常駐 DBHub + tunnel-client
3. 同事照入門說明開始提問
```

## 名詞速查

| 名詞 | 白話解釋 |
|---|---|
| DBHub | 讓 AI 能查詢資料庫的「橋」。 |
| MCP | AI 助理使用外部工具的一種標準。 |
| `.mcpb` | 給 Claude Desktop 雙擊安裝的 DBHub 安裝檔。 |
| DSN／連線字串 | 一行文字，包含資料庫位置、帳號與密碼。等同鑰匙，不可外流。 |
| `.env` | 存放密碼等敏感設定的文字檔，不可提交到 Git。 |
| TOML（`dbhub.toml`） | 設定「連哪些資料庫、提供哪些工具」的文字檔。 |
| stdio／HTTP | DBHub 與 AI 工具的兩種連接方式：前者由 AI 工具直接啟動 DBHub，後者 DBHub 常駐並提供網址。 |
| Docker | 把程式與所需環境裝在「盒子」裡執行的工具。 |
| Tunnel／tunnel-client | OpenAI 提供的私有通道，讓 ChatGPT 不必經公開網路就能連到你電腦上的 DBHub。 |
| 唯讀 | 只能看，不能改。 |

## 指令格式提醒

- 文件中的 Windows 指令都在 **PowerShell** 執行。
- 在 Windows，執行目前資料夾裡的程式要寫 **`./tunnel-client.exe`**，不是 `tunnel-client`。
- 範例中的帳號、密碼、網址、Tunnel ID 都要換成自己的真實值，**不要把真實密碼貼到聊天或文件裡**。
