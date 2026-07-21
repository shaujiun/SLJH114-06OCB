# Supabase 雲端專案設定

## 目前狀態

- Supabase CLI 已安裝為本專案開發套件。
- `supabase/config.toml` 已建立。
- 資料表與 RLS 使用宣告式 SQL 管理。
- `account-login`、`student-activate`、`teacher-register` 已完成本機程式與打包檢查。
- 本機沒有 Docker，因此不啟動本機 Supabase 容器。

## 共用的雲端專案

聯絡簿沿用既有的「英文單字測驗」Supabase 專案，不另外占用免費方案的第 3 個專案。

共用原則：

1. 英文單字系統保留原本的 `profiles`、`vocabulary`、`student_progress` 與 `mastered_words`。
2. 聯絡簿帳號改用 `contact_book_profiles`，不覆寫英文單字系統的 `profiles`。
3. 兩套系統沿用相同的 `username@vocab-explorer.app` Auth 帳號別名。
4. 既有英文單字帳號可以直接綁定聯絡簿；新學生啟用聯絡簿時會同時建立英文單字帳號。
5. 兩套網站部署在同一個 GitHub Pages 網域來源時，可共用瀏覽器登入狀態。
6. 在確認測試帳號與角色權限正確前，不匯入真實學生資料。

`Publishable key` 可以放在前端；`Secret key`、`service_role`、資料庫密碼及 Supabase Access Token 都不能貼在公開訊息、程式碼或 GitHub。

## 連線後的執行順序

1. 由 CLI 登入並連結既有的英文單字測驗 Project reference。
2. 先備份英文單字系統的資料表與 Auth 使用者清單。
3. 先套用 `shared-project-compatibility.sql`，讓英文單字觸發器略過聯絡簿帳號。
4. 依宣告式 SQL 產生第一筆聯絡簿 migration。
5. 將 migration 套用到雲端並確認 SQL 真正成功。
6. 產生兩個至少 32 字元的隨機 HMAC 祕密。
7. 使用 Supabase secrets 設定函式環境，不寫入 `.env.local` 或 Git。
8. 部署三個 Edge Functions。
9. 建立第一位導師管理員。
10. 建立測試學生與一次性啟用碼。
11. 以未核准教師、核准教師及學生帳號驗證權限。
12. 回歸測試英文單字系統登入、單字紀錄及管理功能。
13. 兩套系統都通過後才匯入真實學生名單。

## 英文單字系統備份

本機沒有 Docker，因此不使用 `supabase db dump`。改由已登入的 Supabase CLI 在單一 PowerShell 程序記憶體內取得 `service_role`，再透過官方 API 唯讀匯出：

- `profiles`、`vocabulary`、`student_progress`、`mastered_words`。
- Auth 使用者 ID、電子郵件、時間與 metadata；不匯出密碼雜湊。
- PostgREST OpenAPI 結構及本機 `supabase-schema.sql` 快照。

執行方式：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\backup-shared-supabase.ps1
```

備份輸出到 `backups/`。該資料夾已被 Git 忽略，不能上傳到 GitHub 或公開分享。執行完成後，PowerShell 會清除程序中的後端金鑰。

## 前端環境變數

正式連線時只在 `.env.local` 保存：

```text
VITE_SUPABASE_URL=專案網址
VITE_SUPABASE_PUBLISHABLE_KEY=公開金鑰
```

`.env.local` 已被 Git 忽略，不會進入版本紀錄。
