# 資料模型說明

## 設計重點

### 一班使用，多班預留

所有作業、學生、公告、成績及權限都關聯 `class_id`。第一版介面不顯示班級切換，但未來分享給其他老師時，可以在同一套程式中隔離不同班級。

### 分組依科目保存

`student_subject_groups` 以學生、班級科目、學期及生效日期保存分組，數學與英語互不影響。作業發布時寫入 `assignment_recipients`，使歷史作業不受日後分組調整影響。

### 只記錄繳交例外

`submission_checks` 保存該次點收是否完成；全班皆交時不建立 30 筆正常紀錄。只有異常學生建立 `submission_exceptions`，並以 `submission_status_events` 保存每次變更。

### 請假不是永久免交

請假與公假紀錄保存 `follow_up_due_at`。到下一次該科上課仍未交時，狀態可轉為未完成、未攜帶或遲交，並開始計數。

### 已補交不刪除

`resolved_at` 保存補交時間，`hide_after` 設為補交後 1 天。待辦清單只篩選尚未到 `hide_after` 的資料，統計與歷史仍讀取原紀錄。

### 成績先匯入、後發布

`grade_import_batches` 保存每次 Excel 匯入紀錄，`student_grade_results` 以考試與學生為唯一組合。重複匯入同一次考試時更新既有成績，空白欄位不覆蓋先前資料，方便日後補入校排。`grade_exam_periods.is_published` 控制學生是否能讀取該次成績。

## 主要資料表

| 資料表 | 用途 |
| --- | --- |
| `schools` | 學校基本資料 |
| `academic_years` | 學年度起訖 |
| `academic_terms` | 三個學期的起訖 |
| `classes` | 班級 |
| `contact_book_profiles` | 聯絡簿專用的 Supabase Auth 使用者對應資料、核准狀態；與英文單字系統的 `profiles` 隔離 |
| `students` | 學生、學號、座號與登入連結 |
| `student_activation_codes` | 一次性啟用碼雜湊與使用狀態 |
| `subjects` | 科目主檔 |
| `class_subjects` | 班級啟用的科目 |
| `class_staff_assignments` | 導師及任課教師授權 |
| `student_helper_assignments` | 作業長與科目小老師授權 |
| `student_subject_groups` | 各科目、各學期的學生分組歷史 |
| `assignments` | 作業內容、期限與適用群組 |
| `assignment_recipients` | 發布時的學生對象快照 |
| `submission_checks` | 全班繳交或例外點收完成紀錄 |
| `submission_exceptions` | 個別異常、追繳與補交現況 |
| `submission_status_events` | 狀態變更歷程 |
| `announcements` | 全校／班級公告及圖片路徑 |
| `announcement_reads` | 學生公告已讀紀錄 |
| `honor_entries` | 向全班公開的榮譽榜 |
| `assessment_periods` | 舊版預留評量期間，目前成績畫面不使用 |
| `assessments` | 舊版預留評量項目，目前成績畫面不使用 |
| `student_scores` | 舊版預留個人成績，目前成績畫面不使用 |
| `grade_exam_periods` | 段考／模擬考主檔、排序及發布狀態 |
| `grade_import_batches` | Excel 匯入批次與來源檔案稽核紀錄 |
| `student_grade_results` | 個人成績、排名、匯入來源與學生資料快照 |

## 權限函式方向

- `is_admin()`：是否為已核准管理員。
- `can_manage_class(class_id)`：是否為管理員或該班導師。
- `can_manage_subject(class_subject_id)`：是否為導師或被指派任課教師。
- `is_subject_helper(class_subject_id)`：是否為該科有效的小老師。
- `is_student_self(student_id)`：是否為該學生／家長共用帳號。

真正上線前，所有角色都必須使用獨立測試帳號驗證，不能只依管理員帳號測試。
