function isCommonAssignment(assignment) {
  return assignment?.targetType === 'common'
}

function isGroupAssignment(assignment, groupCode) {
  return assignment?.targetType === 'group'
    && String(assignment?.targetGroupCode || '').toUpperCase() === groupCode
}

export function buildAssignmentBoardGroups(assignments = []) {
  const rows = Array.isArray(assignments) ? assignments : []

  return {
    A: rows.filter((assignment) => isCommonAssignment(assignment) || isGroupAssignment(assignment, 'A')),
    B: rows.filter((assignment) => isCommonAssignment(assignment) || isGroupAssignment(assignment, 'B')),
  }
}

export function filterCurrentAssignmentBoardItems(assignments = [], now = new Date()) {
  const currentTime = now instanceof Date ? now.getTime() : new Date(now).getTime()
  const currentDate = new Date(currentTime)
  const localToday = new Date(currentDate.getTime() - currentDate.getTimezoneOffset() * 60_000)
    .toISOString()
    .slice(0, 10)

  return (Array.isArray(assignments) ? assignments : []).filter((assignment) => {
    const publishedAt = assignment?.publishedAt ? new Date(assignment.publishedAt) : null
    const publishedDate = publishedAt && Number.isFinite(publishedAt.getTime())
      ? new Date(publishedAt.getTime() - publishedAt.getTimezoneOffset() * 60_000).toISOString().slice(0, 10)
      : assignment?.assignmentDate
    if (!publishedDate || publishedDate > localToday) return false
    if (assignment.isFullySubmitted) return false
    const dueTime = new Date(assignment.dueAt).getTime()
    return Number.isFinite(dueTime) && dueTime >= currentTime
  })
}

function localDateValue(value) {
  const date = value instanceof Date ? value : new Date(value)
  if (!Number.isFinite(date.getTime())) return ''
  return new Date(date.getTime() - date.getTimezoneOffset() * 60_000).toISOString().slice(0, 10)
}

export function previousLocalDateString(now = new Date()) {
  const date = now instanceof Date ? new Date(now.getTime()) : new Date(now)
  if (!Number.isFinite(date.getTime())) return ''
  date.setDate(date.getDate() - 1)
  return localDateValue(date)
}

export function previousSchoolDateString(now = new Date(), holidayEvents = []) {
  const date = now instanceof Date ? new Date(now.getTime()) : new Date(now)
  if (!Number.isFinite(date.getTime())) return ''
  const holidays = Array.isArray(holidayEvents) ? holidayEvents : []

  for (let attempts = 0; attempts < 370; attempts += 1) {
    date.setDate(date.getDate() - 1)
    const dateKey = localDateValue(date)
    const isWeekend = date.getDay() === 0 || date.getDay() === 6
    const isHoliday = holidays.some((event) => (
      event?.category === 'holiday'
      && event?.startsOn <= dateKey
      && event?.endsOn >= dateKey
    ))
    if (!isWeekend && !isHoliday) return dateKey
  }

  return previousLocalDateString(now)
}

export function filterPreviousDayAssignmentBoardItems(
  assignments = [],
  referenceDate = previousLocalDateString(),
  now = new Date(),
) {
  const referenceEndTime = new Date(`${referenceDate}T23:59:59.999`).getTime()

  return (Array.isArray(assignments) ? assignments : []).filter((assignment) => {
    const publishedDate = assignment?.publishedAt
      ? localDateValue(assignment.publishedAt)
      : assignment?.assignmentDate
    if (!publishedDate || publishedDate > referenceDate) return false
    if (assignment.isFullySubmitted) return false
    if (publishedDate === referenceDate) return true

    const dueTime = new Date(assignment?.dueAt).getTime()
    return Number.isFinite(dueTime) && dueTime > referenceEndTime
  })
}
