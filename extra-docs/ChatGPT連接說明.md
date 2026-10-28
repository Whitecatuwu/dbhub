# 在 ChatGPT 連接 DBHub 的說明

本文件說明：為什麼 **ChatGPT 免費版無法直接連接 DBHub**，以及若要改用付費方案或其他 AI 工具，需要準備哪些條件。

## 一、結論

| 項目 | 狀況 |
|---|---|
| ChatGPT 免費版加入外掛程式 | **使用者回報可以連結**（2026 年 10 月確認）。但我的網路搜尋結果指出免費版通常只能用目錄中的應用程式，兩者不一致，因此 **連線方式（目錄應用程式或自訂 MCP 端點）與可用功能仍需實測確認**。 |
| ChatGPT 付費版（Plus、Pro） | 需開啟開發者模式，且**只能使用唯讀**的自訂 MCP 連接器（依第三方資料，請以官方說明為準）。 |
| ChatGPT Business、Enterprise、Edu | 可使用完整的 MCP 功能（含寫入），但需要**管理者**先在工作區開啟開發者模式。 |
| 本專案的 Claude Code 外掛（`plugin/`） | 只能用於 **Claude Code**，不能用於 ChatGPT。 |
| **建議做法** | 使用 `tunnel-client`（見第五節），不需公開網路。 |

> 方案與功能名稱變動頻繁。以上資訊整理自第三方說明文件，**正式採用前請先查 OpenAI 官方說明**：<https://help.openai.com/>。

## 二、為什麼不能直接連接

ChatGPT 的自訂 MCP 連接器是在 **OpenAI 的雲端**連線，而不是在使用者電腦上。因此 DBHub 必須符合下列條件：

1. **公開可連線的 HTTPS 網址**
   - `http://localhost:18080/mcp` 或只在公司內網可用的位址，ChatGPT 都無法連到。
   - 本機測試可用 Cloudflare Tunnel 或 ngrok 暫時對外開放，但這不適合正式環境。
2. **身分驗證**
   - ChatGPT 的應用程式設定提供 None、OAuth、Token 等選項。
   - DBHub **沒有內建 OAuth**。若要保護 HTTP 端點，目前只能使用 `--auth-token`（Bearer Token）。是否能順利搭配 ChatGPT 的 Token 選項，需要實測確認。
3. **MCP 端點路徑**
   - 通常是 `https://你的網域/mcp`。

## 三、安全風險（務必閱讀）

把 DBHub 對外開放等於把資料庫的查詢入口放到網際網路上。若沒有妥善保護，任何人都可能嘗試查詢資料。

- **不建議**直接把內部資料庫開放到公開網路。
- 若必須對外，至少要做到：
  - 設定 `--auth-token`，且 Token 要夠長、定期更換。
  - 使用 HTTPS，不使用明文 HTTP。
  - 資料庫帳號只給**唯讀權限**，並在 TOML 設定 `readonly = true`。
  - 限制 `max_rows`、`query_timeout`，避免大型查詢拖垮資料庫。
  - 在反向代理或防火牆限制來源 IP 或加上額外驗證。
- DBHub 的 `DBHUB_ALLOWED_HOSTS` 只是 Host 標頭檢查，**不是**身分驗證。

## 四、替代方案（不需要公開網路）

