# 在 ChatGPT 使用 DBHub：方案與待決定事項

本文件幫你**決定用哪種方式**讓同事在 ChatGPT 使用 DBHub。實際操作步驟請見 [tunnel-client 安裝.md](tunnel-client%20安裝.md)，DBHub 常駐請見 [Docker使用說明.md](Docker使用說明.md)。

> 方案與功能名稱變動頻繁。本文整理自 2026 年 10 月的官方與實測資料，**正式採用前請以 OpenAI 官方說明為準**：<https://help.openai.com/zh-hant/articles/12584461-connecting-custom-mcp-servers-in-chatgpt>。

## 一、先看結論

| 項目 | 狀況 |
|---|---|
| 連線方式 | 用 **tunnel-client**（OpenAI 的私有通道），DBHub 不必公開到網際網路 |
| 免費版、Plus | **已實測**：不需開發者模式，也不需綁卡或儲值，「Plugins → 加號 → Add custom MCP server → Connection 選 Tunnel → 選隧道」即可，並已實際讀到資料庫資料。連接畫面會出現「自訂 MCP 伺服器會帶來風險。」的提示，屬正常 |
| 方案 B（每人各一條隧道） | 已實測可行 |
| 方案 A（共用一條隧道） | **未實測**，見第三節 |
| 需要委託方決定的事 | 見第四節 |

## 二、為什麼用隧道

ChatGPT 的自訂 MCP 連接器是從 **OpenAI 的雲端**去連線，不是從你的電腦。若不用隧道，DBHub 必須有公開可連線的 HTTPS 網址與身分驗證，等於把資料庫的查詢入口放到網際網路上，風險高。DBHub 本身只支援共用密鑰的 Bearer Token，沒有 OAuth。

隧道讓 ChatGPT 經 OpenAI 的私有通道連到你的電腦，**不需要開放任何入站埠**，所以本專案只採用這種方式。

## 三、兩種方案

隧道與權限屬於 **OpenAI Platform 組織**。官方說明：個人帳號使用的是「屬於該帳號的個人 Platform 組織」，隧道必須關聯到該組織或工作區，ChatGPT 才選得到。

|  | 方案 A：同一個 Platform 組織、同一個 Tunnel ID | 方案 B：每人各自一條 Tunnel |
|---|---|---|
| 狀態 | **未實測** | 已實測（免費版、Plus） |
| 做法 | 把同事的個人帳號拉進同一個 Platform 組織，大家選同一個 Tunnel ID | 每人用自己的 Platform 組織建立自己的 Tunnel 與 Runtime API Key，各自執行 tunnel-client |
| DBHub 放哪 | 一台常駐主機，Docker 版 | 每人電腦各自啟動（npx，由 tunnel-client 啟動），共用的只有 MySQL |
| tunnel-client | 只跑一個，與 DBHub 同一台電腦 | 每人一個 |
| 接法 | [tunnel-client 安裝.md](tunnel-client%20安裝.md) 第 9 節「方式 B：HTTP」 | 同上「方式 A：stdio」 |
| 同事要做的事 | 在自己的 ChatGPT 加入連接器、選同一個 Tunnel | 需要有人代為一次性設定（建立 OpenAI 帳號與隧道、Key、安裝 Node.js 與 tunnel-client、放設定檔） |
| 掛掉的影響 | 主機或 tunnel-client 掛掉，全員斷線 | 只影響自己 |
| 密碼放哪 | 只在主機上 | 每位同事的電腦都有資料庫密碼 |
| 管理成本 | 低（集中管理） | 高（每台電腦各一份設定） |

### 方案 A 為什麼還不確定

官方文件沒有說明「被邀請進組織的個人帳號，能否在自己的 ChatGPT 看到該組織的 Tunnel」，也沒有說明免費版或 Plus 的資格。方案 A 的預期行為是：被邀請的帳號在 ChatGPT 的 Tunnel 清單選得到該 Tunnel。這個預期**必須實測才能採用**。

**驗證方法**：

1. 用組織擁有者建立 Tunnel 與 Runtime API Key，在一台電腦跑 tunnel-client 與示範（[tunnel-client 安裝.md](tunnel-client%20安裝.md) 第 7 節）。
2. 在 Platform 的組織設定把第二個個人帳號加為成員，並授予 Tunnels 的 **Read＋Use**。
3. 用第二個帳號登入 ChatGPT，進入「Plugins → 加號 → Add custom MCP server → Connection 選 Tunnel」。
4. 看得到該 Tunnel、能選用，且呼叫示範工具成功，才算通過。
5. 另外確認：該成員是否因此能看到組織的其他資源（成員權限過大是風險）。

