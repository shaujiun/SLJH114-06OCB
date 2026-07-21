# 線上聯絡簿的建立

供 115 學年度八年六班使用的線上聯絡簿。系統以手機操作為優先，提供分組作業、繳交追蹤、公告已讀、榮譽榜、學生／家長個人檢視，以及教師與學生幹部的分級權限。

## 目前進度

第一版核心功能已完成，並已連接共用的「英文單字測驗」Supabase 專案。

- 已完成學生首次啟用、共用登入、密碼重設，以及教師註冊、核准、停用與多科授權。
- 已完成學生建檔、數學／英語獨立分組、作業長及分組科目小老師設定。
- 已完成共同、A 組、B 組作業發布、取消、全班繳交及例外學生追蹤。
- 已完成未完成、未攜帶、遲交、請假、公假、免交、補交與歷程統計。
- 已完成全校／班級公告、圖片、學生已讀及管理員已讀／未讀名單。
- 已完成多人榮譽榜的新增、編輯、隱藏、重新顯示及刪除。
- 已完成獨立班級行事曆，支援月份切換、跨日活動、分類、管理員編輯與可復原下架。
- 已完成 Excel 校務行事曆預覽匯入、八年級對象篩選、處室色彩及重複資料攔截。
- 學生端以獨立標籤切換聯絡簿、公告欄與班級行事曆。
- 已完成班級科目新增、啟用／停用及排序。
- Supabase 遷移與 Edge Functions 已套用至共用雲端專案。
- 已完成 GitHub Pages 初次發布，正式角色與手機外部網路驗收進行中。
- 正式網址：https://shaujiun.github.io/SLJH114-06OCB/

## 已確認技術架構

- 前端：React、Vite，採手機優先設計。
- 程式版本與前端部署：GitHub、GitHub Pages。
- 帳號、關聯資料與權限：Supabase Auth、PostgreSQL、Row Level Security。
- 公告圖片：Supabase Storage。
- 第一版目標日期：2026 年 8 月 7 日。

## 文件

- [正式需求規格](docs/PROJECT_SPEC.md)
- [資料模型說明](docs/DATA_MODEL.md)
- [第一版驗收標準](docs/ACCEPTANCE_CRITERIA.md)
- [第一版正式操作驗收表](docs/MANUAL_ACCEPTANCE_CHECKLIST.md)
- [登入服務契約](docs/AUTH_CONTRACTS.md)
- [Supabase 雲端專案設定](docs/SUPABASE_SETUP.md)
- [GitHub Pages 正式發布步驟](docs/GITHUB_PAGES_DEPLOYMENT.md)
- [Supabase 草案說明](supabase/README.md)

## 本機執行

```powershell
npm install
npm run dev
```

測試及建置：

```powershell
npm test
npm run build
```

## 安全原則

- 學生資料不能只靠前端隱藏，必須由資料庫權限限制。
- 未核准的教師帳號不能讀取班級資料。
- 瀏覽器端不得放置 Supabase service role 金鑰。
- 啟用碼只保存雜湊值，不保存可直接使用的明碼。
- 真實資料匯入前，必須先以測試帳號通過權限驗收。
