# Secure MCP Tunnel 安裝與設定指南（接 DBHub）

適用對象：技術人員。本文以 Windows 與 PowerShell 為主，第 11 節補充 Ubuntu。要先決定採用哪種方案（單一共用主機或每人各自啟動），請看 [ChatGPT連接說明.md](ChatGPT連接說明.md)。

本指南依據 OpenAI 官方文件與本專案文件整理，核對日期為 2026 年 10 月。網頁按鈕名稱、功能開放範圍及權限介面可能調整，請以登入後的實際畫面為準。

## 1. 先認識需要的東西

把 MCP Tunnel 想成一位傳話員：ChatGPT 請它把工作交給你電腦上的工具，再把結果帶回來。

```text
ChatGPT ⇄ OpenAI Tunnel ⇄ tunnel-client ⇄ DBHub ⇄ MySQL
                              ↑
                         在你的電腦執行
```

| 名稱 | 簡單比喻 | 實際用途 |
| --- | --- | --- |
| Tunnel ID | 通道的門牌號碼 | 指定要使用哪條通道 |
| Runtime API Key | 通道的鑰匙 | 讓 tunnel-client 有權使用通道 |
| tunnel-client | 傳話員 | 接收 OpenAI 的請求，轉交給 DBHub |
| DBHub | 真正做事的人 | 提供查詢資料表與執行唯讀 SQL 的工具 |

tunnel-client 本身不會查資料庫，必須搭配 DBHub。第一次測試可以先使用內建示範，不必先準備 DBHub。

整體流程：建立 Tunnel → 建立 Runtime API Key → 安裝 → 測試示範 → 連接 ChatGPT → 改接 DBHub。

## 2. 確認帳號與權限

