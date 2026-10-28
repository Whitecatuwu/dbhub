# DBHub 文件導覽

DBHub 讓 ChatGPT 用白話查詢公司資料庫（MySQL，唯讀）。這個資料夾的文件依讀者分工，請先找到自己的角色。

## 我該讀哪一份？

| 我是… | 我想… | 請讀 |
|---|---|---|
| 管理者 | 了解有哪些方案、有哪些事要我決定 | [ChatGPT連接說明.md](ChatGPT連接說明.md) |
| 技術人員 | 讓 ChatGPT 經 OpenAI 隧道連到 DBHub | [tunnel-client 安裝.md](tunnel-client%20安裝.md) |
| 技術人員 | 用 Docker 讓 DBHub 常駐在一台電腦 | [Docker使用說明.md](Docker使用說明.md) |
| 技術人員 | 了解 DBHub 的工具與啟動方式 | [使用說明與介紹.md](使用說明與介紹.md) |
| 技術人員 | 查 `.env`、`dbhub.toml` 每個參數 | [設定檔說明.md](設定檔說明.md) |
| 一般同事（不懂程式） | 了解能問什麼、怎麼問、出問題找誰 | [給非技術人員的說明.md](給非技術人員的說明.md) |

## 建議的整體流程

```text
1. 資料庫管理者建立「只能讀取」的專用 MySQL 帳號
2. 管理者決定方案（ChatGPT連接說明.md 第四節）
   ├─ 方案 B：每人各一條隧道（已實測）→ 每台電腦用 npx 啟動 DBHub
   └─ 方案 A：共用一條隧道（未實測）→ 一台主機用 Docker 常駐 DBHub
3. 技術人員依 tunnel-client 安裝.md 設定，並在 ChatGPT 加入連接器
4. 同事照入門說明開始提問
```

## 名詞速查

| 名詞 | 白話解釋 |
|---|---|
| DBHub | 讓 AI 能查詢資料庫的「橋」。 |
| MCP | AI 助理使用外部工具的一種標準。 |
| 連接器 | ChatGPT 裡讓它能使用某個 MCP 伺服器的項目。 |
| DSN／連線字串 | 一行文字，包含資料庫位置、帳號與密碼。等同鑰匙，不可外流。 |
| `.env` | 存放密碼等敏感設定的文字檔，不可提交到 Git。 |
| TOML（`dbhub.toml`） | 設定「連哪個資料庫、提供哪些工具」的文字檔。 |
| stdio／HTTP | DBHub 與其他程式的兩種連接方式：前者由對方直接啟動 DBHub，後者 DBHub 常駐並提供網址。 |
| Docker | 把程式與所需環境裝在「盒子」裡執行的工具。 |
| Tunnel／tunnel-client | OpenAI 提供的私有通道，讓 ChatGPT 不必經公開網路就能連到你電腦上的 DBHub。 |
| 唯讀 | 只能看，不能改。 |

## 指令格式提醒

- 文件中的 Windows 指令都在 **PowerShell** 執行；Ubuntu 的對應做法見 [tunnel-client 安裝.md](tunnel-client%20安裝.md) 第 11 節與 [Docker使用說明.md](Docker使用說明.md) 開頭的備註。
- 在 Windows，執行目前資料夾裡的程式要寫 **`./tunnel-client.exe`**，不是 `tunnel-client`。
- 範例中的帳號、密碼、網址、Tunnel ID 都要換成自己的真實值，**不要把真實密碼貼到聊天或文件裡**。
- DBHub 版本固定為 `1.5.0`，不要改用 `@latest`。
