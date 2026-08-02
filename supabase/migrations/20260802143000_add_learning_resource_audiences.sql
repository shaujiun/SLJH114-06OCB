-- 學習資源可依共同、數學 A/B 組或英語 A/B 組顯示。

alter table public.learning_resources
  add column if not exists audience_scope text not null default 'common';

alter table public.learning_resources
  drop constraint if exists learning_resources_audience_scope_check;

alter table public.learning_resources
  add constraint learning_resources_audience_scope_check
  check (audience_scope in ('common', 'math_a', 'math_b', 'english_a', 'english_b'));

create index if not exists learning_resources_class_audience_list_idx
  on public.learning_resources(class_id, audience_scope, is_active, published_at desc);

create or replace function public.learning_resource_audience_matches_subject(
  target_class_subject_id uuid,
  target_audience_scope text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select lower(coalesce(target_audience_scope, 'common')) = 'common'
    or exists (
      select 1
      from public.class_subjects class_subject
      join public.subjects subject on subject.id = class_subject.subject_id
      where class_subject.id = target_class_subject_id
        and class_subject.is_active
        and (
          (lower(target_audience_scope) in ('math_a', 'math_b') and lower(subject.code::text) = 'math')
          or (lower(target_audience_scope) in ('english_a', 'english_b') and lower(subject.code::text) = 'english')
        )
    );
$$;

revoke all on function public.learning_resource_audience_matches_subject(uuid, text) from public;
revoke all on function public.learning_resource_audience_matches_subject(uuid, text) from anon;
grant execute on function public.learning_resource_audience_matches_subject(uuid, text) to authenticated;

create or replace function public.learning_resource_audience_allowed(
  target_class_id uuid,
  target_audience_scope text,
  reference_date date default current_date
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  current_user_type text;
  current_student_id uuid;
  normalized_scope text := lower(coalesce(target_audience_scope, 'common'));
  target_subject text;
  target_group text;
begin
  select profile.user_type
  into current_user_type
  from public.contact_book_profiles profile
  where profile.id = auth.uid()
    and profile.approval_status = 'approved'
    and profile.is_active;

  if current_user_type is null then
    return false;
  end if;

  if current_user_type <> 'student' then
    return true;
  end if;

  select student.id
  into current_student_id
  from public.students student
  where student.profile_id = auth.uid()
    and student.class_id = target_class_id
    and student.is_active
  limit 1;

  if current_student_id is null then
    return false;
  end if;

  if normalized_scope = 'common' then
    return true;
  end if;

  case normalized_scope
    when 'math_a' then target_subject := 'math'; target_group := 'A';
    when 'math_b' then target_subject := 'math'; target_group := 'B';
    when 'english_a' then target_subject := 'english'; target_group := 'A';
    when 'english_b' then target_subject := 'english'; target_group := 'B';
    else return false;
  end case;

  return upper(public.resolve_student_learning_group(
    current_student_id,
    target_subject,
    reference_date
  )) = target_group;
end;
$$;

revoke all on function public.learning_resource_audience_allowed(uuid, text, date) from public;
revoke all on function public.learning_resource_audience_allowed(uuid, text, date) from anon;
grant execute on function public.learning_resource_audience_allowed(uuid, text, date) to authenticated;

drop policy if exists learning_resources_read_allowed
  on public.learning_resources;
create policy learning_resources_read_allowed
on public.learning_resources
for select
to authenticated
using (
  public.contact_book_is_admin()
  or (
    created_by = auth.uid()
    and public.is_approved_user()
  )
  or (
    is_active
    and published_at <= now()
    and public.can_view_class(class_id)
    and public.learning_resource_audience_allowed(class_id, audience_scope, current_date)
  )
);

drop policy if exists learning_resources_insert_allowed
  on public.learning_resources;
create policy learning_resources_insert_allowed
on public.learning_resources
for insert
to authenticated
with check (
  created_by = auth.uid()
  and updated_by = auth.uid()
  and public.learning_resource_audience_matches_subject(class_subject_id, audience_scope)
  and (
    (
      public.contact_book_is_admin()
      and public.can_manage_class(class_id)
      and public.learning_resource_subject_matches(class_id, class_subject_id)
    )
    or (
      class_subject_id is not null
      and public.can_manage_subject(class_subject_id)
      and public.learning_resource_subject_matches(class_id, class_subject_id)
    )
  )
);

drop policy if exists learning_resources_update_allowed
  on public.learning_resources;
create policy learning_resources_update_allowed
on public.learning_resources
for update
to authenticated
using (
  (
    public.contact_book_is_admin()
    and public.can_manage_class(class_id)
  )
  or (
    created_by = auth.uid()
    and class_subject_id is not null
    and public.can_manage_subject(class_subject_id)
  )
)
with check (
  updated_by = auth.uid()
  and public.learning_resource_audience_matches_subject(class_subject_id, audience_scope)
  and (
    (
      public.contact_book_is_admin()
      and public.can_manage_class(class_id)
      and public.learning_resource_subject_matches(class_id, class_subject_id)
    )
    or (
      created_by = auth.uid()
      and class_subject_id is not null
      and public.can_manage_subject(class_subject_id)
      and public.learning_resource_subject_matches(class_id, class_subject_id)
    )
  )
);
