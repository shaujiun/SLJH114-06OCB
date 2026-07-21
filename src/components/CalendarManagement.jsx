import { useCallback, useEffect, useState } from 'react'
import { CalendarPlus, Eye, EyeOff, Pencil, RefreshCw, Save, X } from 'lucide-react'
import {
  calendarCategories,
  calendarCategoryLabels,
  currentMonthKey,
  loadCalendarEvents,
  localDateKey,
  saveCalendarEvent,
  setCalendarEventActive,
} from '../services/calendarService.js'
import { calendarEventDisplayTitle, calendarEventOfficeClass } from '../services/calendarImportService.js'
import CalendarImportPanel from './CalendarImportPanel.jsx'
import MonthCalendar, { calendarEventTimeLabel } from './MonthCalendar.jsx'

const emptyForm = (date = localDateKey()) => ({
  title: '', description: '', location: '', category: 'class_activity',
  startsOn: date, endsOn: date, isAllDay: true, startTime: '08:00', endTime: '09:00',
})

function compactCalendarDate(dateKey) {
  const [, month, day] = dateKey.split('-')
  return `${month}/${day}`
}

function calendarAdminDateLabel(event) {
  return event.startsOn === event.endsOn
    ? compactCalendarDate(event.startsOn)
    : `${compactCalendarDate(event.startsOn)}～${compactCalendarDate(event.endsOn)}`
}

