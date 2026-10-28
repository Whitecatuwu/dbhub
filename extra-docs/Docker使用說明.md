# DBHub 完整安裝教學（繁體中文・初學者版）

適用情境：在 Windows 電腦上，使用 Docker 啟動這份專案，連接已存在的 MySQL，讓瀏覽器或支援 MCP 的 AI 工具查詢資料。

本文件以本專案的 Compose、Dockerfile 與 DBHub 1.5.0 原始碼為準。所有指令都在 **PowerShell** 執行；範例的路徑、資料庫、帳號與密碼要換成自己的資料。

> **Ubuntu 等 Linux 主機**：第 5 節之後的 `docker compose` 指令相同。Compose 已設定 `host.docker.internal:host-gateway`，容器可用 `host.docker.internal` 連到主機上的資料庫。差別只在 Docker 安裝（改裝 Docker Engine，見[官方說明](https://docs.docker.com/engine/install/ubuntu/)，不需要 Docker Desktop 與 WSL），以及建立檔案時用 `nano .env` 取代 `notepad .env`，檢查檔案存在用 `ls -a`。此處未在 Ubuntu 實測，請以實際輸出為準。

## 1. 先用最簡單的方式理解

MySQL 像存資料的倉庫，DBHub 像協助查詢倉庫的服務員，Docker 則是裝好這位服務員與所需工具的盒子。

```text
瀏覽器／AI 工具 → DBHub（Docker 容器）→ MySQL（既有資料庫）
```

MCP 是 AI 工具與外部服務溝通的規則。DBHub 提供 MCP 接口，讓相容的 AI 工具搜尋資料表與執行 SQL。

| 完成後的用途 | 預設網址 |
|---|---|
| DBHub 網頁 | `http://localhost:18080` |
| MCP 接口 | `http://localhost:18080/mcp` |
| 健康檢查 | `http://localhost:18080/healthz` |

這份 Compose **只啟動 DBHub，不會安裝 MySQL，也不會建立資料庫或帳號**。沒有 MySQL 時，請先由資料庫管理者準備可連線的資料庫。

## 2. 安裝 Docker Desktop

Docker 方式已包含所需的 Node.js，不需要另外安裝任何程式執行環境。

1. 開啟 [Docker Desktop Windows 官方安裝頁](https://docs.docker.com/desktop/setup/install/windows-install/)，確認系統需求並下載適合電腦架構的安裝程式。
2. 執行安裝程式，使用 WSL 2 後端；依提示重新啟動電腦。
3. 開啟 Docker Desktop，等待引擎啟動，確認使用 **Linux containers**。
4. 開啟 PowerShell，逐行執行：

```powershell
docker version
docker compose version
```

第一個指令應顯示 Client 與 Server 資訊，第二個應顯示 Compose 版本。Docker Desktop 已包含 Compose，詳見 [Compose 官方安裝說明](https://docs.docker.com/compose/install/)。

若 Docker Desktop 提示需要安裝或更新 WSL，依官方說明，以系統管理員身分開啟 PowerShell，選擇適用的指令：

```powershell
# 尚未安裝 WSL
wsl --install

# 已安裝 WSL，需要更新
wsl --update
```

依提示重開機，再開啟 Docker Desktop。公司電腦若限制安裝或虛擬化，請由 IT 協助。

## 3. 取得完整專案並進入資料夾

請向提供這份教學的人取得**與文件一起交付的完整專案副本**，解壓縮到例如 `C:\work\dbhub`。

這份教學使用額外提供的 Docker 檔案，只下載上游 DBHub 原始碼不一定有這些檔案。不要只複製本文件。

完整副本至少要包含：

```text
dbhub/
├─ compose-dbhub.yaml       ← 啟動規則
├─ Dockerfile.dbhub         ← 建置規則
├─ .dockerignore            ← 排除不該放進映像的檔案
├─ .gitignore               ← 排除不該提交到 Git 的檔案
├─ package.json
├─ pnpm-lock.yaml
├─ pnpm-workspace.yaml
├─ tsconfig.json
├─ tsup.config.ts
├─ src/                     ← 後端程式
└─ frontend/                ← 網頁程式
```

提供者分享前應排除自己的 `.env`、`.env.local`、`dbhub.toml`、`dbhub.docker.toml`、`.git` 與日誌。接收者依下一節建立自己的設定。

```powershell
Set-Location "C:\work\dbhub"
Get-ChildItem -Force
```

請替換成實際路徑。以下所有 Docker 指令都在這個資料夾執行；重新開啟 PowerShell 後，也要先進入此資料夾。

## 4. 準備 MySQL 連線資料

請向資料庫管理者取得主機、埠、資料庫名稱、帳號與密碼。主機是倉庫的地址，埠是門號，帳號與密碼則決定你能否進入。

| MySQL 在哪裡 | TOML 的 `host` | TOML 的 `port` |
|---|---|---|
| 同一台 Windows，MySQL 使用 3306 | `host.docker.internal` | `3306` |
| 同一台 Windows 的 Docker，映射為 `3307:3306` | `host.docker.internal` | `3307` |
| 另一台電腦或公司伺服器 | 實際 IP 或主機名稱 | 管理者提供的埠 |

**容器裡的 `localhost` 是容器自己。** DBHub 要連到 Windows 電腦上的 MySQL，應使用 `host.docker.internal`。

`3307:3306` 表示 Windows 的 3307 轉接到 MySQL 容器的 3306。本教學從 Windows 入口連線，所以填 3307；沒有這個映射就不要照填。

建議使用只可讀取指定資料庫的帳號，例如 `dbhub_reader`。MySQL 帳號也會限制允許登入的來源；只能從 MySQL 自己的 `localhost` 登入的帳號，可能無法接受 DBHub 容器的連線。請管理者確認來源限制與防火牆。

## 5. 建立兩份設定檔

兩份檔案放在 `compose-dbhub.yaml` 旁邊。若已存在，先確認再修改，避免覆蓋原本可用的設定。

### 5.1 `.env`：密碼與對外埠

```powershell
notepad .env
```

若記事本詢問是否建立檔案，選擇建立。貼上以下內容，修改密碼後儲存：

```dotenv
# Windows 上用來開啟 DBHub 的埠
DBHUB_DOCKER_PORT=18080

# 改成管理者提供的密碼
DBHUB_MYSQL_PASSWORD='請替換成實際密碼'
```

檔名必須是 `.env`，不是 `.env.txt`。使用 UTF-8 儲存；「另存新檔」時，檔案類型選「所有檔案」。

單引號可保留密碼中的 `#` 與空白等常見字元。若密碼本身含單引號，需要改用合適的 dotenv 引號寫法，不要直接混用外層引號。個別參數方式不需要把密碼轉成網址編碼。

**本教學不需要加入 `READONLY` 或 `DSN`。** 此版本不支援 `READONLY` 環境變數；唯讀限制設在 TOML。Compose 已指定 HTTP 模式、容器埠 8080 與監聽位址，不需要在 `.env` 重複設定。

### 5.2 `dbhub.docker.toml`：資料庫與工具規則

```powershell
notepad dbhub.docker.toml
```

貼上完整範例，再依自己的環境修改 `host`、`port`、`database`、`user`：

```toml
[[sources]]
id = "company_mysql"
description = "提供唯讀查詢的 MySQL 資料庫"
type = "mysql"
host = "host.docker.internal"
port = 3307
database = "product"
user = "dbhub_reader"
password = "${DBHUB_MYSQL_PASSWORD}"
connection_timeout = 15
query_timeout = 30

[[tools]]
name = "search_objects"
source = "company_mysql"

[[tools]]
name = "execute_sql"
source = "company_mysql"
readonly = true
max_rows = 1000
```

| 設定 | 白話說明 |
|---|---|
| `[[sources]]` | 一個資料庫連線 |
| `id` | 連線的名稱，工具的 `source` 必須與它相同 |
| `password = "${DBHUB_MYSQL_PASSWORD}"` | 從 `.env` 取密碼，保留這行文字，別貼入真實密碼 |
| `connection_timeout = 15` | 建立連線等待上限，單位為秒 |
| `query_timeout = 30` | 查詢逾時設定，單位為秒 |
| `search_objects` | 搜尋資料表、欄位等物件 |
| `execute_sql` | 執行 SQL |
| `readonly = true` | 將 SQL 工具限制為唯讀操作 |
| `max_rows = 1000` | 限制回傳列數；不是限制 SQL 掃描的資料量 |

工具設為唯讀，也應搭配資料庫的唯讀帳號。資料庫帳號本身的權限仍然生效。

本機直接執行通常使用 `dbhub.toml`；**這份 Compose 讀取的是 `dbhub.docker.toml`**，將它掛載成容器的 `/app/dbhub.toml`。只修改 Windows 上的 `dbhub.toml` 不會改到 Docker 服務。若兩份都使用，需要各自維護。

## 6. 建置並啟動

先確認檔案存在：

```powershell
Test-Path .env
Test-Path dbhub.docker.toml
```

兩個結果都應為 `True`。檢查 Compose 格式：

```powershell
docker compose -f ./compose-dbhub.yaml config --quiet
```

沒有錯誤代表 Compose 格式可解析，這一步還沒有驗證資料庫帳密。啟動服務：

```powershell
docker compose -f ./compose-dbhub.yaml up -d --build
```

第一次會下載基礎映像、安裝套件與建置程式，需要網路連線，可能花數分鐘。完成後服務會在背景執行，可以關閉 PowerShell。

`-f` 指定啟動檔，`-d` 表示背景執行，`--build` 表示先建置。`dbhub-local:1.5.0` 是這份原始碼建置的本機映像標籤。

```powershell
docker compose -f ./compose-dbhub.yaml ps
docker compose -f ./compose-dbhub.yaml logs --tail 100 dbhub
```

服務應持續執行，健康狀態稍後變為 `healthy`。剛啟動時的 `health: starting` 是等待狀態，稍候再查；若一直重新啟動，請看日誌。

## 7. 驗證真的可以查資料

安裝完成要確認：HTTP 有回應、工具已載入、MySQL 查詢成功。

### 7.1 健康檢查

```powershell
Invoke-RestMethod -Uri "http://localhost:18080/healthz"
```

預期顯示 `OK`。這只代表 HTTP 服務有回應，不代表 SQL 查詢一定成功。如果改了對外埠，以下所有網址也要修改。

### 7.2 瀏覽器查詢

1. 開啟 `http://localhost:18080`。
2. 找到 SQL 執行工具，名稱可能帶來源後綴，例如 `execute_sql_company_mysql`。
3. 在 SQL 欄位輸入並執行：

```sql
SELECT 1 AS ok, DATABASE() AS database_name;
```

應看到 `ok` 是 `1`，`database_name` 是設定的資料庫。這個查詢不會新增或修改資料。

### 7.3 PowerShell 測試 MCP（進階，可略過）

7.1 與 7.2 都成功就代表安裝完成，這一節只在需要確認 MCP 協定本身時才做，之後接 ChatGPT 也會驗證到同樣的路徑。

逐段執行，先初始化，再列工具，最後呼叫 SQL 工具。此版本支援下列舊版協定的無狀態 HTTP 請求：

```powershell
$mcpUrl = "http://localhost:18080/mcp"
$mcpHeaders = @{ Accept = "application/json, text/event-stream" }

$initBody = @{
    jsonrpc = "2.0"
    id = 1
    method = "initialize"
    params = @{
        protocolVersion = "2025-03-26"
        capabilities = @{}
        clientInfo = @{ name = "installation-check"; version = "1.0" }
    }
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri $mcpUrl -Method Post -Headers $mcpHeaders -ContentType "application/json" -Body $initBody

$listBody = @{
    jsonrpc = "2.0"
    id = 2
    method = "tools/list"
    params = @{}
} | ConvertTo-Json -Depth 10

$listReply = Invoke-RestMethod -Uri $mcpUrl -Method Post -Headers $mcpHeaders -ContentType "application/json" -Body $listBody
$listReply | ConvertTo-Json -Depth 20
```

找到回應中 SQL 工具的 `name`，以實際回應為準。接著執行：

```powershell
# 如果 tools/list 回傳不同名稱，請修改這一行
$sqlToolName = "execute_sql_company_mysql"

$callBody = @{
    jsonrpc = "2.0"
    id = 3
    method = "tools/call"
    params = @{
        name = $sqlToolName
        arguments = @{ sql = "SELECT 1 AS ok, DATABASE() AS database_name;" }
    }
} | ConvertTo-Json -Depth 10

$queryReply = Invoke-RestMethod -Uri $mcpUrl -Method Post -Headers $mcpHeaders -ContentType "application/json" -Body $callBody
$queryReply | ConvertTo-Json -Depth 20
```

成功回應包含查詢資料，`ok` 為 `1`。HTTP 成功不等於 SQL 成功；若回應有 `error` 或 `isError: true`，請依訊息排查。

若回應以 `data:` 開頭，表示事件串流文字，可查看其中的 JSON，或使用支援 Streamable HTTP 的 MCP 客戶端完成同樣的驗證。

## 8. 連接 ChatGPT

ChatGPT 是從 OpenAI 的雲端連線，連不到 `http://localhost:18080/mcp`。請用 OpenAI 的私有隧道（tunnel-client）轉接：

1. 確認第 7 節的 `/healthz` 回傳 `OK`。
2. 依 [tunnel-client 安裝.md](tunnel-client%20安裝.md) 第 9 節「方式 B：HTTP」，讓 tunnel-client 連到 `http://127.0.0.1:18080/mcp`。
3. 在 ChatGPT 新增連接器的步驟見 [tunnel-client 安裝.md](tunnel-client%20安裝.md) 第 8 節。
4. 連線後，先請 ChatGPT 執行 `SELECT 1 AS ok;`，再查詢業務資料。

tunnel-client 必須與這個 Docker 服務在**同一台電腦**，才能用 `127.0.0.1` 連到它。

目前服務只發布到 Windows 的 `127.0.0.1`，區域網路的其他電腦無法直接連入，這是刻意的設計：本教學沒有啟用 DBHub 的 Bearer token 驗證，保護靠「只綁本機＋私有隧道＋唯讀資料庫帳號」。**不要為了方便把埠改成對區域網路或網際網路開放。**

方案選擇（單一共用主機或每人各自啟動）見 [ChatGPT連接說明.md](ChatGPT連接說明.md)。

## 9. 日常操作

修改密碼或 `dbhub.docker.toml` 後，重新啟動，確保設定載入：

```powershell
docker compose -f ./compose-dbhub.yaml restart dbhub
```

修改 `.env` 的 `DBHUB_DOCKER_PORT` 或 Compose 設定後，重新建立容器，瀏覽器與 MCP URL 也要同步修改：

```powershell
docker compose -f ./compose-dbhub.yaml up -d --force-recreate
```

更新原始碼或 Dockerfile 後，重新建置：

```powershell
docker compose -f ./compose-dbhub.yaml up -d --build
```

暫停服務、保留容器：

```powershell
docker compose -f ./compose-dbhub.yaml stop
```

停止並移除本專案 DBHub 容器：

```powershell
docker compose -f ./compose-dbhub.yaml down
```

這份 Compose 沒有 MySQL 服務，因此上述 `down` 不會停止外部 MySQL，也不會刪除它的資料。再次啟動：

```powershell
docker compose -f ./compose-dbhub.yaml up -d
```

Compose 設了 `restart: unless-stopped`，Docker 引擎啟動時通常會恢復未被手動停止的容器；Docker Desktop 本身仍需啟動。

## 10. 常見問題

| 現象 | 原因與處理方式 |
|---|---|
| 找不到 `docker` | 確認 Docker Desktop 已安裝，重新開啟 PowerShell |
| 無法連接 Docker daemon／engine | 開啟 Docker Desktop，等待引擎啟動，確認 Linux containers |
| 找不到 Compose 檔 | 先進入專案資料夾；確認副本包含 `compose-dbhub.yaml` |
| bind mount 來源不存在 | 確認 `.env` 與 `dbhub.docker.toml` 已建立，沒有多出 `.txt` |
| `port is already allocated` | 埠被占用；修改 `DBHUB_DOCKER_PORT`，再用 `up -d --force-recreate` |
| 容器不停重啟 | 看 `logs --tail 100 dbhub`，檢查 TOML 格式與連線設定 |
| `ECONNREFUSED` | MySQL 未啟動、埠錯誤、主機埠未發布，或把主機寫成容器的 `localhost` |
| `ETIMEDOUT` | 主機無法到達、防火牆阻擋或需要 VPN，請確認網路與 MySQL 監聽設定 |
| `Access denied for user` | 確認帳密與 MySQL 允許登入的來源 |
| `Unknown database` | `database` 名稱錯誤或尚未建立；DBHub 不會自動建立它 |
| 密碼變數缺少 | `.env` 與 TOML 的名稱需完全一致，本教學是 `DBHUB_MYSQL_PASSWORD` |
| `READONLY` 不再支援 | 移除 `.env` 的 `READONLY`，改用 TOML 工具的 `readonly = true` |
| 網頁可開但 SQL 失敗 | HTTP 可用不代表資料庫可用，依 SQL 錯誤檢查連線與權限 |
| 瀏覽器開 `/mcp` 不是網頁 | 這是協定接口，請用第 7 節的 POST 或 MCP 客戶端測試 |
| HTTP `401` | 有啟用 token 驗證，客戶端需帶正確的 `Authorization: Bearer ...`；手動測試也需調整 |
| HTTP `403` 提到 Host／Origin | 檢查額外主機名稱或代理的允許設定；Host 名稱檢查不是登入驗證 |
| MySQL 5.7 SQL 語法錯誤 | 5.7 不支援 CTE `WITH`，改用子查詢，也不要使用 `utf8mb4_0900_ai_ci` |
| 建置下載失敗 | 確認網路、Docker Desktop 代理與公司憑證設定後重新建置 |

分享錯誤前，遮住密碼、token、完整連線字串與敏感查詢結果。`.gitignore` 與 `.dockerignore` 不會過濾你手動寄出的 ZIP 內容。

## 11. 交付與驗收清單

提供者交付前：

- [ ] 提供完整專案，包含 Docker 啟動檔、建置檔、忽略規則與本文件。
- [ ] 排除自己的密碼設定、日誌與 Git 歷史中的敏感資料。
- [ ] 告知接收者向誰取得 MySQL 主機、埠、資料庫、帳號與密碼。

接收者安裝後：

- [ ] Docker 引擎已啟動，Compose 可執行。
- [ ] 已建立自己的 `.env` 與 `dbhub.docker.toml`。
- [ ] 容器持續執行，狀態為 `healthy`。
- [ ] `/healthz` 回傳 `OK`，網頁可開啟。
- [ ] MCP 工具清單可取得。
- [ ] SQL 測試成功，回傳正確的資料庫名稱。
- [ ] ChatGPT 經 tunnel-client 連線成功，使用設定的唯讀工具。

文件依據：`compose-dbhub.yaml`、`Dockerfile.dbhub`、`src/config/env.ts`、`src/server.ts` 與 `src/tools/execute-sql.ts`。其他安裝方式可查閱 [DBHub 上游專案](https://github.com/bytebase/dbhub)。本文件已核對本專案設定與原始碼；接收者仍需在自己的電腦完成第 7 節的實際驗證。
