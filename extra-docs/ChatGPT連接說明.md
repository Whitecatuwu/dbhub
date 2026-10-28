# 在 ChatGPT 連接 DBHub：方案選擇

本文件幫你**決定用哪種方式**讓 ChatGPT 使用 DBHub。實際操作步驟請見 [tunnel-client 安裝.md](tunnel-client%20安裝.md)（第 9 節說明如何接上 DBHub）與 [Docker使用說明.md](Docker使用說明.md)。

> 方案與功能名稱變動頻繁。本文整理自 2026 年 10 月的官方與第三方資料，**正式採用前請以 OpenAI 官方說明為準**：<https://help.openai.com/zh-hant/articles/12584461-connecting-custom-mcp-servers-in-chatgpt>。

## 一、先看結論

| 項目 | 狀況 |
|---|---|
| **建議做法** | 用 **tunnel-client**（OpenAI 的私有通道）。DBHub 不必公開到網際網路。 |
| ChatGPT | 免費版目前可以透過外掛程式 -> 新增自訂 MCP 伺服器 |
| 本專案的 `plugin/` | 只能用在 **Claude Code**，ChatGPT 不能用。 |
| 只想讓同事查資料、不一定要 AI | 用 DBHub 內建的網頁介面（Workbench）。 |

## 二、為什麼不能直接連

ChatGPT 的自訂 MCP 連接器是從 **OpenAI 的雲端**去連線，不是從你的電腦。因此如果不用隧道，DBHub 必須：

1. 有**公開可連線的 HTTPS 網址**。`http://localhost:18080/mcp` 或公司內網位址，ChatGPT 連不到。
2. 有身分驗證。DBHub 沒有內建 OAuth，只支援 Bearer Token（`--auth-token`）；ChatGPT 的 Token 選項能否順利配合，需要實測。
3. 端點路徑通常是 `https://你的網域/mcp`。

把 DBHub 公開等於把資料庫的查詢入口放到網際網路上，風險高。**tunnel-client 讓 ChatGPT 經 OpenAI 的私有通道連到你的電腦，不需要公開任何埠**，所以建議優先使用。

## 三、替代方案（不用公開網路）

| 情境 | 建議做法 |
|---|---|
| 同事願意改用 Claude | 用 Claude Desktop 加 `.mcpb` 安裝檔，見 [管理者發放指南（Claude Desktop）.md](管理者發放指南（Claude%20Desktop）.md)。 |
| 只想看資料表或跑查詢，不需要 AI | 用 DBHub 內建 **Workbench** 網頁介面（預設 `http://localhost:18080`）。 |
| 開發者本人使用 | Claude Code 搭配 stdio 或本機 HTTP，見 [使用說明與介紹.md](使用說明與介紹.md)。 |

## 四、推薦做法：ChatGPT ＋ tunnel-client

ChatGPT 的操作路徑：

**外掛程式（Plugins）→ 新增自訂 MCP 伺服器 → 連線方式選 Tunnel → 選擇隧道**

### 前置條件