export default function CalendarManagement({ dashboard, onNotice }) {
  const [month, setMonth] = useState(currentMonthKey())
  const [selectedDate, setSelectedDate] = useState(localDateKey())
  const [events, setEvents] = useState([])
  const [form, setForm] = useState(emptyForm)
  const [editingId, setEditingId] = useState('')
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [statusId, setStatusId] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    try {
      setEvents(await loadCalendarEvents({
        classId: dashboard.classInfo.id,
        month,
        includeInactive: true,
      }))
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setLoading(false)
    }
  }, [dashboard.classInfo.id, month, onNotice])

  useEffect(() => { load() }, [load])

  function update(field, value) {
    setForm((current) => ({ ...current, [field]: value }))
  }

  function resetForm(date = selectedDate) {
    setEditingId('')
    setForm(emptyForm(date))
  }

  function startEditing(event) {
    setEditingId(event.id)
    setForm({
      title: event.title,
      description: event.description,
      location: event.location,
      category: event.category,
      startsOn: event.startsOn,
      endsOn: event.endsOn,
      isAllDay: event.isAllDay,
      startTime: event.startTime || '08:00',
      endTime: event.endTime || '09:00',
    })
    document.querySelector('.calendar-event-form')?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }

  async function submit(event) {
    event.preventDefault()
    setSaving(true)
    try {
      const wasEditing = Boolean(editingId)
      const title = form.title.trim()
      await saveCalendarEvent({
        eventId: editingId || null,
        classId: dashboard.classInfo.id,
        ...form,
      })
      setMonth(form.startsOn.slice(0, 7))
      setSelectedDate(form.startsOn)
      resetForm(form.startsOn)
      await load()
      onNotice('success', `行程「${title}」已${wasEditing ? '更新' : '新增'}。`)
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setSaving(false)
    }
  }

  async function toggleActive(event) {
    const action = event.isActive ? '下架' : '恢復'
    if (!window.confirm(`確定要${action}行程「${event.title}」嗎？`)) return
    setStatusId(event.id)
    try {
      await setCalendarEventActive({ eventId: event.id, isActive: !event.isActive })
      await load()
      onNotice('success', `行程「${event.title}」已${action}。`)
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setStatusId('')
    }
  }

  async function handleImported(firstDate) {
    const nextMonth = firstDate.slice(0, 7)
    setSelectedDate(firstDate)
    if (nextMonth === month) await load()
    else setMonth(nextMonth)
  }

  return (
    <section className="calendar-management">
      <div className="student-page-heading">
        <div><p className="eyebrow">CALENDAR MANAGEMENT</p><h2>行事曆管理</h2><p>建立班級、學校、考試及放假行程；下架後仍可恢復。</p></div>
        <button className="teacher-refresh-button" type="button" aria-label="重新整理行事曆" disabled={loading} onClick={load}><RefreshCw className={loading ? 'is-spinning' : ''} /></button>
      </div>

      <CalendarImportPanel
        classId={dashboard.classInfo.id}
        onImported={handleImported}
        onNotice={onNotice}
      />

      <div className="calendar-management-layout">
        <form className="calendar-event-form" onSubmit={submit}>
          <div className="student-panel-title"><span><CalendarPlus /></span><div><h3>{editingId ? '編輯行程' : '新增行程'}</h3><p>跨日活動可設定不同的開始與結束日期。</p></div></div>
          <label><span>行程標題</span><input required maxLength="80" value={form.title} onChange={(event) => update('title', event.target.value)} placeholder="例如：第一次段考" /></label>
          <div className="student-form-grid"><label><span>行程分類</span><select value={form.category} onChange={(event) => update('category', event.target.value)}>{calendarCategories.map((category) => <option value={category.value} key={category.value}>{category.label}</option>)}</select></label><label><span>地點（選填）</span><input maxLength="100" value={form.location} onChange={(event) => update('location', event.target.value)} placeholder="例如：各班教室" /></label></div>
          <div className="student-form-grid"><label><span>開始日期</span><input required type="date" value={form.startsOn} onChange={(event) => { update('startsOn', event.target.value); if (event.target.value > form.endsOn) update('endsOn', event.target.value) }} /></label><label><span>結束日期</span><input required type="date" min={form.startsOn} value={form.endsOn} onChange={(event) => update('endsOn', event.target.value)} /></label></div>
          <label className="calendar-all-day-toggle"><input type="checkbox" checked={form.isAllDay} onChange={(event) => update('isAllDay', event.target.checked)} /><span>全天行程</span></label>
          {!form.isAllDay && <div className="student-form-grid"><label><span>開始時間</span><input required type="time" value={form.startTime} onChange={(event) => update('startTime', event.target.value)} /></label><label><span>結束時間</span><input required type="time" value={form.endTime} onChange={(event) => update('endTime', event.target.value)} /></label></div>}
          <label><span>詳細說明（選填）</span><textarea rows="5" maxLength="2000" value={form.description} onChange={(event) => update('description', event.target.value)} placeholder="提供學生與家長需要知道的內容" /></label>
          <div className="honor-form-actions">{editingId && <button className="secondary-button" type="button" disabled={saving} onClick={() => resetForm()}><X />取消編輯</button>}<button className="approve-button" type="submit" disabled={saving || !form.title.trim()}><Save />{saving ? '儲存中…' : editingId ? '儲存行程變更' : '新增至行事曆'}</button></div>
        </form>

        <MonthCalendar events={events} month={month} selectedDate={selectedDate} onMonthChange={setMonth} onSelectDate={(date) => { setSelectedDate(date); if (!editingId) setForm((current) => ({ ...current, startsOn: date, endsOn: date })) }} loading={loading} />
      </div>

      <section className="calendar-admin-list-panel">
        <div className="student-list-heading"><div><span><CalendarPlus /></span><div><h3>本月行程管理</h3><p>共 {events.length} 項，包含已下架行程。</p></div></div></div>
        {!events.length && <div className="student-list-empty"><CalendarPlus /><strong>本月尚無行程</strong><span>可從上方表單建立第一筆行程。</span></div>}
        <div className="calendar-admin-list">
          {events.map((event) => (
            <article className={`${event.isActive ? '' : 'is-inactive'} is-${event.category}${calendarEventOfficeClass(event)}`} key={event.id}>
              <div className="calendar-admin-card-body">
                <div className="calendar-admin-card-topline">
                  <span>{event.sourceOffice || calendarCategoryLabels[event.category]}</span>
                  <span>{calendarAdminDateLabel(event)}・{calendarEventTimeLabel(event)}</span>
                </div>
                <div className="calendar-admin-card-title"><h3>{calendarEventDisplayTitle(event)}</h3>{event.location && <span>{event.location}</span>}</div>
                {event.sourceAudience && <p>{event.sourceAudience}</p>}
              </div>
              <div className="calendar-admin-card-actions"><button type="button" onClick={() => startEditing(event)}><Pencil />編輯</button><button type="button" disabled={statusId === event.id} onClick={() => toggleActive(event)}>{event.isActive ? <EyeOff /> : <Eye />}{statusId === event.id ? '處理中…' : event.isActive ? '下架' : '恢復'}</button></div>
            </article>
          ))}
        </div>
      </section>
    </section>
  )
}
