# Secure MCP Tunnel 安裝與設定指南

適用對象：第一次使用 MCP Tunnel 的使用者。本文以 Windows 與 PowerShell 為主，並附上其他平台的安裝方式。

本指南依據 OpenAI 官方文件與本專案文件整理，核對日期為 2026 年 10 月 8 日。網頁按鈕名稱、功能開放範圍及權限介面可能調整，請以登入後的實際畫面為準。

## 1. 先認識需要的東西

把 MCP Tunnel 想成一位傳話員：ChatGPT 請它把工作交給你電腦上的工具，再把結果帶回來。

```text
ChatGPT ⇄ OpenAI Tunnel ⇄ tunnel-client ⇄ MCP 伺服器
                              ↑
                         在你的電腦執行
```

| 名稱 | 簡單比喻 | 實際用途 |
| --- | --- | --- |
| Tunnel ID | 通道的門牌號碼 | 指定要使用哪條通道 |
| Runtime API Key | 通道的鑰匙 | 讓 tunnel-client 有權使用通道 |
| tunnel-client | 傳話員 | 接收 OpenAI 的請求，轉交給 MCP 伺服器 |
| MCP 伺服器 | 真正做事的人 | 提供查詢資料、操作工具等功能 |

tunnel-client 不會自動變成資料庫查詢工具。若要查詢 MySQL，仍需要一個提供資料庫工具的 MCP 伺服器。第一次測試可以先使用內建示範，不必先準備自己的 MCP。

整體流程：確認權限 → 建立 Tunnel → 建立 Runtime API Key → 安裝 → 測試示範 → 連接 ChatGPT → 改接自己的 MCP。

## 2. 確認帳號與權限

