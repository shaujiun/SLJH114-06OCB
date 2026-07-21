import { useCallback, useEffect, useState } from 'react'
import { CalendarRange, RefreshCw } from 'lucide-react'
import { currentMonthKey, loadCalendarEvents, localDateKey } from '../services/calendarService.js'
import MonthCalendar from './MonthCalendar.jsx'

export default function CalendarViewer({ classId, audience = 'student' }) {
  const [month, setMonth] = useState(currentMonthKey())
  const [selectedDate, setSelectedDate] = useState(localDateKey())
  const [events, setEvents] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    try {
      setEvents(await loadCalendarEvents({ classId, month }))
      setError('')
    } catch (loadError) {
      setError(loadError.message)
    } finally {
      setLoading(false)
    }
  }, [classId, month])

  useEffect(() => { load() }, [load])

  return (
    <section className={`calendar-viewer is-${audience}`}>
      <div className="student-page-heading calendar-page-heading">
        <div><p className="eyebrow">CLASS CALENDAR</p><h1>班級行事曆</h1><p>切換月份並點選日期，即可查看當天完整行程。</p></div>
        <button type="button" aria-label="重新整理行事曆" disabled={loading} onClick={load}><RefreshCw className={loading ? 'is-spinning' : ''} /></button>
      </div>
      {error && <div className="admin-notice is-error"><CalendarRange />{error}</div>}
      <MonthCalendar
        events={events}
        month={month}
        selectedDate={selectedDate}
        onMonthChange={setMonth}
        onSelectDate={setSelectedDate}
        loading={loading}
      />
    </section>
  )
}
