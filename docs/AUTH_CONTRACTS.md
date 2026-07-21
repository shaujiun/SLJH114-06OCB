# 登入服務契約

前端不直接保存或驗證帳號密碼，而是呼叫已部署的 Supabase Edge Functions。本文件固定前後端交換格式，供後續維護與驗收使用。

## 安全原則

- 學生及教師在畫面上輸入的是學號／自訂帳號，不要求電子郵件。
- Auth 內部使用 HMAC 雜湊後的別名電子郵件，別名不包含原始學號或教師帳號。
- 內部 Supabase Auth 帳號轉換只在 Edge Function 執行。
- service role 金鑰只能存在 Edge Function 環境，不得進入 Vite 環境變數。
- 一次性啟用碼只比對雜湊值；成功使用後立刻標記失效。
- 教師註冊完成後維持 `pending`，核准前不得取得班級資料。
- 登入錯誤訊息不能透露某個學號或教師帳號是否存在。
- 公開端點以雜湊後的 IP／帳號識別執行次數限制，不保存原始 IP。

## `account-login`

學生／家長及教師共用的登入入口。

請求：

```json
{
  "accountType": "student",
  "username": "115001",
  "password": "使用者輸入的密碼"
}
```

教師的 `accountType` 為 `teacher`。

成功回應：

```json
{
  "session": {
    "access_token": "...",
    "refresh_token": "..."
  },
  "profile": {
    "displayName": "學生姓名或教師姓名",
    "role": "student",
    "approvalStatus": "approved"
  }
}
```

教師仍等待核准時，可以回傳 `approvalStatus: pending`，但不能回傳可讀取班級資料的有效工作階段。

## `student-activate`

請求：

```json
{
  "studentId": "115001",
  "activationCode": "AB12CD",
  "password": "使用者建立的密碼"
}
```

成功條件：

1. 學生存在且尚未綁定登入帳號。
2. 啟用碼未使用且未過期。
3. 以固定時間方式比對啟用碼雜湊。
4. 若英文單字 Auth 帳號已存在，驗證原密碼並沿用同一個使用者 ID；若不存在，建立兩套系統共用的 Auth 使用者。
5. 建立學生 `contact_book_profiles`。
6. 將 `students.profile_id` 綁定共用帳號。
7. 將啟用碼標記為已使用。

以上步驟必須在安全的伺服器流程中完成；任一步失敗都不能留下可登入但未綁定的半成品帳號。

## `teacher-register`

請求：

```json
{
  "username": "teacher.wang",
  "displayName": "王老師",
  "password": "使用者建立的密碼"
}
```

成功後建立：

- Supabase Auth 使用者。
- `contact_book_profiles.user_type = teacher`。
- `contact_book_profiles.approval_status = pending`。

不建立班級或科目授權；導師核准時才新增 `class_staff_assignments`。

## 錯誤格式

Edge Function 對前端回傳一致格式：

```json
{
  "error": "帳號或密碼不正確。"
}
```

伺服器日誌可保存內部錯誤碼，但不得保存明碼密碼或完整啟用碼。