登入 [OpenAI Platform](https://platform.openai.com/)，切換到要使用的組織。個人帳號會有屬於自己的個人 Platform 組織。實測免費版與 Plus 帳號建立 Tunnel 與 Runtime API Key **都不需要加入付款方式或儲值**。

| 工作 | 所需 Tunnels 權限 |
| --- | --- |
| 建立或修改 Tunnel | Read（讀取）＋Manage（管理） |
| 執行 tunnel-client 或選用 Tunnel | Read（讀取）＋Use（使用） |
| 自己建立並執行 | Read＋Manage＋Use |

自己的個人組織通常已具備全部權限。在別人的組織中權限不足時，請組織擁有者在 [組織角色設定](https://platform.openai.com/settings/organization/people/roles) 指派角色。

## 3. 建立 Tunnel ID

1. 開啟 [Tunnels 管理頁](https://platform.openai.com/settings/organization/tunnels)。
2. 確認目前選到正確的組織。
3. 選擇建立 Tunnel 的按鈕（例如 **Create tunnel**），輸入容易辨識的名稱，例如 `dbhub-mysql`。
4. 建立後，複製平台產生的 Tunnel ID。

Tunnel ID 的格式如下，這是範例，不能直接使用：

```text
tunnel_0123456789abcdef0123456789abcdef
```

請使用平台實際產生的 ID。建立後可稍等約 30 秒再測試。

## 4. 建立 Runtime API Key

Runtime API Key 是給 tunnel-client 使用的鑰匙。

1. 開啟 [API Keys](https://platform.openai.com/settings/organization/api-keys)，確認使用與 Tunnel 相同的組織。
2. 新增 API Key，名稱可填 `tunnel-client`。
3. 權限選 **Restricted（受限）**，找到 **Tunnels**，啟用 **Read＋Use**。
4. 建立後複製 Key，妥善保存在密碼管理器。

不要把真實 Key 貼到聊天、截圖、公開文件或 Git。遺失時重新建立；外洩時立刻撤銷並換發。本指南用網頁建立 Tunnel，不需要 Admin API Key，也不要把 Admin API Key 放進長時間執行的 tunnel-client。

## 5. 安裝 Windows 執行檔

1. 從 [Tunnels 管理頁](https://platform.openai.com/settings/organization/tunnels) 的下載連結取得 Windows 版本，也可使用官方 [最新公開版本](https://github.com/openai/tunnel-client/releases/latest)。
2. 一般 Intel／AMD 電腦選 **amd64／x64**；Windows ARM 電腦選 **arm64**（「設定 → 系統 → 關於 → 系統類型」可確認）。
3. 解壓縮整個壓縮檔，例如放在 `C:\Tools\tunnel-client`，保留壓縮檔附帶的其他檔案。
4. 在包含 `tunnel-client.exe` 的資料夾開啟 PowerShell，確認可以執行：

```powershell
Set-Location C:\Tools\tunnel-client
./tunnel-client.exe --version
./tunnel-client.exe help quickstart
```

能顯示版本與說明就代表程式可以啟動。在 Windows PowerShell，執行目前資料夾裡的程式要寫 `./tunnel-client.exe`，不是 `tunnel-client`。本文路徑只是範例，請換成實際位置。

## 6. 設定 API Key 與 Tunnel ID

在同一個 PowerShell 視窗執行，依提示輸入 Runtime API Key（輸入時不顯示明文）：

```powershell
$tunnelSecret = Read-Host "請輸入 Runtime API Key" -AsSecureString
$env:CONTROL_PLANE_API_KEY = [System.Net.NetworkCredential]::new("", $tunnelSecret).Password
Remove-Variable tunnelSecret
```

再設定 Tunnel ID，把引號裡的文字換成真正的 ID：

```powershell
$env:CONTROL_PLANE_TUNNEL_ID = "貼上平台產生的 Tunnel ID"
```

這些設定只存在目前的 PowerShell 視窗，關閉後下次要重新設定。不要列印環境變數，也不要分享包含秘密的診斷輸出。

## 7. 先執行內建示範

先用內建 MCP 示範確認 Tunnel 設定可以運作：

```powershell
./tunnel-client.exe run --embedded-stateless-mcp-stub --health.listen-addr 127.0.0.1:8080
```

保持 PowerShell 開著，在瀏覽器開啟 <http://127.0.0.1:8080/ui>，查看健康、就緒與連線狀態。程式已啟動不代表已經連線成功，還要確認它準備好接收請求。示範提供 `server_info`、`echo` 與 `uppercase` 工具。

如果 8080 埠被占用（例如 Docker 版 DBHub 不會占用它，但其他程式可能），改用 `127.0.0.1:8081`，狀態頁網址隨之改變。

## 8. 在 ChatGPT 連接 Tunnel

保持示範程式執行，再進行以下操作。免費版與 Plus 帳號實測都不需要先開啟開發者模式：

1. 開啟 ChatGPT 的 **Plugins** 頁面。
2. 選擇加號，再選 **Add custom MCP server**。
3. 在 **Connection** 選擇 **Tunnel**。
4. 選擇剛建立的 Tunnel，或貼上 Tunnel ID。
5. 驗證方式：示範與 DBHub 都未設定驗證，選無驗證選項。
6. 畫面會出現「自訂 MCP 伺服器會帶來風險。」的提示。這是 ChatGPT 對所有自訂 MCP 的通用警告，確認你信任這個伺服器後再繼續。
7. 完成建立，開啟新聊天，選用這個自訂 MCP，測試工具。

可以輸入：

> 請使用這個 MCP 的 echo 工具，回傳「你好，Tunnel」。

若 ChatGPT 確實呼叫工具並取得結果，代表 ChatGPT 到本機示範的完整路徑成功。

Runtime API Key 留在電腦上供 tunnel-client 使用，ChatGPT 的 MCP 驗證欄位是另一層設定，**不要把 Runtime API Key 填進去**。

## 9. 改接 DBHub

示範測試成功後，在原 PowerShell 按 **Ctrl＋C** 停止示範，再擇一：

| | 方式 A：由 tunnel-client 啟動 DBHub（stdio） | 方式 B：連到已用 Docker 常駐的 DBHub（HTTP） |
|---|---|---|
| 適合 | 每人電腦各自啟動 | 一台常駐主機 |
| 需要先準備 | 已安裝 **Node.js** 22.5 以上、有 `dbhub.toml` 與 `.env` | 已依 [Docker使用說明.md](Docker使用說明.md) 啟動，`http://127.0.0.1:18080/healthz` 回傳 `OK` |

### 方式 A：stdio

先進入**放有 `.env` 與 `dbhub.toml` 的專案資料夾**（`.env` 的密碼要從這裡讀取），再用 tunnel-client 的**完整路徑**執行。下面假設專案在 `C:\work\dbhub`、tunnel-client 在 `C:\Tools\tunnel-client`：

```powershell
Set-Location C:\work\dbhub
C:\Tools\tunnel-client\tunnel-client.exe init --sample sample_mcp_stdio_local --profile dbhub-stdio --tunnel-id $env:CONTROL_PLANE_TUNNEL_ID --mcp-command "npx -y @bytebase/dbhub@1.5.0 --config ./dbhub.toml"
C:\Tools\tunnel-client\tunnel-client.exe doctor --profile dbhub-stdio --explain
C:\Tools\tunnel-client\tunnel-client.exe run --profile dbhub-stdio
```

- 設定檔路徑請用絕對路徑，並用 `/` 取代 `\`。
- 版本固定為 `1.5.0`，不要改成 `@latest`。
- Windows 的 `npx` 若在 `doctor` 階段啟動失敗，可改把命令包成 `cmd /c npx -y ...`，以 `doctor` 輸出為準。
- 同一個 Tunnel ID 同時只能有一個 stdio 的 tunnel-client；重新啟動前必須先停止舊的程式。

### 方式 B：HTTP

DBHub 的 MCP 端點是 `http://127.0.0.1:18080/mcp`。tunnel-client 必須與 DBHub 在**同一台電腦**。這個架構**不要**設定 `DBHUB_AUTH_TOKEN`，保護靠 DBHub 只綁本機、私有隧道與唯讀資料庫帳號。

```powershell
./tunnel-client.exe init --profile dbhub-http --tunnel-id $env:CONTROL_PLANE_TUNNEL_ID --mcp-server-url "http://127.0.0.1:18080/mcp" --health-listen-addr "127.0.0.1:8080"
./tunnel-client.exe doctor --profile dbhub-http --explain
./tunnel-client.exe run --profile dbhub-http
```

若 `doctor` 對 `http://` 位址有警告，請依輸出判斷；本專案尚未對這個組合做過長期實測。DBHub 若比 tunnel-client 晚啟動，可調整 `mcp.startup_wait_timeout`（例如 `2m`）。

tunnel-client 的公開說明沒有設定「轉送 Authorization 標頭」的選項，且明文 HTTP 可能只允許本機位址，所以**不要**讓 tunnel-client 連到區域網路上另一台電腦的 DBHub。

### 共同注意

- 隧道只保護網路路徑。DBHub 仍必須使用**唯讀資料庫帳號**，並在 TOML 設定 `readonly = true` 與 `max_rows`。
- 在 ChatGPT 新增連接器的步驟同第 8 節；測試時改問「請列出資料庫裡有哪些資料表」。

### 如何理解 profile？

Profile 就像「記住設定的便條紙」。`init` 建立設定，`doctor` 檢查，`run` 執行。已建立 profile 後，日後不必每次重新執行 `init`。秘密應保留為環境變數參照，不要寫成設定檔裡的明文 Key。

## 10. 日常啟動與停止（Windows）

每次使用時：

1. 打開 PowerShell，進入 `tunnel-client.exe` 所在資料夾。
2. 依第 6 節重新設定 Runtime API Key 與 Tunnel ID。
3. 方式 B 先確認 DBHub 已啟動；方式 A 要在專案資料夾執行。
4. 啟動之前建立的 profile：

```powershell
./tunnel-client.exe run --profile dbhub-http
```

停止時按 **Ctrl＋C**。停止程式、關閉電腦或電腦休眠後，ChatGPT 就無法經由這台電腦使用 DBHub。本文使用前景執行，**Windows 尚未設定開機自動啟動**；長期常駐請用 Ubuntu 的 systemd（第 11 節），或自行用 Windows 工作排程器處理。

使用完畢可移除秘密：

```powershell
Remove-Item Env:CONTROL_PLANE_API_KEY
```

## 11. Ubuntu 附錄

概念與第 1～10 節相同，差別在安裝與環境變數。以下步驟依官方說明與常見做法整理，**尚未在 Ubuntu 實測**，請以 `doctor` 輸出為準。

**安裝**：從[官方 Releases](https://github.com/openai/tunnel-client/releases/latest) 下載 Linux 版（x86_64 選 amd64，ARM 選 arm64），解壓縮後放到例如 `/opt/tunnel-client/`，並給執行權限：

```bash
chmod +x /opt/tunnel-client/tunnel-client
/opt/tunnel-client/tunnel-client --version
```

**設定環境變數**（只在目前終端有效；避免把真實 Key 留在命令歷史，可先在指令前加一個空格，或改用下面的 systemd 設定檔）：

```bash
export CONTROL_PLANE_API_KEY="貼上 Runtime API Key"
export CONTROL_PLANE_TUNNEL_ID="貼上 Tunnel ID"
```

`init`、`doctor`、`run` 的指令與第 9 節相同，把 `./tunnel-client.exe` 換成 `/opt/tunnel-client/tunnel-client`，路徑用 `/`。方式 A 需要先安裝 Node.js 22.5 以上。

**開機自動啟動（systemd）**：

1. 建立只有自己能讀的環境檔 `/etc/tunnel-client.env`：

   ```bash
   sudo install -m 600 /dev/null /etc/tunnel-client.env
   sudo nano /etc/tunnel-client.env
   ```

   內容：

   ```text
   CONTROL_PLANE_API_KEY=貼上 Runtime API Key
   CONTROL_PLANE_TUNNEL_ID=貼上 Tunnel ID
   ```

2. 建立 `/etc/systemd/system/tunnel-client.service`（方式 B 的範例；方式 A 要把 `WorkingDirectory` 設為放有 `.env` 與 `dbhub.toml` 的資料夾，並改用對應的 profile）：

   ```ini
   [Unit]
   Description=OpenAI tunnel-client for DBHub
   After=network-online.target docker.service
   Wants=network-online.target

   [Service]
   EnvironmentFile=/etc/tunnel-client.env
   WorkingDirectory=/opt/tunnel-client
   ExecStart=/opt/tunnel-client/tunnel-client run --profile dbhub-http
   Restart=on-failure
   RestartSec=10

   [Install]
   WantedBy=multi-user.target
   ```

3. 啟用並查看狀態：

   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now tunnel-client
   systemctl status tunnel-client
   journalctl -u tunnel-client -n 50
   ```

`init` 建立的 profile 存放位置依官方預設而定；以 systemd 執行時，需確認服務使用者能讀到同一份 profile，否則請改用 `run` 的命令列參數。這一點同樣需要實測確認。

macOS、Kubernetes、Go SDK、原始碼編譯等其他部署方式，請看官方 [tunnel-client 專案](https://github.com/openai/tunnel-client)。

## 12. 常見問題

| 狀況 | 優先檢查 |
| --- | --- |
| 看不到 Tunnels 頁面或建立按鈕 | 組織是否正確、帳號是否有 Read＋Manage |
| 找不到 `tunnel-client.exe` | 是否已解壓縮、是否進入該資料夾、是否寫成 `./tunnel-client.exe` |
| 出現 401 | Key 是否正確、有效，是否已在目前視窗設定 |
| 執行時出現 403 | Key 與建立者是否有目標 Tunnel 的 Read＋Use |
| Platform 有 Tunnel，ChatGPT 選不到 | 該 Tunnel 是否與這個 ChatGPT 帳號所用的組織／工作區關聯，見 [ChatGPT連接說明.md](ChatGPT連接說明.md) |
| DBHub 連線失敗 | DBHub 是否啟動、網址或啟動命令是否正確、`.env` 是否在執行目錄 |
| 狀態頁打不開 | 程式是否仍執行、健康檢查埠是否被占用 |
| 公司網路無法連線 | 是否允許對 OpenAI 的 outbound HTTPS、是否需要代理或企業憑證 |
| 重開機後 Key 消失 | Windows 的設定只存在目前視窗，需重新輸入；Ubuntu 請用 systemd 環境檔 |

通道本身不需要開放外網入站埠。執行主機只需要能向 OpenAI 發起 HTTPS 連線，並能連到 DBHub。

## 13. 完成確認

- [ ] 已取得平台建立的 Tunnel ID，並建立具有 Read＋Use 權限的 Runtime API Key。
- [ ] 執行檔能顯示版本。
- [ ] 內建示範健康且就緒，ChatGPT 能呼叫示範工具。
- [ ] 改接 DBHub 後 `doctor` 通過，ChatGPT 能列出資料表。
- [ ] 使用唯讀資料庫帳號，TOML 已設定 `readonly = true` 與 `max_rows`。
- [ ] 真實 Key 未寫入文件、截圖或版本控制。

## 參考資料

- [OpenAI Secure MCP Tunnel 官方指南](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels)
- [OpenAI 新增自訂 MCP 指南](https://developers.openai.com/api/docs/guides/custom-mcp-server)
- [OpenAI tunnel-client 專案](https://github.com/openai/tunnel-client)
- [ChatGPT連接說明.md](ChatGPT連接說明.md)：方案選擇與待決定事項
- [Docker使用說明.md](Docker使用說明.md)：讓 DBHub 常駐（方式 B 需要）
