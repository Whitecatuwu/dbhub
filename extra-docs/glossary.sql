-- ============================================================
-- 自動控制與機電材料經銷商：商品詞彙表（MySQL 5.7 / utf8）
--
-- 對接的商品表：products(i_products_id, vc_products_no, vc_subject_TW0, vc_shortName_TW0, i_use)
-- products 沒有品牌 / 品類欄位，所以術語表有兩種用法：
--   1. 同義詞展開：使用者輸入 → 找到標準術語 → 取出它所有別名 → 去比對品名 / 簡稱
--   2. 型號前綴：vc_products_no 的前綴 → 反推品牌 / 品類 / 系列
--
-- 執行方式：用 mysql 客戶端整份匯入（mysql -u... -p dbname < 本檔）。
--           建議 agent 只給 SELECT 權限，維護術語表走另外的帳號。
--
-- 正規化規則（寫入與查詢必須一致）：
--   alias_norm = LOWER + 去掉空白 / - / _ / .
--   全形半形(NFKC)與繁簡轉換請在應用層先處理。
-- ============================================================

SET NAMES utf8;

DROP VIEW  IF EXISTS v_glossary_expand;
DROP VIEW  IF EXISTS v_glossary_lookup;
DROP TABLE IF EXISTS model_rule;
DROP TABLE IF EXISTS glossary_alias;
DROP TABLE IF EXISTS glossary_term;

