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