1. **OpenAI 平台權限**：在 OpenAI 組織中具備 Tunnels 的 **Read** 與 **Use**（建立隧道者另需 **Manage**）。權限不足請組織管理者開通。
2. **Tunnel ID**（`tunnel_...`）：在 [Tunnels 管理頁](https://platform.openai.com/settings/organization/tunnels) 建立。
3. **Runtime API Key**：在 [API Keys 頁](https://platform.openai.com/settings/organization/api-keys) 建立。

這三項怎麼取得、怎麼設定，**逐步說明在 [tunnel-client 安裝.md](tunnel-client%20安裝.md) 第 2～6 節**，這裡不再贅述。

### 兩種接法（擇一）

| | 接法 A：tunnel-client 啟動 DBHub（stdio） | 接法 B：tunnel-client 連到已常駐的 DBHub（HTTP） |
|---|---|---|
| 適合 | 一個人使用、快速試用 | 多人共用、DBHub 已用 Docker 常駐 |
| DBHub 怎麼啟動 | 由 tunnel-client 自動啟動 | 先用 Docker 啟動，見 [Docker使用說明.md](Docker使用說明.md) |
| 需要先裝 | Node.js 與 `dbhub.toml` | Docker Desktop |
| 操作步驟 | [tunnel-client 安裝.md](tunnel-client%20安裝.md) 第 9 節「接 DBHub：方式 A」 | 同上「方式 B」 |

### 重要注意事項

- **隧道只保護網路路徑，不限制 SQL。** ChatGPT 能呼叫的工具仍會執行 SQL，因此一定要使用唯讀資料庫帳號，並在 TOML 設定 `readonly = true`、`max_rows`。能使用此連接器的人都能查資料，請只授權需要的人。
- **單一實例**：使用 stdio 接法時，同一個 Tunnel ID 同時只能有一個 tunnel-client 在執行。
- **要保持執行**：關閉 tunnel-client、電腦關機或休眠後，ChatGPT 就無法使用 DBHub。
- **接法 B 不要設定 `DBHUB_AUTH_TOKEN`**：官方說明未提到隧道會轉送自訂的 `Authorization` 標頭，設定後請求可能被擋成 401。這個架構靠「DBHub 只綁本機＋私有隧道＋唯讀帳號」保護。
- **接法 B 的資料庫位址**：Compose 掛載的是 `dbhub.docker.toml`，其中資料庫主機要用 `host.docker.internal`，不是 `127.0.0.1`。
- **接法 A 的密碼讀取**：`dbhub.toml` 中的 `${DBHUB_MYSQL_PASSWORD}` 從執行目錄的 `.env` 讀取，所以 tunnel-client 要在放有 `.env` 的專案資料夾執行。

## 五、多人使用的三個方案

同事只用 ChatGPT 時，ChatGPT 無法啟動你電腦上的程式（stdio），所以 DBHub 要以 HTTP 常駐。隧道屬於 **OpenAI 平台組織**，不是個人 ChatGPT 帳號。

| 方案 | 適用 | 同事需要做的事 |
|---|---|---|
| 1. ChatGPT Business 工作區 ＋ 一條隧道（建議） | 公司願意購買，資料較敏感 | 在自己的 ChatGPT 加入同一個連接器 |
| 2. 公開 HTTPS 端點 ＋ Token | 不能購買 Business，資料敏感度低 | 在個人帳號新增自訂 MCP，填網址與 Token |
| 3. 只用 Workbench 網頁介面 | 不需要 AI 對話 | 用瀏覽器開內網網址 |

> 以下判斷依文件推論，**尚未用多個真實帳號實測**；方案 1、2 採用前請先用一個帳號試通。

### 方案 1：Business 工作區 ＋ 一條隧道

- 管理者在工作區開啟開發者模式並建立一條隧道。
- 在一台常駐主機上執行 Docker 版 DBHub 與一個 tunnel-client（接法 B）。
- 每位同事在自己的 ChatGPT 加入**同一個**連接器、選同一條隧道，不必安裝任何東西。
- 缺點：有訂閱費用。

### 方案 2：公開 HTTPS ＋ Token

- 以 Docker 常駐 DBHub，前面接 HTTPS 入口（例如 Cloudflare Tunnel）。
- 在 `.env` 設定 `DBHUB_AUTH_TOKEN`，可用逗號列出多把，**一人一把**；某人離開時只撤銷他那一把。
- 同事在 ChatGPT 新增自訂 MCP，填 `https://你的網域/mcp` 與自己的 Token。
- 風險：查詢入口在公開網路；ChatGPT 的 Token 選項是否能正確送出 Bearer token 需實測。務必使用唯讀帳號、`readonly = true`、`max_rows`、`query_timeout`，並在入口限制來源或速率。

### 方案 3：Workbench 網頁介面

- 最安全，但沒有 AI 對話。
- DBHub 沒有內建登入，Compose 預設只綁 `127.0.0.1`。要給內網使用需自行調整綁定位址，並以防火牆或反向代理保護。

### 共通注意事項

- 所有人共用同一個 DBHub 與連線池，也是同一個資料庫身分，**無法分辨誰查了什麼，也無法分權限**。若不同人要看不同資料，需拆成多個 `[[sources]]` 與不同的資料庫帳號，並對應不同連接器。
- 主機、tunnel-client 或 HTTPS 入口掛掉會影響所有人；請設定開機自動啟動。Windows 長期常駐的做法官方文件沒有說明，需自行用作業系統的服務或排程處理。

## 六、常見問題

**Q：ChatGPT 顯示找不到或無法連線？**
用隧道時，先確認 tunnel-client 仍在執行、狀態頁顯示就緒（見 [tunnel-client 安裝.md](tunnel-client%20安裝.md) 第 7、12 節）。用公開網址時，通常是網址不是公開 HTTPS、防火牆擋住或 Token 不符，先從外部測試 `/healthz`。

**Q：能不能只用 `plugin/` 外掛？**
不行。`plugin/` 是 Claude Code 的格式，ChatGPT 不會讀取。

**Q：免費版能用嗎？**
目前可以。可以透過外掛程式 -> 新增自訂 MCP 伺服器；不行的話請改用 Claude Desktop 或升級方案。

**Q：Windows 指令要寫 `tunnel-client` 還是 `./tunnel-client.exe`？**
在 PowerShell 的程式所在資料夾，寫 `./tunnel-client.exe`。

---

本文件基於 2026 年 10 月的資料整理，OpenAI 的功能與方案可能隨時調整。
