# 登入 Edge Functions

| 函式 | 用途 | 登入前可用 |
| --- | --- | --- |
| `account-login` | 學生／家長及教師共用登入 | 是 |
| `student-activate` | 學號＋一次性啟用碼建立密碼 | 是 |
| `student-reset-password` | 學號＋一次性重設碼自行建立新密碼 | 是 |
| `teacher-register` | 任課老師自行註冊 pending 帳號 | 是 |

後台另有 `admin-create-student`、`admin-regenerate-activation` 與
`admin-create-password-reset` 等需登入且僅限管理員使用的函式。

## 共用安全措施

- Auth 帳號別名與英文單字系統一致，同一組帳密可供兩套系統使用。
- 啟用碼只比對 HMAC 雜湊。
- 公開端點資料庫節流，不保存原始 IP。
- service role 只存在 Edge Function 環境。
- 學生啟用資料由單一資料庫交易完成。
- Auth 建立後若資料庫寫入失敗，刪除半成品 Auth 使用者。
- 統一錯誤訊息，避免透露帳號是否存在。

## 部署前祕密

- `ACTIVATION_CODE_HMAC_SECRET`
- `RATE_LIMIT_HMAC_SECRET`

兩者必須使用不同的長隨機值。