登入 [OpenAI Platform](https://platform.openai.com/)，切換到要使用的組織。

| 工作 | 所需 Tunnels 權限 |
| --- | --- |
| 建立或修改 Tunnel | Read（讀取）＋Manage（管理） |
| 執行 tunnel-client 或選用 Tunnel | Read（讀取）＋Use（使用） |
| 自己建立並執行 | Read＋Manage＋Use |

權限不足時，請組織擁有者或權限管理員在 [組織角色設定](https://platform.openai.com/settings/organization/people/roles) 配置角色並指派給你。也可透過 [組織群組](https://platform.openai.com/settings/organization/people/groups) 指派角色。

Platform 的 Tunnel 權限和 ChatGPT 的自訂 MCP 權限是分開的。若要連接 ChatGPT，還需要目標工作區允許新增及使用自訂 MCP。看不到相關功能時，應先確認組織、工作區與帳號權限；重新安裝程式無法解決權限問題。

## 3. 建立 Tunnel ID

1. 開啟 [Tunnels 管理頁](https://platform.openai.com/settings/organization/tunnels)。
2. 確認目前選到正確的組織。
3. 選擇建立 Tunnel 的按鈕，例如 **Create tunnel**。
4. 輸入方便辨識的名稱，例如 `my-local-mcp`。
5. 若有描述欄位，可填入「Windows 本機 MCP」。
6. 依畫面設定組織或工作區關聯。如果要讓 ChatGPT 工作區使用，確認已關聯到目標工作區。
7. 建立後，複製平台產生的 Tunnel ID。

Tunnel ID 的格式如下，這是範例，不能直接拿來使用：

```text
tunnel_0123456789abcdef0123456789abcdef
```

請使用平台實際產生的 ID，不要自己編造。建立後可稍等約 30 秒再測試。

如果組織與 ChatGPT 工作區的關聯無法自動驗證，請由管理員確認帳戶關聯，必要時聯絡 OpenAI 帳戶團隊。

## 4. 建立 Runtime API Key

Runtime API Key 是給電腦上的 tunnel-client 使用的鑰匙。

1. 開啟 [Runtime API Keys](https://platform.openai.com/settings/organization/api-keys)。
2. 確認使用與 Tunnel 相同的組織。
3. 選擇新增 API Key，名稱可填 `windows-tunnel-client`。
4. 權限選 **Restricted（受限）**。
5. 找到 **Tunnels**，啟用 **Read＋Use**。
6. 建立後複製 Key，妥善保存在密碼管理器。

Key 的建立者本身也必須有目標 Tunnel 的 Read＋Use 權限。Key 的權限不能超過使用它的帳號原本具有的權限。

不要把真實 Key 貼到聊天、截圖、公開文件或 Git。若無法再次查看完整 Key，遺失時應重新建立；外洩時應撤銷並換發。

### 是否需要 Admin API Key？

本指南使用網頁建立 Tunnel，因此不需要 Admin API Key。

| Key 類型 | 用途 |
| --- | --- |
| Runtime API Key | 執行 `doctor` 與 `run`，供通道日常使用 |
| Admin API Key | 用命令列列出、建立、修改或刪除 Tunnel |

不要把 Admin API Key 放進長時間執行的 tunnel-client 設定。

## 5. 安裝 Windows 執行檔

### 5.1 下載並解壓縮

1. 從 [Tunnels 管理頁](https://platform.openai.com/settings/organization/tunnels) 的下載連結取得 Windows 版本，也可使用官方 [最新公開版本](https://github.com/openai/tunnel-client/releases/latest)。
2. 一般 Intel／AMD Windows 電腦選 **amd64／x64**；Windows ARM 電腦選 **arm64**。可在 Windows「設定 → 系統 → 關於 → 系統類型」確認。
3. 解壓縮整個壓縮檔，例如放在 `C:\Tools\tunnel-client`。如果沒有該資料夾的寫入權限，也可以放在自己的使用者資料夾。
4. 保留壓縮檔附帶的其他檔案。
5. 在包含 `tunnel-client.exe` 的資料夾開啟 PowerShell。

例如：

```powershell
Set-Location C:\Tools\tunnel-client
```

本文路徑只是範例，請換成實際解壓縮位置。若執行檔位於解壓縮後的子資料夾，請進入那個子資料夾。

### 5.2 確認可以執行

```powershell
.\tunnel-client.exe --version
.\tunnel-client.exe help quickstart
```

能顯示版本與說明，就代表程式可以啟動。PowerShell 指令前面的 `.\` 表示「執行目前資料夾裡的程式」。

## 6. 設定 API Key 與 Tunnel ID

在同一個 PowerShell 視窗執行下面指令，再依提示輸入 Runtime API Key。輸入時不會顯示明文：

```powershell
$tunnelSecret = Read-Host "請輸入 Runtime API Key" -AsSecureString
$env:CONTROL_PLANE_API_KEY = [System.Net.NetworkCredential]::new("", $tunnelSecret).Password
Remove-Variable tunnelSecret
```

接著設定 Tunnel ID，把引號裡的文字換成真正的 ID：

```powershell
$env:CONTROL_PLANE_TUNNEL_ID = "貼上平台產生的 Tunnel ID"
```

這是把鑰匙和門牌交給目前 PowerShell 啟動的程式。API Key 在執行期間仍是程式可以讀取的秘密；不要列印環境變數或分享包含秘密的診斷輸出。

這些設定只存在目前的 PowerShell 工作階段。關閉視窗後，下次要重新設定。

## 7. 先執行內建示範

先用內建 MCP 示範，確認 Tunnel 設定可以運作：

```powershell
.\tunnel-client.exe run --embedded-stateless-mcp-stub --health.listen-addr 127.0.0.1:8080
```

保持 PowerShell 開著，在瀏覽器開啟：

[本機狀態頁：http://127.0.0.1:8080/ui](http://127.0.0.1:8080/ui)

查看健康、就緒與連線狀態。程式已啟動不代表已經連線成功；還要確認它準備好接收請求。

示範提供 `server_info`、`echo` 與 `uppercase` 等工具。

如果 8080 埠被占用，改用 8081：

```powershell
.\tunnel-client.exe run --embedded-stateless-mcp-stub --health.listen-addr 127.0.0.1:8081
```

此時狀態頁改為 [http://127.0.0.1:8081/ui](http://127.0.0.1:8081/ui)。

## 8. 在 ChatGPT 連接 Tunnel

保持示範程式執行，再進行以下操作：

1. 開啟 ChatGPT 的 **Plugins** 頁面。
2. 選擇加號，再選 **Add custom MCP server**。
3. 在 **Connection** 選擇 **Tunnel**。
4. 選擇剛建立的 Tunnel，或貼上 Tunnel ID。
5. 依 MCP 伺服器本身的設定選擇驗證方式。若示範服務未設定驗證，選擇介面提供的無驗證選項。
6. 閱讀畫面上的提示並確認，完成建立。
7. 開啟新聊天，選用這個自訂 MCP，測試工具。

可以輸入：

> 請使用這個 MCP 的 echo 工具，回傳「你好，Tunnel」。

若 ChatGPT 確實呼叫工具並取得結果，就代表 ChatGPT 到本機示範的完整路徑已經成功。

Runtime API Key 留在電腦上，供 tunnel-client 使用。ChatGPT 的 MCP 驗證欄位是另一層設定，不要把 Runtime API Key 當成 MCP 的登入密碼填入。

若看不到新增功能或 Tunnel 選項，請確認帳號及工作區權限。介面名稱可能調整，可參考 [官方新增自訂 MCP 說明](https://developers.openai.com/api/docs/guides/custom-mcp-server)。

## 9. 改接自己的 MCP 伺服器

示範測試成功後，在原 PowerShell 按 **Ctrl＋C** 停止示範，再依 MCP 類型選擇下面其中一種方式。

### 方式 A：MCP 有 HTTP 網址

假設 MCP 端點是 `http://127.0.0.1:3000/mcp`。先依該 MCP 的說明啟動伺服器，再建立設定：

```powershell
.\tunnel-client.exe init --profile local-http --tunnel-id $env:CONTROL_PLANE_TUNNEL_ID --mcp-server-url "http://127.0.0.1:3000/mcp" --health-listen-addr "127.0.0.1:8080"
```

如果 8080 埠被占用，改用 8081：
```powershell
.\tunnel-client.exe init --profile local-http --tunnel-id $env:CONTROL_PLANE_TUNNEL_ID --mcp-server-url "http://127.0.0.1:3000/mcp" --health-listen-addr "127.0.0.1:8081"
```

請把網址換成真正支援 MCP Streamable HTTP 的端點。普通網頁、一般 REST API 或 MySQL 的 3306 埠，不能直接當成 MCP 端點。

檢查設定：

```powershell
.\tunnel-client.exe doctor --profile local-http --explain
```

依檢查結果修正問題，通過後啟動：

```powershell
.\tunnel-client.exe run --profile local-http
```

### 方式 B：MCP 用命令啟動（stdio）

假設已有支援 stdio 的 MCP 程式 `C:\mcp\server.py`，且已安裝它需要的 Python 與套件：

```powershell
.\tunnel-client.exe init --sample sample_mcp_stdio_local --profile local-stdio --tunnel-id $env:CONTROL_PLANE_TUNNEL_ID --mcp-command "python C:/mcp/server.py"
```

請替換成實際啟動命令。範例不會替你建立 `server.py`；該檔案必須本來就是 MCP 伺服器。

檢查並啟動：

```powershell
.\tunnel-client.exe doctor --profile local-stdio --explain
.\tunnel-client.exe run --profile local-stdio
```

這種方式由 tunnel-client 啟動 MCP 子程式。同一個 Tunnel ID 只能有一個使用 stdio 的活躍 tunnel-client；重新啟動前，必須先停止舊的程式。

### 接 DBHub（本專案的實際用法）

上面兩種方式的範例用的是通用 MCP。要接本專案的 DBHub，擇一：

| | 方式 A：由 tunnel-client 啟動 DBHub（stdio） | 方式 B：連到已用 Docker 常駐的 DBHub（HTTP） |
|---|---|---|
| 適合 | 一個人使用、快速試用 | 多人共用、長期使用 |
| 需要先準備 | 已安裝 **Node.js**、有 `dbhub.toml` 與 `.env` | 已依 [Docker使用說明.md](Docker使用說明.md) 啟動，`http://127.0.0.1:18080/healthz` 回傳 `OK` |

**方式 A：stdio**

先在 PowerShell 進入**放有 `.env` 與 `dbhub.toml` 的專案資料夾**（`.env` 中的密碼要從這裡讀取），再用 tunnel-client 的**完整路徑**執行。下面假設專案在 `C:\work\dbhub`、tunnel-client 在 `C:\Tools\tunnel-client`：

```powershell
Set-Location C:\work\dbhub
C:\Tools\tunnel-client\tunnel-client.exe init --sample sample_mcp_stdio_local --profile dbhub-stdio --tunnel-id $env:CONTROL_PLANE_TUNNEL_ID --mcp-command "npx -y @bytebase/dbhub@1.5.0 --config ./dbhub.toml"
C:\Tools\tunnel-client\tunnel-client.exe doctor --profile dbhub-stdio --explain
C:\Tools\tunnel-client\tunnel-client.exe run --profile dbhub-stdio
```

- 設定檔路徑請用絕對路徑，並用 `/` 取代 `\`。
- 版本固定為 `1.5.0`，不要改成 `@latest`。
- Windows 的 `npx` 若在 `doctor` 階段啟動失敗，可改把命令包成 `cmd /c npx -y ...`；以 `doctor` 輸出為準。
- 同一個 Tunnel ID 同時只能有一個 stdio 的 tunnel-client。

**方式 B：HTTP（DBHub 已用 Docker 常駐）**

此時 DBHub 的 MCP 端點是 `http://127.0.0.1:18080/mcp`。這個架構**不要**設定 `DBHUB_AUTH_TOKEN`，保護靠 DBHub 只綁本機、私有隧道與唯讀資料庫帳號。

```powershell
./tunnel-client.exe init --profile dbhub-http --tunnel-id $env:CONTROL_PLANE_TUNNEL_ID --mcp-server-url "http://127.0.0.1:18080/mcp" --health-listen-addr "127.0.0.1:8080"
./tunnel-client.exe doctor --profile dbhub-http --explain
./tunnel-client.exe run --profile dbhub-http
```

若 `doctor` 對 `http://` 位址有警告，請依輸出判斷；本專案尚未對這個組合做過長期實測。DBHub 若比 tunnel-client 晚啟動，可調整 `mcp.startup_wait_timeout`（例如 `2m`）。

**共同注意**：

- 隧道只保護網路路徑。DBHub 仍必須使用**唯讀資料庫帳號**，並在 TOML 設定 `readonly = true` 與 `max_rows`。
- 在 ChatGPT 新增連接器的步驟同第 8 節；測試時改問「請列出資料庫裡有哪些資料表」。

### 如何理解 profile？

Profile 就像「記住設定的便條紙」。`init` 建立設定，`doctor` 檢查，`run` 執行。已建立 profile 後，日後不必每次重新執行 `init`。秘密應保留為環境變數參照，不要寫成設定檔裡的明文 Key。

## 10. 日常啟動與停止

每次使用時：

1. 打開 PowerShell，進入執行檔(tunnel-client.exe)資料夾。
2. 依第 6 節重新設定 Runtime API Key。
3. HTTP 模式先確認 MCP 伺服器已經啟動。
4. 啟動之前建立的 profile：

```powershell
.\tunnel-client.exe run --profile local-http
```

stdio 模式則使用 `--profile local-stdio`。

停止時按 **Ctrl＋C**。停止程式、關閉電腦或電腦休眠後，ChatGPT 就無法經由這台電腦使用 MCP。本文使用前景執行，尚未設定開機自動啟動。

使用完畢後，也可從目前視窗移除秘密：

```powershell
Remove-Item Env:CONTROL_PLANE_API_KEY
```

## 11. 其他安裝方式

以下方式取代第 5 節的 Windows 安裝，其餘 Tunnel、權限與 Key 的概念相同。

| 方式 | 適用情境 | 操作或文件 |
| --- | --- | --- |
| macOS Homebrew | macOS 一般使用者 | `brew install openai/tools/tunnel-client` |
| Linux 執行檔 | Linux 主機 | 從官方下載入口選擇 Linux 及相符架構版本 |
| 原始碼編譯 | 需要開發或自訂版本 | 見下方說明 |
| Docker／Compose | 希望用容器管理環境 | 見官方 [tunnel-client 專案](https://github.com/openai/tunnel-client) 的部署文件 |
| Kubernetes | 已有 Kubernetes 環境 | 同上 |
| VM／systemd | Linux 上長期執行 | 同上 |
| Go SDK | 在 Go MCP 程式內直接整合 | 同上 |

macOS 官方支援使用 Homebrew 安裝。直接下載的 ZIP 可能被 Gatekeeper 阻擋；遇到這種情況，請使用官方 Homebrew 安裝路徑。

### 從原始碼編譯（Windows）

需要 Git、Go，以及專案要求的相依套件。目前這份專案的 `go.mod` 指定 Go 1.27.0；請以使用版本的 `go.mod` 為準。

```powershell
git clone https://github.com/openai/tunnel-client.git
Set-Location tunnel-client
go version
go build -o .\bin\tunnel-client.exe ./cmd/client
.\bin\tunnel-client.exe --version
```

後續指令改用 `.\bin\tunnel-client.exe`。若修改管理介面，還需要依官方專案的開發文件重建管理介面資產；使用未修改且已包含資產的原始碼時，可以直接編譯執行檔。

macOS／Linux 的環境變數語法與 PowerShell 不同，例如 `export CONTROL_PLANE_API_KEY="..."`；請依平台調整，並避免把真實 Key 留在命令歷史中。

## 12. 常見問題

| 狀況 | 優先檢查 |
| --- | --- |
| 看不到 Tunnels 頁面或建立按鈕 | 組織是否正確、帳號是否有 Read＋Manage、功能是否可用 |
| 找不到 `tunnel-client.exe` | 是否已解壓縮、是否進入執行檔所在資料夾、是否加上 `.\` |
| 出現 401 | Key 是否正確、有效，是否已在目前視窗設定 |
| 執行時出現 403 | Key 與建立者是否有目標 Tunnel 的 Read＋Use |
| Platform 有 Tunnel，ChatGPT 沒有 | 工作區關聯、ChatGPT 自訂 MCP 權限與 Tunnel 使用權限 |
| MCP 連線失敗 | MCP 是否啟動、網址或啟動命令是否正確 |
| 狀態頁打不開 | 程式是否仍執行、健康檢查埠是否被占用 |
| 公司網路無法連線 | 是否允許對 OpenAI 的 outbound HTTPS、是否需要代理或企業 CA |
| 重啟後 Key 消失 | 目前流程只設定工作階段環境變數，需重新輸入 |

通道本身不需要開放外網入站埠。執行主機需要向 OpenAI 發起 HTTPS 連線，並能存取 MCP。企業代理、憑證與 mTLS 設定請參考官方 [tunnel-client 專案](https://github.com/openai/tunnel-client) 的部署文件。

## 13. 完成確認

- [ ] 已取得平台建立的 Tunnel ID。
- [ ] 已建立具有 Read＋Use 權限的 Runtime API Key。
- [ ] 執行檔能顯示版本。
- [ ] 內建示範健康且就緒。
- [ ] ChatGPT 能實際呼叫示範工具並取得結果。
- [ ] 改接自己的 MCP 後，`doctor` 通過且工具呼叫成功。
- [ ] 真實 Key 未寫入文件、截圖或版本控制。

## 參考資料

- [OpenAI Secure MCP Tunnel 官方指南](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels)
- [OpenAI 新增自訂 MCP 指南](https://developers.openai.com/api/docs/guides/custom-mcp-server)
- [OpenAI tunnel-client 專案](https://github.com/openai/tunnel-client)
- [ChatGPT連接說明.md](ChatGPT連接說明.md)：方案選擇與多人使用
- [Docker使用說明.md](Docker使用說明.md)：讓 DBHub 常駐（方式 B 需要）