結果請更新到本節，並把上表的「未實測」改成實測結果。

## 四、待決定的事

下列四項各附建議預設值。若沒有特別指示，先依預設值準備。

| 編號 | 要決定什麼 | 建議預設值 | 理由 |
|---|---|---|---|
| 1 | 採用方案 A 還是方案 B | **方案 B** | 已實測；方案 A 通過第三節的驗證後可再改 |
| 2 | DBHub 放哪裡 | 方案 B：每人電腦各自啟動（npx）；方案 A：一台常駐主機（Docker） | 由方案決定。tunnel-client 與 DBHub 需在同一台電腦，不要跨區域網路連線 |
| 3 | 非技術人員的一次性設定由誰做 | 技術人員到場或遠端代為完成一次 | 設定涉及 API Key 與環境變數，不適合要求非技術人員自己處理 |
| 4 | 資料庫帳號 | 全員共用同一個唯讀 MySQL 帳號 | 規模小、管理簡單；代價是一人電腦被入侵就要換密碼 |

選了方案 B 與共用帳號時，需要接受：

- 密碼存在每位同事電腦的 `.env`。離職或電腦遺失時，由資料庫管理者更換該帳號密碼，並重新發放給其他人。
- 所有人用同一個資料庫身分，**無法分辨誰查了什麼，也無法分權限**。若要分權限，需拆成多個資料庫帳號與多個設定。

## 五、重要注意事項

- **隧道只保護網路路徑，不限制 SQL。** 一定要使用唯讀資料庫帳號，並在 TOML 設定 `readonly = true`、`max_rows`。能使用該連接器的人都能查資料，請只授權需要的人。
- **要保持執行**：關閉 tunnel-client、電腦關機或休眠後，ChatGPT 就無法使用 DBHub。Ubuntu 可用 systemd 開機自動啟動，Windows 需自行處理，見 [tunnel-client 安裝.md](tunnel-client%20安裝.md) 第 10、11 節。
- **單一實例**：官方說明，使用 stdio 時，同一個 Tunnel ID 同時只能有一個 tunnel-client 在執行。
- **不要設定 `DBHUB_AUTH_TOKEN`**：tunnel-client 的公開說明沒有轉送 `Authorization` 標頭的選項，設定後請求可能被擋成 401。這個架構靠「DBHub 只綁本機＋私有隧道＋唯讀帳號」保護。
- **Docker 版連資料庫**：Compose 掛載的是 `dbhub.docker.toml`，其中資料庫主機要用 `host.docker.internal`，不是 `127.0.0.1`。
- **stdio 版讀密碼**：`dbhub.toml` 中的 `${DBHUB_MYSQL_PASSWORD}` 從執行目錄的 `.env` 讀取，所以 tunnel-client 要在放有 `.env` 的專案資料夾執行。
- **Plus／Pro 的限制**：第三方資料提到 Plus、Pro 的自訂連接器可能只能唯讀。DBHub 本來就設為唯讀，通常不受影響。

## 六、備案：只用網頁介面（Workbench）

只想看資料表或跑查詢、不需要 AI 對話時，可用 DBHub 內建的網頁介面（Docker 版預設 `http://localhost:18080`）。這是最安全的方式，但沒有 AI 對話。DBHub 沒有內建登入，Compose 預設只綁 `127.0.0.1`；不要為了讓別台電腦連入就改成對區域網路開放。

## 七、常見問題

**Q：ChatGPT 顯示找不到或無法連線？**
先確認 tunnel-client 仍在執行、狀態頁顯示就緒（見 [tunnel-client 安裝.md](tunnel-client%20安裝.md) 第 7、12 節）。

**Q：ChatGPT 的 Tunnel 清單是空的？**
該 Tunnel 沒有關聯到這個 ChatGPT 帳號所用的組織，或該帳號沒有 Tunnels 的 Use 權限。方案 A 尤其要檢查，見第三節。

**Q：免費版能用嗎？**
已實測可以，詳見第一節。OpenAI 的規則可能調整，若突然不能用，請先查官方說明。

**Q：Windows 指令要寫 `tunnel-client` 還是 `./tunnel-client.exe`？**
在 PowerShell 的程式所在資料夾，寫 `./tunnel-client.exe`。

---

本文件基於 2026 年 10 月的資料與實測整理，OpenAI 的功能與方案可能隨時調整。
