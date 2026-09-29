const monthDayFormatter = new Intl.DateTimeFormat('en-US', {
  timeZone: 'Asia/Taipei',
  month: 'numeric',
  day: 'numeric',
})

export function formatAssignmentDueMonthDay(value) {
  const date = new Date(value)
  if (!Number.isFinite(date.getTime())) return ''
  const parts = Object.fromEntries(
    monthDayFormatter.formatToParts(date).map((part) => [part.type, part.value]),
  )
  return `${parts.month}/${parts.day}`
}

export function isPastAssignmentDue(value, referenceTime = new Date()) {
  const dueTime = new Date(value).getTime()
  const currentTime = referenceTime instanceof Date
    ? referenceTime.getTime()
    : new Date(referenceTime).getTime()
  return Number.isFinite(dueTime) && Number.isFinite(currentTime) && dueTime < currentTime
}

export function isAssignmentOverdue(assignment, referenceTime = new Date()) {
  const hasPendingStudents = Boolean(
    assignment?.outstandingSeatNumbers?.length
    || assignment?.pendingStudents?.length
    || Number(assignment?.pendingRecipientCount) > 0,
  )
  return hasPendingStudents && isPastAssignmentDue(assignment?.dueAt, referenceTime)
}
