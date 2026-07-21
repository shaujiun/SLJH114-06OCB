# Supabase 資料庫與函式

此資料夾保存線上聯絡簿的資料庫遷移、RLS 權限、Edge Functions 與驗證工具。雲端沿用既有的「英文單字測驗」Supabase 專案；截至 `20260720020000` 的遷移與登入函式均已套用。

## 檔案順序

1. `shared-project-compatibility.sql`：保護英文單字系統的 Auth 註冊觸發器。
2. `schema.sql`：資料表、索引、檢查條件與共用觸發器。
3. `rls-policies.sql`：角色判斷函式與 Row Level Security 草案。
4. `seed.sql`：115 學年度八年六班及初始科目。
5. `config.toml`：本機及函式設定。
6. `functions/`：學生啟用、共用登入、教師註冊與共用安全模組。

## 正式發布前仍須完成

- 使用管理員、未核准教師、數學老師、英語老師、小老師、A 組學生及 B 組學生測試權限。
- 完成手機與桌面畫面驗收。
- 設定 GitHub 遠端倉庫並部署正式公開網址。

## 本機環境說明

本機沒有 Docker，因此不執行本機 Supabase 容器；資料庫遷移、遠端 lint 與函式部署直接透過已連結的 Supabase 雲端專案驗證。
