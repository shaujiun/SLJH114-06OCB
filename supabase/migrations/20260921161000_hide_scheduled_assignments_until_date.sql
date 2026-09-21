begin;

-- assignment_date 是學生開始看見作業的臺灣日期；published_at 仍記錄實際建立時間。
-- 教師／管理者可提前檢查；學生幹部與一般學生在指定日期前都不可讀取內容。
drop policy if exists assignments_read_allowed on public.assignments;
create policy assignments_read_allowed on public.assignments
for select to authenticated using (
  public.can_manage_subject(class_subject_id)
  or (
    assignment_date <= (now() at time zone 'Asia/Taipei')::date
    and (
      public.can_access_assignment_as_staff(id)
      or (is_active and public.is_current_student_assignment_recipient(id))
    )
  )
);

commit;
