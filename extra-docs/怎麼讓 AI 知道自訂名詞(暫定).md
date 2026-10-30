以下假設你要讓 agent 透過 `execute_sql` 或 custom tool 查詢，設計重點是：**查得到、查得準、回傳夠短**。

**核心設計：術語與別名分開**

同一個概念常有多種寫法（簡稱、舊名、不同語言、錯別字），所以不要把別名塞進同一欄，拆成兩張表：

```sql
CREATE TABLE glossary_term (
  id          INTEGER PRIMARY KEY,
  canonical   TEXT NOT NULL UNIQUE,   -- 標準名稱
  term_type   TEXT NOT NULL,          -- 'entity' | 'column' | 'metric' | 'status' ...
  definition  TEXT NOT NULL,          -- 一到兩句，說明是什麼
  db_ref      TEXT,                   -- 對應位置，如 'orders.sku_cd'
  notes       TEXT,                   -- 易混淆處、例外、單位
  status      TEXT DEFAULT 'active',  -- 'active' | 'deprecated'
  updated_at  TEXT
);

CREATE TABLE glossary_alias (
  alias    TEXT NOT NULL,
  term_id  INTEGER NOT NULL REFERENCES glossary_term(id),
  lang     TEXT,                      -- 'zh-TW' | 'en' | 'ja' ...
  PRIMARY KEY (alias, term_id)
);
CREATE INDEX idx_alias ON glossary_alias(alias);
```

**欄位設計的理由**

- **`canonical` 加 `alias`**：agent 查任何一種寫法，都能回到同一個標準條目。
- **`db_ref`**：這是最有價值的欄位。`search_objects` 只告訴 agent 欄位存在，這個欄位告訴它「業務詞對應哪個 table.column」，agent 才能直接寫對 SQL。
- **`term_type`**：讓 agent 知道這是欄位、指標還是狀態值，不會把「GMV」當成欄位名去查。
- **`notes`**：放易錯資訊，例如「含稅」「單位是分不是元」「2024 年前的資料不含此欄」。
- **`status` 加 deprecated**：舊名稱保留但標註，agent 看到才知道要改用新名稱，而不是查不到就當作不存在。
- **`definition` 保持短**：每次查詢結果都會進 context，寫成長段落會浪費 token。

**查詢方式**

做成 custom tool，輸入一個詞，回傳最少必要欄位：

```sql
SELECT t.canonical, t.term_type, t.definition, t.db_ref, t.notes, t.status
FROM glossary_alias a
JOIN glossary_term t ON t.id = a.term_id
WHERE a.alias = :term   -- 先用精確比對
LIMIT 5;
```

精確比對沒結果時，再提供模糊比對（`LIKE` 或資料庫的全文檢索 / trigram）當第二個工具或第二步，並限制筆數。

**幾個容易踩的坑**

1. **正規化**：寫入和查詢時統一處理大小寫、全形半形、前後空白、繁簡體。不然「SKU」和「sku」會查不到。
2. **一詞多義**：同一個 alias 可以對應多個 term（例如「單價」在訂單和採購是不同東西）。可以加 `scope` 欄位（所屬領域或 table），回傳多筆時讓 agent 自己根據上下文選，或回問使用者。
3. **查不到的訊號**：工具回傳空結果時，在 tool description 裡規定 agent 要說「術語表沒有這個詞」並詢問，而不是自己猜。
4. **別讓 agent 寫入**：術語表建議用唯讀帳號存取，維護走另外的流程，避免 agent 隨手把猜測寫進去，變成之後的「權威」資料。
5. **維護成本**：術語表過期比沒有更糟。可以記錄 `updated_at`，並定期用 `search_objects` 的結果比對 `db_ref` 是否還存在。

**是否需要更複雜的結構**

術語少於幾百筆，上面兩張表就夠。如果有層級關係（例如「訂單狀態」底下有一組狀態值），再加 `parent_id`；如果需要語意相似搜尋，才考慮加向量欄位，但多數情況下精確別名加模糊比對已經夠用。
