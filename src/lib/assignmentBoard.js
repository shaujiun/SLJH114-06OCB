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