-- ---------- 1. 術語主表 ----------
CREATE TABLE glossary_term (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  canonical   VARCHAR(100) NOT NULL,                  -- 標準名稱
  term_type   ENUM('brand','category','spec','unit') NOT NULL,
  scope       VARCHAR(200) DEFAULT NULL,              -- 適用範圍（哪些品類才適用）
  definition  VARCHAR(500) NOT NULL,                  -- 一兩句，保持短
  notes       VARCHAR(500) DEFAULT NULL,              -- 易混淆處、例外
  status      ENUM('active','deprecated') NOT NULL DEFAULT 'active',
  replaced_by INT UNSIGNED DEFAULT NULL,              -- deprecated 時指向新詞
  updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_canonical (canonical),
  CONSTRAINT fk_term_replaced FOREIGN KEY (replaced_by) REFERENCES glossary_term (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- ---------- 2. 別名表 ----------
-- kind = generic：一詞多義或籠統說法，查到時要依上下文挑，不能直接當唯一答案
-- search_expand：這個別名是否拿去比對商品品名（太短或太籠統的別名會誤中，設為 0）
CREATE TABLE glossary_alias (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  term_id       INT UNSIGNED NOT NULL,
  alias         VARCHAR(100) NOT NULL,
  alias_norm    VARCHAR(100) CHARACTER SET utf8 COLLATE utf8_bin
                GENERATED ALWAYS AS (
                  LOWER(REPLACE(REPLACE(REPLACE(REPLACE(alias, ' ', ''), '-', ''), '_', ''), '.', ''))
                ) STORED,
  lang          ENUM('zh-TW','zh-CN','en') NOT NULL,
  kind          ENUM('official','colloquial','abbr','en','zh_cn','legacy','typo','generic') NOT NULL,
  search_expand TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  UNIQUE KEY uk_norm_term (alias_norm, term_id),     -- 同時當 alias_norm 的查詢索引
  KEY idx_term (term_id),
  CONSTRAINT fk_alias_term FOREIGN KEY (term_id) REFERENCES glossary_term (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- ---------- 3. 型號規則表（用 vc_products_no 前綴反推品牌 / 品類 / 系列）----------
CREATE TABLE model_rule (
  id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  brand_id     INT UNSIGNED NOT NULL,
  category_id  INT UNSIGNED NOT NULL,
  pattern      VARCHAR(100) NOT NULL,                 -- LIKE 語法，如 'FR-D7%'、'VFD%EL%'
  pattern_norm VARCHAR(100) CHARACTER SET utf8 COLLATE utf8_bin
               GENERATED ALWAYS AS (
                 LOWER(REPLACE(REPLACE(REPLACE(REPLACE(pattern, ' ', ''), '-', ''), '_', ''), '.', ''))
               ) STORED,
  series       VARCHAR(100) NOT NULL,
  decode_note  VARCHAR(500) NOT NULL,                 -- 型號各段意義
  successor    VARCHAR(100) DEFAULT NULL,             -- 新舊替代（以原廠公告為準）
  PRIMARY KEY (id),
  KEY idx_pattern_norm (pattern_norm),
  CONSTRAINT fk_rule_brand    FOREIGN KEY (brand_id)    REFERENCES glossary_term (id),
  CONSTRAINT fk_rule_category FOREIGN KEY (category_id) REFERENCES glossary_term (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- ---------- 4. View ----------
-- 術語查詢用
CREATE VIEW v_glossary_lookup AS
SELECT a.alias_norm, a.alias, a.kind AS alias_kind,
       t.id AS term_id, t.canonical, t.term_type, t.scope, t.definition, t.notes,
       t.status, r.canonical AS replaced_by
FROM glossary_alias a
JOIN glossary_term t ON t.id = a.term_id
LEFT JOIN glossary_term r ON r.id = t.replaced_by;

-- 同義詞展開用：某個術語底下所有可拿去比對品名的字串
CREATE VIEW v_glossary_expand AS
SELECT t.id AS term_id, t.canonical AS search_text
FROM glossary_term t
UNION
SELECT a.term_id, a.alias
FROM glossary_alias a
WHERE a.search_expand = 1;

-- ============================================================
-- 範例資料：術語
-- ============================================================


-- ---------- 品牌 ----------
INSERT INTO glossary_term (canonical, term_type, scope, definition, notes) VALUES
('Mitsubishi Electric','brand',NULL,'日本三菱電機：PLC、變頻器、伺服、斷路器、接觸器','搜尋「三菱」預設指三菱電機，不是三菱重工或三菱商事'),
('Omron','brand',NULL,'日本歐姆龍：繼電器、感測器、PLC、溫控器、編碼器',NULL),
('Panasonic','brand',NULL,'日本松下（台灣稱國際牌），含原松下電工(NAiS)的繼電器、開關、PLC、感測器','NAiS 為舊品牌，新舊型號可能並存於庫存'),
('Delta Electronics','brand',NULL,'台達電子：變頻器、PLC、HMI、伺服、電源',NULL),
('Fuji Electric','brand',NULL,'日本富士電機：斷路器、接觸器、變頻器',NULL),
('Schneider Electric','brand',NULL,'施耐德電機：接觸器、斷路器、按鈕開關、電源','Telemecanique 為其旗下舊品牌，LC1D 等型號仍沿用'),
('Siemens','brand',NULL,'德國西門子：PLC、接觸器、馬達保護斷路器',NULL),
('Keyence','brand',NULL,'日本基恩斯：感測器、視覺、量測',NULL),
('Autonics','brand',NULL,'韓國奧托尼克斯：感測器、溫控器、編碼器、計時器',NULL),
('Mean Well','brand',NULL,'台灣明緯：開關電源供應器',NULL),
('TECO','brand',NULL,'台灣東元：馬達、變頻器、電磁開關',NULL),
('Shihlin Electric','brand',NULL,'台灣士林電機：無熔絲開關、電磁開關、變頻器',NULL),
('CHINT','brand',NULL,'中國正泰：低壓電器、斷路器、接觸器',NULL),
('AirTAC','brand',NULL,'台灣亞德客：氣壓缸、電磁閥、氣動元件',NULL),
('Yaskawa','brand',NULL,'日本安川電機：伺服、變頻器、機器人',NULL),
('LS Electric','brand',NULL,'韓國 LS 電氣（原 LS 產電）：斷路器、接觸器、變頻器、PLC','「LS」也可能是極限開關(Limit Switch)的縮寫，需看上下文'),
('LSIS','brand',NULL,'LS 產電舊稱，已改名 LS Electric','舊型錄與舊料號可能仍標示 LSIS');

-- ---------- 品類 ----------
INSERT INTO glossary_term (canonical, term_type, scope, definition, notes) VALUES
('變頻器','category',NULL,'以改變頻率控制交流馬達轉速的驅動裝置','現場說的「調速器」可能指變頻器，也可能指單相/直流馬達速度控制器，需確認'),
('可程式控制器','category',NULL,'PLC，工業自動化的邏輯控制主機與擴充模組',NULL),
('伺服馬達','category',NULL,'搭配伺服驅動器做精密位置/速度/扭矩控制的馬達','伺服馬達與驅動器必須同品牌同系列搭配'),
('伺服驅動器','category',NULL,'驅動伺服馬達的控制器，三菱稱伺服放大器',NULL),
('人機介面','category',NULL,'HMI，觸控螢幕操作面板',NULL),
('溫度控制器','category',NULL,'溫控器，依感測器訊號做 PID 或 ON/OFF 溫度控制',NULL),
('電磁接觸器','category',NULL,'以線圈控制主迴路通斷的接觸器，MC','線圈電壓(AC110V/AC220V/DC24V)要另外確認'),
('熱過載繼電器','category',NULL,'馬達過載保護元件，台灣俗稱積熱電驛 THR','要與接觸器同廠牌同系列搭配，並確認電流設定範圍'),
('電磁開關','category',NULL,'接觸器加熱過載繼電器的組合，MS','業界說「電磁開關」有時指整組、有時指單顆接觸器，報價前先確認'),
('無熔絲斷路器','category',NULL,'塑殼斷路器，台灣俗稱 NFB','NFB 嚴格說是日系用語，等同 MCCB；框架容量(AF)與跳脫電流(AT)是兩個不同數字'),
('漏電斷路器','category',NULL,'具漏電偵測的斷路器，ELB/ELCB',NULL),
('馬達保護斷路器','category',NULL,'專為馬達設計的斷路器，兼具過載與短路保護，MPCB',NULL),
('繼電器','category',NULL,'小型控制用繼電器，台灣常稱電驛','底座通常另購，詢價時要確認'),
('固態繼電器','category',NULL,'無機械接點的半導體繼電器，SSR','需區分 AC 負載或 DC 負載，並注意散熱'),
('計時器','category',NULL,'延時 / 限時繼電器，台灣稱限時電驛',NULL),
('變壓器','category',NULL,'電壓轉換用變壓器，TR','「TR」也可能是計時電驛，需看上下文'),
('近接開關','category',NULL,'非接觸式金屬檢測感測器（電感式為主）','需確認 NPN/PNP 與常開/常閉'),
('光電開關','category',NULL,'以光線檢測物體的感測器，對照式 / 反射式 / 擴散反射式',NULL),
('極限開關','category',NULL,'機械式行程檢出開關',NULL),
('按鈕開關','category',NULL,'操作用按鈕，常見開孔 22mm / 16mm',NULL),
('急停開關','category',NULL,'緊急停止按鈕，需符合安全規範',NULL),
('指示燈','category',NULL,'盤面信號指示燈',NULL),
('電源供應器','category',NULL,'AC 轉 DC 的開關電源，控制盤常用 24V','需確認輸出電壓、功率(W)與安裝方式(DIN軌/鎖附式)'),
('端子台','category',NULL,'配線端子，含 DIN 軌端子與固定式端子排',NULL),
('電磁閥','category',NULL,'電控氣動或液壓閥','需確認位置數/通口數、線圈電壓與接管口徑'),
('氣壓缸','category',NULL,'氣動缸，缸徑與行程是主要規格','「汽缸」是引擎用語，氣動場合應為「氣缸」，但常被誤寫'),
('編碼器','category',NULL,'旋轉編碼器，回授位置與轉速','需確認解析度(P/R)、軸徑、輸出型式'),
('減速機','category',NULL,'齒輪減速機',NULL),
('馬達','category',NULL,'電動機，含感應馬達與直流馬達','容量常以「馬力(HP)」或「匹」表示，需換算 kW');

-- ---------- 規格 ----------
INSERT INTO glossary_term (canonical, term_type, scope, definition, notes) VALUES
('常開接點','spec','繼電器,接觸器,按鈕,感測器','未動作時斷開、動作時導通，NO','a 接點即常開'),
('常閉接點','spec','繼電器,接觸器,按鈕,感測器','未動作時導通、動作時斷開，NC','b 接點即常閉'),
('切換接點','spec','繼電器,按鈕,極限開關','一組同時含 NO 與 NC 並共用共接點，SPDT / Form C',NULL),
('NPN輸出','spec','近接開關,光電開關,編碼器','DC 三線式 NPN 輸出（汲入型 sink）','要與 PLC 輸入型式(sink/source)匹配，買錯會無法偵測'),
('PNP輸出','spec','近接開關,光電開關,編碼器','DC 三線式 PNP 輸出（源出型 source）','亞洲 PLC 常搭 NPN，歐系常搭 PNP，但不是絕對'),
('三相','spec','變頻器,馬達,斷路器','三相電源',NULL),
('單相','spec','變頻器,馬達,斷路器','單相電源',NULL),
('200V級','spec','變頻器,馬達,斷路器','電壓等級 200~240V（台灣習稱 220V）','僅用於主迴路電壓等級；線圈電壓是另一個屬性'),
('400V級','spec','變頻器,馬達,斷路器','電壓等級 380~480V（台灣工廠多為 380V）',NULL),
('DC24V','spec','繼電器,接觸器,電磁閥,電源供應器','直流 24V，控制迴路最常見電壓','可能是線圈電壓，也可能是電源輸出電壓，看品類'),
('AC110V','spec','繼電器,接觸器,電磁閥','交流 110V 線圈電壓（日系 AC100V 規格常通用）','AC100V 與 AC110V 在型錄上是不同線圈代號，下單前要核對'),
('AC220V','spec','繼電器,接觸器,電磁閥','交流 220V 線圈電壓','單說「220V」時可能是線圈電壓，也可能是主迴路電壓等級'),
('極數','spec','斷路器,接觸器,開關,馬達','1P/2P/3P/4P 的極數','馬達的 2P/4P/6P 是磁極數，與斷路器的極數意義不同，要看品類'),
('IP防護等級','spec',NULL,'防塵防水等級，如 IP20、IP65、IP67','IP65 防塵且防噴水；IP67 可短時間浸水'),
('DIN軌','spec','端子台,電源供應器,斷路器,繼電器底座','35mm 標準導軌安裝方式','「導軌」也可能指線性滑軌，需看品類');

-- ---------- 單位 ----------
INSERT INTO glossary_term (canonical, term_type, scope, definition, notes) VALUES
('馬力','unit',NULL,'HP，馬達容量單位；1HP ≈ 0.746kW','常見對照：1HP≈0.75kW、2HP≈1.5kW、3HP≈2.2kW、5HP≈3.7kW、7.5HP≈5.5kW、10HP≈7.5kW'),
('千瓦','unit',NULL,'kW，功率單位','台灣舊式寫法為「瓩」');

UPDATE glossary_term
SET status = 'deprecated',
    replaced_by = (SELECT id FROM (SELECT id FROM glossary_term WHERE canonical = 'LS Electric') x)
WHERE canonical = 'LSIS';


-- ============================================================
-- 範例資料：別名
-- ============================================================
CREATE TEMPORARY TABLE alias_seed (
  canonical VARCHAR(100), alias VARCHAR(100), lang VARCHAR(10), kind VARCHAR(20)
) DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;


INSERT INTO alias_seed VALUES
-- 品牌
('Mitsubishi Electric','三菱','zh-TW','colloquial'),
('Mitsubishi Electric','三菱電機','zh-TW','official'),
('Mitsubishi Electric','三菱电机','zh-CN','zh_cn'),
('Mitsubishi Electric','Mitsubishi','en','en'),
('Mitsubishi Electric','MELCO','en','abbr'),
('Omron','歐姆龍','zh-TW','official'),
('Omron','欧姆龙','zh-CN','zh_cn'),
('Omron','OMRON','en','en'),
('Panasonic','國際牌','zh-TW','colloquial'),
('Panasonic','松下','zh-TW','colloquial'),
('Panasonic','松下電工','zh-TW','legacy'),
('Panasonic','Panasonic','en','en'),
('Panasonic','PANA','en','abbr'),
('Panasonic','NAiS','en','legacy'),
('Delta Electronics','台達','zh-TW','colloquial'),
('Delta Electronics','台達電','zh-TW','colloquial'),
('Delta Electronics','台达','zh-CN','zh_cn'),
('Delta Electronics','Delta','en','en'),
('Fuji Electric','富士','zh-TW','colloquial'),
('Fuji Electric','富士電機','zh-TW','official'),
('Fuji Electric','富士电机','zh-CN','zh_cn'),
('Fuji Electric','Fuji','en','en'),
('Schneider Electric','施耐德','zh-TW','official'),
('Schneider Electric','施奈德','zh-TW','colloquial'),
('Schneider Electric','Schneider','en','en'),
('Schneider Electric','Telemecanique','en','legacy'),
('Siemens','西門子','zh-TW','official'),
('Siemens','西门子','zh-CN','zh_cn'),
('Siemens','Siemens','en','en'),
('Keyence','基恩斯','zh-TW','official'),
('Keyence','基恩士','zh-TW','colloquial'),
('Keyence','Keyence','en','en'),
('Autonics','奧托尼克斯','zh-TW','official'),
('Autonics','奥托尼克斯','zh-CN','zh_cn'),
('Autonics','Autonics','en','en'),
('Mean Well','明緯','zh-TW','official'),
('Mean Well','明纬','zh-CN','zh_cn'),
('Mean Well','Mean Well','en','en'),
('TECO','東元','zh-TW','official'),
('TECO','东元','zh-CN','zh_cn'),
('TECO','TECO','en','en'),
('Shihlin Electric','士林電機','zh-TW','official'),
('Shihlin Electric','士林','zh-TW','colloquial'),
('Shihlin Electric','Shihlin','en','en'),
('CHINT','正泰','zh-TW','official'),
('CHINT','CHINT','en','en'),
('AirTAC','亞德客','zh-TW','official'),
('AirTAC','亚德客','zh-CN','zh_cn'),
('AirTAC','AirTAC','en','en'),
('Yaskawa','安川','zh-TW','colloquial'),
('Yaskawa','安川電機','zh-TW','official'),
('Yaskawa','Yaskawa','en','en'),
('LS Electric','LS Electric','en','en'),
('LS Electric','LS電氣','zh-TW','official'),
('LS Electric','LS电气','zh-CN','zh_cn'),
('LS Electric','LS','en','generic'),
('LSIS','LSIS','en','legacy'),
('LSIS','LS產電','zh-TW','legacy'),

-- 變頻 / 控制 / 驅動
('變頻器','VFD','en','abbr'),
('變頻器','Inverter','en','en'),
('變頻器','AC Drive','en','en'),
('變頻器','變頻驅動器','zh-TW','official'),
('變頻器','变频器','zh-CN','zh_cn'),
('變頻器','調速器','zh-TW','generic'),
('可程式控制器','PLC','en','abbr'),
('可程式控制器','可編程控制器','zh-CN','zh_cn'),
('可程式控制器','可编程控制器','zh-CN','zh_cn'),
('可程式控制器','程式控制器','zh-TW','colloquial'),
('伺服馬達','Servo Motor','en','en'),
('伺服馬達','伺服电机','zh-CN','zh_cn'),
('伺服馬達','伺服','zh-TW','generic'),
('伺服驅動器','Servo Drive','en','en'),
('伺服驅動器','Servo Amplifier','en','en'),
('伺服驅動器','伺服放大器','zh-TW','colloquial'),
('伺服驅動器','伺服驱动器','zh-CN','zh_cn'),
('伺服驅動器','伺服','zh-TW','generic'),
('人機介面','HMI','en','abbr'),
('人機介面','觸控螢幕','zh-TW','colloquial'),
('人機介面','觸控面板','zh-TW','colloquial'),
('人機介面','觸摸屏','zh-CN','zh_cn'),
('溫度控制器','溫控器','zh-TW','colloquial'),
('溫度控制器','Temperature Controller','en','en'),
('溫度控制器','温控器','zh-CN','zh_cn'),
('溫度控制器','PID控制器','zh-TW','colloquial'),

-- 開關 / 保護 / 接觸
('電磁接觸器','MC','en','abbr'),
('電磁接觸器','接觸器','zh-TW','colloquial'),
('電磁接觸器','Magnetic Contactor','en','en'),
('電磁接觸器','Contactor','en','en'),
('電磁接觸器','接触器','zh-CN','zh_cn'),
('熱過載繼電器','積熱電驛','zh-TW','colloquial'),
('熱過載繼電器','THR','en','abbr'),
('熱過載繼電器','TH-RY','en','abbr'),
('熱過載繼電器','Thermal Overload Relay','en','en'),
('熱過載繼電器','OLR','en','abbr'),
('熱過載繼電器','過載繼電器','zh-TW','colloquial'),
('熱過載繼電器','热继电器','zh-CN','zh_cn'),
('電磁開關','MS','en','abbr'),
('電磁開關','Magnetic Switch','en','en'),
('電磁開關','Magnetic Starter','en','en'),
('無熔絲斷路器','NFB','en','abbr'),
('無熔絲斷路器','無熔絲開關','zh-TW','colloquial'),
('無熔絲斷路器','MCCB','en','abbr'),
('無熔絲斷路器','Molded Case Circuit Breaker','en','en'),
('無熔絲斷路器','塑殼斷路器','zh-TW','official'),
('無熔絲斷路器','斷路器','zh-TW','generic'),
('無熔絲斷路器','Breaker','en','generic'),
('無熔絲斷路器','断路器','zh-CN','generic'),
('漏電斷路器','ELB','en','abbr'),
('漏電斷路器','ELCB','en','abbr'),
('漏電斷路器','RCCB','en','abbr'),
('漏電斷路器','漏電開關','zh-TW','colloquial'),
('漏電斷路器','漏电断路器','zh-CN','zh_cn'),
('漏電斷路器','斷路器','zh-TW','generic'),
('漏電斷路器','Breaker','en','generic'),
('漏電斷路器','断路器','zh-CN','generic'),
('馬達保護斷路器','MPCB','en','abbr'),
('馬達保護斷路器','MMS','en','abbr'),
('馬達保護斷路器','馬達斷路器','zh-TW','colloquial'),
('馬達保護斷路器','Motor Protection Circuit Breaker','en','en'),
('馬達保護斷路器','斷路器','zh-TW','generic'),
('馬達保護斷路器','Breaker','en','generic'),
('馬達保護斷路器','断路器','zh-CN','generic'),

-- 繼電器 / 計時 / 變壓
('繼電器','電驛','zh-TW','colloquial'),
('繼電器','Relay','en','en'),
('繼電器','RY','en','abbr'),
('繼電器','继电器','zh-CN','zh_cn'),
('固態繼電器','SSR','en','abbr'),
('固態繼電器','Solid State Relay','en','en'),
('固態繼電器','固態電驛','zh-TW','colloquial'),
('固態繼電器','固态继电器','zh-CN','zh_cn'),
('計時器','Timer','en','en'),
('計時器','限時電驛','zh-TW','colloquial'),
('計時器','計時電驛','zh-TW','colloquial'),
('計時器','延时继电器','zh-CN','zh_cn'),
('計時器','TR','en','generic'),
('變壓器','Transformer','en','en'),
('變壓器','变压器','zh-CN','zh_cn'),
('變壓器','TR','en','generic'),

-- 感測 / 操作
('近接開關','接近開關','zh-TW','colloquial'),
('近接開關','接近开关','zh-CN','zh_cn'),
('近接開關','Proximity Sensor','en','en'),
('近接開關','Proximity Switch','en','en'),
('近接開關','感應開關','zh-TW','generic'),
('光電開關','光電感測器','zh-TW','official'),
('光電開關','光電眼','zh-TW','colloquial'),
('光電開關','光电开关','zh-CN','zh_cn'),
('光電開關','Photoelectric Sensor','en','en'),
('光電開關','感應開關','zh-TW','generic'),
('極限開關','Limit Switch','en','en'),
('極限開關','LS','en','generic'),
('極限開關','行程開關','zh-TW','colloquial'),
('極限開關','行程开关','zh-CN','zh_cn'),
('按鈕開關','按鈕','zh-TW','colloquial'),
('按鈕開關','Push Button','en','en'),
('按鈕開關','PB','en','abbr'),
('按鈕開關','押扣','zh-TW','colloquial'),
('按鈕開關','按钮开关','zh-CN','zh_cn'),
('急停開關','E-Stop','en','abbr'),
('急停開關','Emergency Stop','en','en'),
('急停開關','緊急停止開關','zh-TW','official'),
('急停開關','急停按鈕','zh-TW','colloquial'),
('急停開關','急停开关','zh-CN','zh_cn'),
('指示燈','PL','en','abbr'),
('指示燈','Pilot Lamp','en','en'),
('指示燈','信號燈','zh-TW','colloquial'),
('指示燈','指示灯','zh-CN','zh_cn'),

-- 籠統的「開關」：一詞多義
('按鈕開關','開關','zh-TW','generic'),
('極限開關','開關','zh-TW','generic'),
('近接開關','開關','zh-TW','generic'),
('光電開關','開關','zh-TW','generic'),
('無熔絲斷路器','開關','zh-TW','generic'),
('電磁開關','開關','zh-TW','generic'),
('按鈕開關','Switch','en','generic'),
('極限開關','Switch','en','generic'),
('近接開關','Switch','en','generic'),
('光電開關','Switch','en','generic'),
('無熔絲斷路器','Switch','en','generic'),
('電磁開關','Switch','en','generic'),

-- 電源 / 配線 / 氣動 / 機構
('電源供應器','SMPS','en','abbr'),
('電源供應器','Power Supply','en','en'),
('電源供應器','PSU','en','abbr'),
('電源供應器','開關電源','zh-CN','zh_cn'),
('端子台','TB','en','abbr'),
('端子台','Terminal Block','en','en'),
('端子台','端子排','zh-TW','colloquial'),
('端子台','端子座','zh-TW','colloquial'),
('電磁閥','Solenoid Valve','en','en'),
('電磁閥','SOL','en','abbr'),
('電磁閥','电磁阀','zh-CN','zh_cn'),
('氣壓缸','氣缸','zh-TW','colloquial'),
('氣壓缸','汽缸','zh-TW','typo'),
('氣壓缸','气缸','zh-CN','zh_cn'),
('氣壓缸','Air Cylinder','en','en'),
('氣壓缸','Pneumatic Cylinder','en','en'),
('編碼器','Encoder','en','en'),
('編碼器','Rotary Encoder','en','en'),
('編碼器','旋轉編碼器','zh-TW','official'),
('編碼器','编码器','zh-CN','zh_cn'),
('減速機','Gear Reducer','en','en'),
('減速機','Gearbox','en','en'),
('減速機','減速器','zh-TW','colloquial'),
('減速機','减速机','zh-CN','zh_cn'),
('馬達','Motor','en','en'),
('馬達','電動機','zh-TW','official'),
('馬達','电机','zh-CN','zh_cn'),

-- 規格 / 單位
('常開接點','NO','en','abbr'),
('常開接點','a接點','zh-TW','colloquial'),
('常開接點','常開','zh-TW','colloquial'),
('常閉接點','NC','en','abbr'),
('常閉接點','b接點','zh-TW','colloquial'),
('常閉接點','常閉','zh-TW','colloquial'),
('切換接點','c接點','zh-TW','colloquial'),
('切換接點','SPDT','en','abbr'),
('切換接點','Form C','en','en'),
('NPN輸出','NPN','en','abbr'),
('NPN輸出','NPN輸出','zh-TW','official'),
('NPN輸出','DC3線NPN','zh-TW','colloquial'),
('PNP輸出','PNP','en','abbr'),
('PNP輸出','PNP輸出','zh-TW','official'),
('三相','3φ','en','abbr'),
('三相','3相','zh-TW','colloquial'),
('三相','3PH','en','abbr'),
('三相','Three Phase','en','en'),
('單相','1φ','en','abbr'),
('單相','1相','zh-TW','colloquial'),
('單相','1PH','en','abbr'),
('單相','Single Phase','en','en'),
('單相','单相','zh-CN','zh_cn'),
('200V級','200V級','zh-TW','official'),
('200V級','200V Class','en','en'),
('200V級','230V','en','colloquial'),
('200V級','220V','en','generic'),
('400V級','400V級','zh-TW','official'),
('400V級','400V Class','en','en'),
('400V級','380V','en','colloquial'),
('400V級','440V','en','colloquial'),
('400V級','460V','en','colloquial'),
('DC24V','DC24V','en','abbr'),
('DC24V','24VDC','en','abbr'),
('DC24V','24V直流','zh-TW','colloquial'),
('AC110V','AC110V','en','abbr'),
('AC110V','110VAC','en','abbr'),
('AC220V','AC220V','en','abbr'),
('AC220V','220VAC','en','abbr'),
('AC220V','220V','en','generic'),
('極數','極數','zh-TW','official'),
('極數','Pole','en','en'),
('極數','1P','en','generic'),
('極數','2P','en','generic'),
('極數','3P','en','generic'),
('極數','4P','en','generic'),
('IP防護等級','IP','en','abbr'),
('IP防護等級','防護等級','zh-TW','official'),
('IP防護等級','防水等級','zh-TW','colloquial'),
('DIN軌','DIN Rail','en','en'),
('DIN軌','DIN軌道','zh-TW','colloquial'),
('DIN軌','導軌','zh-TW','generic'),
('馬力','HP','en','abbr'),
('馬力','匹','zh-TW','colloquial'),
('千瓦','kW','en','abbr'),
('千瓦','瓩','zh-TW','legacy');


INSERT INTO glossary_alias (term_id, alias, lang, kind)
SELECT t.id, s.alias, s.lang, s.kind
FROM alias_seed s
JOIN glossary_term t ON t.canonical = s.canonical;

-- 太籠統或太短的別名不拿去比對品名，避免誤中：
--   generic 一律排除；純 ASCII 且 2 字元以下（MC、PB、TR、NO…）、單一字元（匹）也排除
UPDATE glossary_alias
SET search_expand = 0
WHERE kind = 'generic'
   OR CHAR_LENGTH(alias) < 2
   OR alias REGEXP '^[A-Za-z0-9 .-]{1,2}$';

-- ============================================================
-- 範例資料：型號規則
-- ※ decode_note 為方便 agent 理解的摘要，上線前請對照原廠型錄校對
-- ※ pattern 要對照 vc_products_no 實際寫法（有無連字號、有無空白）調整
-- ============================================================
CREATE TEMPORARY TABLE rule_seed (
  brand VARCHAR(100), category VARCHAR(100), pattern VARCHAR(100),
  series VARCHAR(100), decode_note VARCHAR(500), successor VARCHAR(100)
) DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;


INSERT INTO rule_seed VALUES
('Mitsubishi Electric','變頻器','FR-D7%','FR-D700','小型變頻器。FR-D720=三相200V級、FR-D720S=單相200V級、FR-D740=三相400V級；後段為容量','FR-D800'),
('Mitsubishi Electric','變頻器','FR-E7%','FR-E700','小型變頻器，功能比 D700 完整；型號格式與 D700 類似','FR-E800'),
('Mitsubishi Electric','可程式控制器','FX3U%','MELSEC FX3U','基本單元。如 FX3U-32MR/ES：32=I/O點數、MR=繼電器輸出、MT=電晶體輸出','FX5U'),
('Mitsubishi Electric','伺服驅動器','MR-J4%','MR-J4','AC 伺服放大器。MR-J4-xxxA=通用介面、MR-J4-xxxB=SSCNET III/H 通訊型','MR-J5'),
('Mitsubishi Electric','電磁接觸器','S-T%','S-T','電磁接觸器；後接容量級別，線圈電壓需另確認',NULL),
('Mitsubishi Electric','熱過載繼電器','TH-T%','TH-T','熱過載繼電器，與 S-T 接觸器搭配；需確認電流設定範圍',NULL),
('Mitsubishi Electric','無熔絲斷路器','NF%','NF','無熔絲斷路器，如 NF63-CV、NF125-CV；數字為框架容量(AF)',NULL),
('Omron','繼電器','MY%','MY','小型電力繼電器。MY2=2組接點、MY4=4組接點；底座另購',NULL),
('Omron','繼電器','LY%','LY','電力繼電器。LY2=2極、LY4=4極',NULL),
('Omron','繼電器','G2R%','G2R','PCB 型電力繼電器，G2R-1=單極、G2R-2=雙極',NULL),
('Omron','近接開關','E2E%','E2E','圓柱型電感式近接開關；型號含檢出距離、輸出型式(NPN/PNP、NO/NC)、連接方式',NULL),
('Omron','光電開關','E3Z%','E3Z','小型光電開關；尾碼表示感測方式(對照/反射/擴散反射)與輸出型式',NULL),
('Omron','固態繼電器','G3NA%','G3NA','固態繼電器，面板/DIN軌安裝；需確認負載類型與電流',NULL),
('Omron','編碼器','E6B2%','E6B2','增量型旋轉編碼器，如 E6B2-CWZ6C；型號含解析度(P/R)與輸出型式',NULL),
('Omron','計時器','H3Y%','H3Y','小型計時器（限時電驛）',NULL),
('Omron','溫度控制器','E5CC%','E5CC','數位溫度控制器',NULL),
('Delta Electronics','變頻器','VFD%EL%','VFD-EL','小型變頻器。如 VFD007EL21A：007=0.75kW、21=單相230V、23=三相230V、43=三相460V',NULL),
('Delta Electronics','可程式控制器','DVP%','DVP','PLC 系列（SS/SA/SX/ES/EH 等子系列），尾碼含輸出型式',NULL),
('Delta Electronics','人機介面','DOP-%','DOP','HMI。DOP-B 系列型號含螢幕尺寸代碼（如 B07 約 7 吋級）',NULL),
('Delta Electronics','伺服驅動器','ASD-B2%','ASD-B2','伺服驅動器，搭配 ECMA 系列伺服馬達',NULL),
('Delta Electronics','伺服馬達','ECMA%','ECMA','伺服馬達，搭配 ASD 系列驅動器',NULL),
('Autonics','近接開關','PR%','PR','圓柱型近接開關。PR12-4DN：12=外徑12mm、4=檢出距離4mm、DN=DC三線NPN常開；DP=PNP常開；DN2/DP2=常閉',NULL),
('Autonics','編碼器','E40S%','E40S','增量型旋轉編碼器，外徑40mm；型號含軸徑、解析度、輸出型式、電壓',NULL),
('Schneider Electric','電磁接觸器','LC1D%','TeSys D','接觸器。LC1D09=9A級；尾碼為線圈電壓（M7=AC220V、B7=AC24V、BD=DC24V）',NULL),
('Schneider Electric','熱過載繼電器','LRD%','TeSys LRD','熱過載繼電器；LRD 後的代號對應電流設定範圍，需查樣本',NULL),
('Schneider Electric','馬達保護斷路器','GV2%','TeSys GV2','馬達保護斷路器，如 GV2ME08；後段為電流範圍代號',NULL),
('Schneider Electric','按鈕開關','XB4%','Harmony XB4','22mm 開孔的按鈕、選擇開關、指示燈系列',NULL),
('Siemens','電磁接觸器','3RT%','SIRIUS 3RT','接觸器系列',NULL),
('Siemens','馬達保護斷路器','3RV%','SIRIUS 3RV','馬達保護斷路器系列',NULL),
('Siemens','可程式控制器','6ES7%','SIMATIC S7','S7 系列 PLC 與模組的料號前綴；世代(S7-300/1200/1500)由後段碼區分',NULL),
('Mean Well','電源供應器','LRS-%','LRS','封閉式開關電源。LRS-350-24：350=功率W、24=輸出電壓V',NULL),
('Mean Well','電源供應器','NDR-%','NDR','DIN 軌電源，命名格式同 LRS（功率-輸出電壓）',NULL),
('Panasonic','可程式控制器','FP0R%','FP0R','小型 PLC',NULL),
('Fuji Electric','電磁接觸器','SC-N%','SC-N','電磁接觸器系列',NULL),
('Fuji Electric','無熔絲斷路器','BW%','BW','無熔絲斷路器系列',NULL),
('Shihlin Electric','無熔絲斷路器','BM%','BM','無熔絲開關系列',NULL);


INSERT INTO model_rule (brand_id, category_id, pattern, series, decode_note, successor)
SELECT b.id, c.id, s.pattern, s.series, s.decode_note, s.successor
FROM rule_seed s
JOIN glossary_term b ON b.canonical = s.brand
JOIN glossary_term c ON c.canonical = s.category;

DROP TEMPORARY TABLE alias_seed;
DROP TEMPORARY TABLE rule_seed;


-- ============================================================
-- 查詢範例（? 為使用者輸入的參數）
-- ============================================================

-- A. 術語查詢：精確比對，主要詞義排前面，generic 排後面
-- SELECT term_id, canonical, term_type, scope, definition, notes, status, replaced_by, alias_kind
-- FROM v_glossary_lookup
-- WHERE alias_norm = LOWER(REPLACE(REPLACE(REPLACE(REPLACE(?, ' ', ''), '-', ''), '_', ''), '.', ''))
-- ORDER BY (alias_kind = 'generic'), canonical
-- LIMIT 8;

-- B. 術語查詢：精確比對查不到時的模糊備援（限制筆數）
--    輸入太短會誤中（例如 thr 會中 Three Phase），建議應用層限制輸入至少 3 個字元，或只在精確比對無結果時才用
-- SELECT DISTINCT term_id, canonical, term_type, definition
-- FROM v_glossary_lookup
-- WHERE alias_norm LIKE CONCAT('%', LOWER(REPLACE(REPLACE(REPLACE(REPLACE(?, ' ', ''), '-', ''), '_', ''), '.', '')), '%')
-- LIMIT 5;

-- C. 同義詞展開：取得某術語（A 查到的 term_id）所有可比對品名的字串
--    建議由應用層取出清單，再丟給搜尋引擎；下面第二段是直接在 SQL 裡比對的寫法，
--    商品量大時會全表掃描（LIKE '%…%' 用不到索引），只適合小量或除錯
-- SELECT search_text FROM v_glossary_expand WHERE term_id = ?;
--
-- SELECT p.i_products_id, p.vc_products_no, p.vc_subject_TW0
-- FROM products p
-- WHERE p.i_use = 1
--   AND EXISTS (SELECT 1 FROM v_glossary_expand e
--               WHERE e.term_id = ?
--                 AND (p.vc_subject_TW0   LIKE CONCAT('%', e.search_text, '%')
--                   OR p.vc_shortName_TW0 LIKE CONCAT('%', e.search_text, '%')))
-- LIMIT 50;

-- D. 型號查詢：由型號反推品牌 / 品類 / 系列（要求含數字，避免 NFB 被當成 NF 型號）
-- SELECT b.canonical AS brand, c.canonical AS category, r.series, r.decode_note, r.successor
-- FROM model_rule r
-- JOIN glossary_term b ON b.id = r.brand_id
-- JOIN glossary_term c ON c.id = r.category_id
-- WHERE ? REGEXP '[0-9]'
--   AND LOWER(REPLACE(REPLACE(REPLACE(REPLACE(?, ' ', ''), '-', ''), '_', ''), '.', '')) LIKE r.pattern_norm
-- ORDER BY CHAR_LENGTH(r.pattern_norm) DESC
-- LIMIT 3;

-- E. 型號前綴撈商品：只用前綴比對，可走 idx_products_no（前提是 pattern 寫法與品號一致）
-- SELECT p.i_products_id, p.vc_products_no, p.vc_subject_TW0
-- FROM products p
-- WHERE p.i_use = 1
--   AND p.vc_products_no LIKE (SELECT pattern FROM model_rule WHERE id = ?)
-- LIMIT 50;

-- F. 規則覆蓋率檢查：拿真實品號驗證每條 pattern 有沒有命中，沒命中多半是品號寫法不同
-- SELECT r.id, r.series, r.pattern, COUNT(p.i_products_id) AS hit
-- FROM model_rule r
-- LEFT JOIN products p ON p.i_use = 1 AND p.vc_products_no LIKE r.pattern
-- GROUP BY r.id, r.series, r.pattern
-- ORDER BY hit;
