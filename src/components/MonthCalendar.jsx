import { CalendarDays, ChevronLeft, ChevronRight, Clock3, MapPin, RotateCcw } from 'lucide-react'
import {
  buildMonthCells,
  calendarCategoryLabels,
  eventsOnDate,
  localDateKey,
  shiftMonth,
} from '../services/calendarService.js'
import { calendarEventDisplayTitle, calendarEventOfficeClass } from '../services/calendarImportService.js'

const weekdays = ['日', '一', '二', '三', '四', '五', '六']

function monthTitle(month) {
  const [year, monthNumber] = month.split('-').map(Number)
  return `${year} 年 ${monthNumber} 月`
}

function dateTitle(dateKey) {
  const [year, month, day] = dateKey.split('-').map(Number)
  return `${year} 年 ${month} 月 ${day} 日`
}

export function calendarEventTimeLabel(event) {
  if (event.isAllDay) return '全天'
  return `${event.startTime}－${event.endTime}`
}

export function calendarEventDateLabel(event) {
  const compactDate = (dateKey) => {
    const [, month, day] = dateKey.split('-').map(Number)
    return `${month}/${day}`
  }
  return event.startsOn === event.endsOn
    ? compactDate(event.startsOn)
    : `${compactDate(event.startsOn)}～${compactDate(event.endsOn)}`
}

export default function MonthCalendar({
  events,
  month,
  selectedDate,
  onMonthChange,
  onSelectDate,
  loading = false,
}) {
  const cells = buildMonthCells(month)
  const selectedEvents = eventsOnDate(events, selectedDate)

  function changeMonth(nextMonth) {
    onMonthChange(nextMonth)
    onSelectDate(`${nextMonth}-01`)
  }

  function selectCell(cell) {
    if (!cell.isCurrentMonth) {
      onMonthChange(cell.dateKey.slice(0, 7))
    }
    onSelectDate(cell.dateKey)
  }

  return (
    <section className="calendar-board" aria-label="班級月份行事曆">
      <header className="calendar-board-toolbar">
        <button type="button" aria-label="上個月" onClick={() => changeMonth(shiftMonth(month, -1))}><ChevronLeft /></button>
        <div><CalendarDays /><h2>{monthTitle(month)}</h2>{loading && <span>讀取中…</span>}</div>
        <div className="calendar-board-navigation">
          <button type="button" onClick={() => changeMonth(localDateKey().slice(0, 7))}><RotateCcw />今天</button>
          <button type="button" aria-label="下個月" onClick={() => changeMonth(shiftMonth(month, 1))}><ChevronRight /></button>
        </div>
      </header>

      <div className="calendar-weekdays" aria-hidden="true">
        {weekdays.map((day) => <span key={day}>{day}</span>)}
      </div>
      <div className="calendar-month-grid">
        {cells.map((cell) => {
          const dayEvents = eventsOnDate(events, cell.dateKey)
          return (
            <button
              className={`${cell.isCurrentMonth ? '' : 'is-outside'}${cell.isToday ? ' is-today' : ''}${selectedDate === cell.dateKey ? ' is-selected' : ''}`}
              type="button"
              key={cell.dateKey}
              onClick={() => selectCell(cell)}
            >
              <span className="calendar-day-number">{cell.day}</span>
              <span className="calendar-day-events">
                {dayEvents.slice(0, 3).map((event) => (
                  <span className={`is-${event.category}${event.isActive ? '' : ' is-inactive'}${calendarEventOfficeClass(event)}`} key={event.id}>{calendarEventDisplayTitle(event)}</span>
                ))}
                {dayEvents.length > 3 && <small>另有 {dayEvents.length - 3} 項</small>}
              </span>
            </button>
          )
        })}
      </div>

      <section className="calendar-day-agenda">
        <div className="calendar-agenda-heading"><div><strong>{dateTitle(selectedDate)}</strong><span>{selectedEvents.length} 項行程</span></div></div>
        {!selectedEvents.length && <div className="calendar-agenda-empty"><CalendarDays /><span>這一天沒有安排行程。</span></div>}
        <div className="calendar-agenda-list">
          {selectedEvents.map((event) => (
            <article className={`is-${event.category}${event.isActive ? '' : ' is-inactive'}${calendarEventOfficeClass(event)}`} key={event.id}>
              <div className="calendar-agenda-topline">
                <span className={`calendar-event-category is-${event.category}${calendarEventOfficeClass(event)}`}>{event.sourceOffice || calendarCategoryLabels[event.category]}</span>
                <div className="calendar-event-meta">
                  <span><CalendarDays />{calendarEventDateLabel(event)}</span>
                  <span><Clock3 />{calendarEventTimeLabel(event)}</span>
                  {event.location && <span><MapPin />{event.location}</span>}
                  {event.sourceAudience && <span>{event.sourceAudience}</span>}
                </div>
              </div>
              <div className="calendar-agenda-content"><h3>{calendarEventDisplayTitle(event)}</h3>{event.description && <p>{event.description}</p>}</div>
              {!event.isActive && <strong className="calendar-inactive-label">已下架</strong>}
            </article>
          ))}
        </div>
      </section>
    </section>
  )
}
