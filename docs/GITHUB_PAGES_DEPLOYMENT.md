# GitHub Pages 正式發布步驟

目前專案已準備自動發布流程，但尚未建立 GitHub 遠端倉庫，也尚未公開網站。

## 一、建立 GitHub 倉庫

1. 登入 GitHub，建立一個新的私人倉庫。私人倉庫使用 GitHub Pages 可能需要付費方案，實際資格以 GitHub 帳號顯示為準。
2. 建議倉庫名稱使用 `806-online-contact-book`。
3. 建立時不要另外加入 README、`.gitignore` 或授權檔，以免與本機專案衝突。
4. 將 GitHub 顯示的倉庫網址保存下來，之後再由 Codex 協助連接與推送。

> 不要直接將目前包含既有 Git 歷史的倉庫改為公開。早期測試紀錄曾含有學生識別資料；若必須使用公開倉庫，應另建不含舊提交歷史的乾淨部署倉庫。

## 二、設定部署資料

進入 GitHub 倉庫的 `Settings` → `Secrets and variables` → `Actions`。

在 `Secrets` 建立：

- `VITE_SUPABASE_URL`：共用 Supabase 專案網址。
- `VITE_SUPABASE_PUBLISHABLE_KEY`：Supabase 公開金鑰。

這兩項是前端原本就必須使用的公開連線資料；請勿放入 Database password 或 service role key。

在 `Variables` 建立：

- `VITE_LEARNING_SYSTEM_URL`：登入後「前往各科學習系統」按鈕的正式網址。若尚未決定，可先不建立。

## 三、啟用 GitHub Pages

1. 進入 `Settings` → `Pages`。
2. 在 `Build and deployment` 的 `Source` 選擇 `GitHub Actions`。
3. 推送 `main` 分支後，GitHub 會依序安裝套件、執行測試、建置並發布網站。
4. 只有測試及建置成功時才會更新正式網站。

## 四、發布後驗收

1. 確認 GitHub Actions 最新一次執行為綠色成功狀態。
2. 使用電腦開啟正式網址並測試管理員登入。
3. 手機關閉 Wi-Fi，改用行動網路開啟正式網址。
4. 依照 [第一版正式操作驗收表](MANUAL_ACCEPTANCE_CHECKLIST.md) 完成各角色測試。

正式網址使用 HTTPS，因此手機發布公告時也可直接使用瀏覽器的安全加密功能，不再受區域網路 HTTP 限制。