| 情境 | 建議做法 |
|---|---|
| 多位同事只用 ChatGPT（個人帳號或同一工作區） | 見[第六節](#六多人使用的三個方案)。 |
| 同事願意改用其他 AI 工具 | 改用 **Claude Desktop**，並安裝本專案的 **MCP Bundle**（`mcpb/`），在本機執行，不需要公開網路。 |
| 只想看資料表或跑查詢，不需要 AI | 使用 DBHub 內建的 **Workbench 網頁介面**（預設 `http://localhost:18080`）。 |
| 開發者本人使用 | 使用 Claude Code 搭配 stdio 或本機 HTTP 端點（見 [使用說明與介紹.md](使用說明與介紹.md)）。 |

## 五、推薦做法：ChatGPT 外掛程式 + tunnel-client

使用者已確認以下路徑可以連上 DBHub：

**ChatGPT → 外掛程式 → 新增自訂 MCP 伺服器 → 連線方式選 `tunnel-client`**

`tunnel-client`（<https://github.com/openai/tunnel-client>）是 OpenAI 提供的 Secure MCP Tunnel 客戶端。它在你的電腦上執行，把本機的 MCP 伺服器接到 OpenAI 的隧道端點，因此 **DBHub 不需要公開網路，也不需要自行設定 HTTPS 與防火牆**。

### 前置條件

1. **OpenAI 平台權限**：需要在 OpenAI 組織中具備 Tunnels 的 **Read** 與 **Use** 權限（管理隧道者另需 **Manage**）。權限不足時請管理者開通。
2. **隧道 ID（`tunnel_...`）**：在 Tunnels 管理頁建立或查看：<https://platform.openai.com/settings/organization/tunnels>
3. **Runtime API key**：在此建立：<https://platform.openai.com/settings/organization/api-keys>

### 步驟

1. **安裝 tunnel-client**
   - macOS：`brew install openai/tools/tunnel-client`
   - Windows：請從 Tunnels 管理頁下載官方支援的版本（官方說明不建議直接使用未經確認的版本）。
   - 確認安裝：`tunnel-client --version`

2. **設定 DBHub 為 stdio 的 MCP 伺服器**，由 tunnel-client 啟動。例如用 `dbhub.toml`：

   ```bash
   tunnel-client init --sample sample_mcp_stdio_local --profile dbhub --tunnel-id tunnel_你的ID --mcp-command "npx -y @bytebase/dbhub@1.5.0 --config ./dbhub.toml"
   ```

3. **設定 API key 環境變數**（以 PowerShell 為例）：

   ```powershell
   $env:CONTROL_PLANE_API_KEY = "sk-..."
   ```

4. **檢查設定**：

   ```bash
   tunnel-client doctor --profile dbhub --explain
   ```

5. **啟動**（保持視窗開啟）：

   ```bash
   tunnel-client run --profile dbhub
   ```

6. **在 ChatGPT 新增連接器**：外掛程式 → 新增自訂 MCP 伺服器 → 連線方式選 `tunnel-client` → 選擇剛才的隧道 → 儲存。
7. **測試**：請 ChatGPT 列出資料表，確認工具可以呼叫。

### 注意事項

- **執行位置**：`dbhub.toml` 中的 `${DBHUB_MYSQL_PASSWORD}` 會從執行目錄的 `.env` 讀取，因此 `tunnel-client` 要在專案資料夾中執行，或改用絕對路徑。
- **單一實例**：使用 stdio 模式（`--mcp.command`）時，同一個隧道 ID 只能同時執行一個 `tunnel-client`，否則會互相衝突。
- **保持執行**：`tunnel-client run` 關閉後，ChatGPT 就無法使用 DBHub。長期使用可參考官方的 `tunnel-client runtimes connect` 指令。
- **權限仍然重要**：隧道只是保護網路路徑，ChatGPT 能呼叫的工具仍然會執行 SQL。因此仍須使用唯讀帳號，並在 TOML 中設定 `readonly = true`、`max_rows`。能使用此連接器的人都能查詢資料，請只授權需要的人。
- 以上指令取自官方 README，`--mcp-command` 的格式與 Windows 路徑寫法請以 `tunnel-client help quickstart` 的輸出為準。

### 改指向已在執行的 HTTP 端點（Docker 常駐 DBHub）

上面是由 `tunnel-client` 用 stdio 啟動 DBHub。若 DBHub 已由 `compose-dbhub.yaml` 常駐在同一台主機，可以讓 `tunnel-client` 改連 HTTP 端點。依官方 README，用 `--mcp.server-url`：

```powershell
$env:CONTROL_PLANE_API_KEY = "sk-..."
tunnel-client run --control-plane.tunnel-id tunnel_你的ID --mcp.server-url http://127.0.0.1:18080/mcp
```

- 先用 `curl http://127.0.0.1:18080/healthz` 確認 DBHub 正常。
- README 的範例網址是 `https://`，**未明說 `http://127.0.0.1` 是否可用**，請以 `doctor` 與 `run` 的輸出實測。
- README **未提到會轉送自訂的 `Authorization` 標頭**。這個架構建議先不要設定 `DBHUB_AUTH_TOKEN`，否則請求可能被擋成 401；保護靠「DBHub 只綁本機＋私有隧道＋只讀資料庫帳號」。
- DBHub 若比 `tunnel-client` 晚啟動，可設 `mcp.startup_wait_timeout`（例如 `2m`）。
- README 沒有說明 Windows 長期常駐的做法；`tunnel-client` 要自己用作業系統的服務管理確保開機自動啟動。
- 本專案的 Compose 會掛載 `dbhub.docker.toml`（容器內的 `/app/dbhub.toml`），其中資料庫主機要用 `host.docker.internal`，而不是 `127.0.0.1`。

## 六、多人使用的三個方案

同事只使用 ChatGPT、不會用 Claude Code 或 Claude Desktop 時，不能用 stdio（ChatGPT 無法啟動本機程式），DBHub 必須以 HTTP 常駐。`tunnel-client` 與隧道屬於 **OpenAI 平台組織**，不是個人 ChatGPT 帳號，因此要先看同事是在同一個組織，還是各自使用個人帳號。

| 方案 | 適用 | 同事需要做的事 |
|---|---|---|
| 1. ChatGPT Business 工作區 ＋ 一條隧道 | 公司願意購買，資料敏感度較高 | 在自己的 ChatGPT 加入同一個連接器 |
| 2. 公開 HTTPS 端點 ＋ Token | 不能購買 Business，資料敏感度低 | 在個人帳號新增自訂 MCP，填網址與 Token |
| 3. 只用 Workbench 網頁介面 | 不需要 AI 對話，只想查資料 | 用瀏覽器開內網網址 |

> 以下判斷依文件與官方 README 推論，未用個人帳號實測；方案 1、2 在採用前請先用一個帳號試通。

### 方案 1：ChatGPT Business 工作區（建議）

- 管理者在工作區開啟開發者模式，並建立一條隧道。
- 只需在一台常駐主機執行一個 `tunnel-client`，指向 `http://127.0.0.1:18080/mcp`（做法見第五節）。
- 每位同事在自己的 ChatGPT 加入**同一個**連接器、選同一條隧道，不必安裝任何東西。
- 隧道屬於組織，可集中管理誰能使用。
- DBHub 以 HTTP 執行時每個請求獨立處理，多人同時查詢沒有問題。
- 缺點：有訂閱費用。

### 方案 2：公開 HTTPS 端點 ＋ Token（個人帳號）

- 以 Compose 常駐 DBHub，前面接 HTTPS 入口（例如 Cloudflare Tunnel，不必對外開放主機埠）。
- 在 `.env` 設定 `DBHUB_AUTH_TOKEN`。可用逗號列出多把 token，**一人一把**；某人離開時只撤銷他那一把。
- 每位同事在 ChatGPT 新增自訂 MCP 應用程式，填 `https://你的網域/mcp` 與自己的 Token。
- 風險與前提：
  - 資料庫的查詢入口放在公開網路上。
  - ChatGPT 的 Token 選項是否能正確送出 Bearer token，需要實測。
  - Plus、Pro 的自訂 MCP 連接器需開發者模式且為唯讀；免費版能否新增自訂端點尚未確認。
  - 務必使用只讀資料庫帳號、`readonly = true`、`max_rows`、`query_timeout`，並在入口限制來源或速率。

### 方案 3：Workbench 網頁介面

- DBHub 內建的 Workbench 只在公司內網或 VPN 開放（例如 `http://主機:18080`），同事用瀏覽器查詢。
- 最安全，但沒有 AI 對話。
- 注意：DBHub 沒有內建登入，Compose 預設只綁 `127.0.0.1`；要給內網使用需自行調整對外綁定，並以防火牆或反向代理保護。

### 共通注意事項

- 所有人共用同一個 DBHub 與連線池；PostgreSQL 預設每個來源上限 10 條連線（`pool_max_connections`），使用者多時以 `query_timeout`、`max_rows` 避免單一大查詢拖慢其他人。
- 所有 ChatGPT 使用同一個資料庫身分，**無法分辨是誰查的，也無法分權限**。若不同人要看不同資料，需拆成多個 `[[sources]]` 與不同的資料庫帳號，並對應不同的連接器。
- 主機與 `tunnel-client`／HTTPS 入口掛掉會影響所有人，請確認它們開機後自動啟動。

## 七、其他方式：公開 HTTPS 端點（不建議）

上述方式不需要公開網路，建議優先使用。以下是直接對外開放 DBHub 的做法，風險較高：

以下為通用流程，實際畫面與名稱請以 OpenAI 官方說明為準：

1. 確認方案與管理者權限，並請管理者在工作區開啟**開發者模式**。
2. 準備公開的 HTTPS 端點，並確認 `https://你的網域/mcp` 可以從外部連線。
3. 在 DBHub 啟動時設定 Token，例如：

   ```bash
   npx -y @bytebase/dbhub@1.5.0 --config ./dbhub.toml --transport http --port 8080 --auth-token "長且隨機的字串"
   ```

4. 在 ChatGPT 的設定中新增自訂 MCP 應用程式，填入端點網址，驗證方式依實際選項設定。
5. 以唯讀查詢測試，例如請它列出資料表，確認工具可以正常呼叫。

## 八、常見問題

**Q：ChatGPT 顯示找不到或無法連線？**
通常是網址不是公開 HTTPS、防火牆擋住、或 Token 不符。先用瀏覽器或 `curl` 從外部測試 `/healthz`。

**Q：能不能只用 `plugin/` 外掛？**
不行。`plugin/` 是 Claude Code 的外掛格式，ChatGPT 不會讀取。

**Q：免費版為什麼不能用？**
已有使用者回報免費版可以連結外掛程式，但連線方式與可用範圍尚未記錄在此。若要照做，請先確認實際使用的是哪一種連接方式，並測試是否能連到本機或公開的 DBHub 端點。若無法連線，再改用上方替代方案。

---

本文件基於 2026 年資料整理，OpenAI 的功能與方案可能隨時調整，請以官方文件為準。
