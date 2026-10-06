export const ADMISSION_RULE_VERSION = 'yunlin-113-05-16'

export const ADMISSION_MAX_SCORES = Object.freeze({
  preference: 8,
  economic: 1,
  nearby: 5,
  attendance: 5,
  discipline: 5,
  balanced: 9,
  remote: 2,
  rewards: 15,
  competitions: 9,
  fitness: 6,
  diversePerformance: 25,
  exam: 30,
  withoutExam: 60,
  total: 90,
})

export const DISCIPLINE_OPTIONS = Object.freeze({
  none: 5,
  warnings_up_to_2: 1,
  minor_demerit_or_more: 0,
})

export const REMOTE_SCHOOL_OPTIONS = Object.freeze({
  seven_or_less: 2,
  eight_to_twelve: 1,
  other: 0,
})

export const COMPETITION_AWARD_OPTIONS = Object.freeze({
  international: [
    { value: 'first_to_fourth', label: '第 1 至 4 名', score: 7 },
  ],
  national: [
    { value: 'first', label: '第 1 名／特優／冠軍／金牌', score: 7 },
    { value: 'second', label: '第 2 名／優等／亞軍／銀牌', score: 6 },
    { value: 'third', label: '第 3 名／甲等／季軍／銅牌', score: 5 },
    { value: 'fourth_or_selected', label: '第 4 名至入選／佳作', score: 4 },
  ],
  county: [
    { value: 'first', label: '全縣第 1 名', score: 3 },
    { value: 'second', label: '全縣第 2 名', score: 2 },
    { value: 'third', label: '全縣第 3 名', score: 1 },
    { value: 'fourth_to_sixth', label: '全縣第 4、5、6 名', score: 0.5 },
  ],
})

export const TEAM_SCALE_OPTIONS = Object.freeze({
  individual: { label: '個人賽或 3 人以下', multiplier: 1 },
  team_4_19: { label: '團體賽 4 至 19 人', multiplier: 0.5 },
  team_20_plus: { label: '團體賽 20 人以上', multiplier: 0.25 },
})

export const ADMISSION_SEMESTERS = Object.freeze([
  { key: 'grade7_1', label: '七年級上學期' },
  { key: 'grade7_2', label: '七年級下學期' },
  { key: 'grade8_1', label: '八年級上學期' },
  { key: 'grade8_2', label: '八年級下學期' },
  { key: 'grade9_1', label: '九年級上學期' },
])

export const BALANCED_DOMAIN_OPTIONS = Object.freeze([
  { key: 'health', label: '健康與體育' },
  { key: 'arts', label: '藝術' },
  { key: 'integrated', label: '綜合活動' },
  { key: 'technology', label: '科技' },
])

export const FITNESS_STANDARDS = Object.freeze({
  male: {
    13: { curlUps: 17, sitAndReach: 18, standingLongJump: 148, runSeconds: 676, shuttleRun: 32 },
    14: { curlUps: 19, sitAndReach: 18, standingLongJump: 165, runSeconds: 659, shuttleRun: 34 },
    15: { curlUps: 21, sitAndReach: 18, standingLongJump: 175, runSeconds: 619, shuttleRun: 38 },
    16: { curlUps: 22, sitAndReach: 18, standingLongJump: 180, runSeconds: 578, shuttleRun: 40 },
  },
  female: {
    13: { curlUps: 13, sitAndReach: 24, standingLongJump: 120, runSeconds: 316, shuttleRun: 23 },
    14: { curlUps: 12, sitAndReach: 23, standingLongJump: 122, runSeconds: 323, shuttleRun: 23 },
    15: { curlUps: 13, sitAndReach: 25, standingLongJump: 125, runSeconds: 320, shuttleRun: 24 },
    16: { curlUps: 15, sitAndReach: 24, standingLongJump: 127, runSeconds: 311, shuttleRun: 25 },
  },
})

function numberWithin(value, minimum, maximum) {
  const number = Number(value)
  if (!Number.isFinite(number)) return minimum
  return Math.min(maximum, Math.max(minimum, number))
}

function roundScore(value) {
  return Math.round((Number(value) + Number.EPSILON) * 100) / 100
}

function numericOrNull(value) {
  if (value === '' || value === null || value === undefined) return null
  const number = Number(value)
  return Number.isFinite(number) ? number : null
}

export function emptySemesterRecords() {
  return ADMISSION_SEMESTERS.map(({ key }) => ({
    semester: key,
    truancyPeriods: '',
    warningCount: '',
    minorDemeritCount: '',
    majorDemeritCount: '',
    disciplineCleared: false,
  }))
}

export function emptyBalancedScores() {
  return ADMISSION_SEMESTERS.map(({ key }) => ({
    semester: key,
    health: '',
    arts: '',
    integrated: '',
    technology: '',
  }))
}

export function emptyFitnessRecords() {
  return ADMISSION_SEMESTERS.map(({ key }) => ({
    semester: key,
    age: '',
    curlUps: '',
    sitAndReach: '',
    standingLongJump: '',
    cardioType: 'run',
    cardioResult: '',
  }))
}

export function calculateSemesterMetrics(check = {}) {
  const records = Array.isArray(check.semesterRecords) ? check.semesterRecords : []
  const attendanceRecords = records.filter((record) => numericOrNull(record?.truancyPeriods) !== null)
  const disciplineRecords = records.filter((record) => (
    record?.disciplineCleared === true
    || numericOrNull(record?.warningCount) !== null
    || numericOrNull(record?.minorDemeritCount) !== null
    || numericOrNull(record?.majorDemeritCount) !== null
  ))

  const attendance = attendanceRecords.length
    ? Math.min(attendanceRecords.filter((record) => numericOrNull(record.truancyPeriods) === 0).length, 5)
    : numberWithin(check.noTruancySemesters, 0, 5)

  let discipline = DISCIPLINE_OPTIONS[check.disciplineStatus] || 0
  let outstandingWarnings = 0
  let outstandingMinorDemerits = 0
  let outstandingMajorDemerits = 0
  if (disciplineRecords.length) {
    for (const record of disciplineRecords) {
      if (record.disciplineCleared === true) continue
      outstandingWarnings += Math.max(0, numericOrNull(record.warningCount) || 0)
      outstandingMinorDemerits += Math.max(0, numericOrNull(record.minorDemeritCount) || 0)
      outstandingMajorDemerits += Math.max(0, numericOrNull(record.majorDemeritCount) || 0)
    }
    discipline = outstandingMinorDemerits > 0 || outstandingMajorDemerits > 0 || outstandingWarnings >= 3
      ? 0
      : outstandingWarnings > 0
        ? 1
        : 5
  }

  return {
    attendance,
    discipline,
    attendanceSemesterCount: attendanceRecords.length,
    disciplineSemesterCount: disciplineRecords.length,
    outstandingWarnings,
    outstandingMinorDemerits,
    outstandingMajorDemerits,
  }
}

export function calculateBalancedMetrics(check = {}) {
  const records = Array.isArray(check.balancedScores) ? check.balancedScores : []
  const domainResults = BALANCED_DOMAIN_OPTIONS.map((domain) => {
    const values = records
      .map((record) => numericOrNull(record?.[domain.key]))
      .filter((value) => value !== null && value >= 0 && value <= 100)
    const average = values.length
      ? roundScore(values.reduce((sum, value) => sum + value, 0) / values.length)
      : null
    return { ...domain, average, enteredSemesters: values.length, passed: average !== null && average >= 60 }
  })
  const enteredScoreCount = domainResults.reduce((sum, domain) => sum + domain.enteredSemesters, 0)
  const passedDomains = enteredScoreCount
    ? domainResults.filter((domain) => domain.passed).map((domain) => domain.key)
    : Array.isArray(check.balancedDomains) ? [...new Set(check.balancedDomains.filter(Boolean))] : []
  return {
    domainResults,
    passedDomains,
    score: Math.min(passedDomains.length, 3) * 3,
  }
}

export function parseFitnessTime(value) {
  if (value === '' || value === null || value === undefined) return null
  if (typeof value === 'string' && value.includes(':')) {
    const parts = value.trim().split(':')
    if (parts.length !== 2) return null
    const minutes = Number(parts[0])
    const seconds = Number(parts[1])
    if (!Number.isInteger(minutes) || minutes < 0 || !Number.isFinite(seconds) || seconds < 0 || seconds >= 60) return null
    return minutes * 60 + seconds
  }
  const seconds = Number(value)
  return Number.isFinite(seconds) && seconds >= 0 ? seconds : null
}

export function fitnessRecordResult(record, gender) {
  const age = Number(record?.age)
  const standard = FITNESS_STANDARDS[gender]?.[age]
  if (!standard) return { standard: null, passedItems: [] }

  const passedItems = []
  const curlUps = numericOrNull(record.curlUps)
  const sitAndReach = numericOrNull(record.sitAndReach)
  const standingLongJump = numericOrNull(record.standingLongJump)
  const cardioResult = record.cardioType === 'shuttle'
    ? numericOrNull(record.cardioResult)
    : parseFitnessTime(record.cardioResult)

  if (curlUps !== null && curlUps >= standard.curlUps) passedItems.push('muscular')
  if (sitAndReach !== null && sitAndReach >= standard.sitAndReach) passedItems.push('flexibility')
  if (standingLongJump !== null && standingLongJump >= standard.standingLongJump) passedItems.push('power')
  if (cardioResult !== null) {
    if (record.cardioType === 'shuttle' && cardioResult >= standard.shuttleRun) passedItems.push('cardio')
    if (record.cardioType !== 'shuttle' && cardioResult <= standard.runSeconds) passedItems.push('cardio')
  }
  return { standard, passedItems }
}

export function calculateFitnessMetrics(check = {}) {
  const records = Array.isArray(check.fitnessRecords) ? check.fitnessRecords : []
  const hasEnteredResult = records.some((record) => (
    numericOrNull(record?.curlUps) !== null
    || numericOrNull(record?.sitAndReach) !== null
    || numericOrNull(record?.standingLongJump) !== null
    || (record?.cardioType === 'run' ? parseFitnessTime(record?.cardioResult) : numericOrNull(record?.cardioResult)) !== null
  ))
  if (!hasEnteredResult) {
    const legacyItems = Math.min(numberWithin(check.fitnessQualifiedItems, 0, 4), 4)
    return { qualifiedItems: [], qualifiedItemCount: legacyItems, score: Math.min(legacyItems * 3, 6) }
  }

  const qualifiedItems = new Set()
  for (const record of records) {
    const result = fitnessRecordResult(record, check.fitnessGender)
    result.passedItems.forEach((item) => qualifiedItems.add(item))
  }
  return {
    qualifiedItems: [...qualifiedItems],
    qualifiedItemCount: qualifiedItems.size,
    score: Math.min(qualifiedItems.size * 3, 6),
  }
}

export function preferenceScore(order) {
  const value = Number(order)
  if (!Number.isInteger(value) || value < 1 || value > 50) return 0
  if (value <= 10) return 8
  if (value <= 20) return 7
  if (value <= 30) return 6
  if (value <= 40) return 5
  return 4
}

export function competitionBaseScore(tier, awardLevel) {
  return COMPETITION_AWARD_OPTIONS[tier]
    ?.find((option) => option.value === awardLevel)?.score || 0
}

export function competitionEntryScore(entry) {
  if (!entry || entry.reviewStatus === 'pending' || entry.reviewStatus === 'rejected') return 0
  const base = competitionBaseScore(entry.tier, entry.awardLevel)
  const multiplier = TEAM_SCALE_OPTIONS[entry.teamScale]?.multiplier || 0
  return roundScore(base * multiplier)
}

function competitionIdentity(entry) {
  const competition = entry.catalogCode
    || entry.catalogId
    || String(entry.competitionName || entry.customName || '').trim().toLocaleLowerCase('zh-Hant')
  return `${entry.schoolYear || 'unknown'}:${competition}`
}

export function scoredCompetitionEntries(entries = []) {
  const bestByIdentity = new Map()
  for (const entry of entries) {
    const score = competitionEntryScore(entry)
    const identity = competitionIdentity(entry)
    const current = bestByIdentity.get(identity)
    if (!current || score > current.score) bestByIdentity.set(identity, { entry, score })
  }
  return [...bestByIdentity.values()]
}

export function calculateAdmissionScores(check = {}, competitions = []) {
  const preference = preferenceScore(check.preferenceOrder)
  const economic = check.economicWeakness === true ? 1 : 0
  const nearby = check.nearbyEnrollment === true ? 5 : 0
  const semesterMetrics = calculateSemesterMetrics(check)
  const attendance = semesterMetrics.attendance
  const discipline = semesterMetrics.discipline
  const balancedMetrics = calculateBalancedMetrics(check)
  const balanced = balancedMetrics.score
  const remote = REMOTE_SCHOOL_OPTIONS[check.remoteSchoolBand] || 0
  const rewards = Math.min(
    numberWithin(check.majorMerits, 0, 99) * 4.5
      + numberWithin(check.minorMerits, 0, 99) * 1.5
      + numberWithin(check.commendations, 0, 99) * 0.5,
    ADMISSION_MAX_SCORES.rewards,
  )
  const competitionItems = scoredCompetitionEntries(competitions)
  const competitionRaw = competitionItems.reduce((sum, item) => sum + item.score, 0)
  const competition = Math.min(competitionRaw, ADMISSION_MAX_SCORES.competitions)
  const fitnessMetrics = calculateFitnessMetrics(check)
  const fitness = fitnessMetrics.score
  const diversePerformance = Math.min(
    rewards + competition + fitness,
    ADMISSION_MAX_SCORES.diversePerformance,
  )
  const fixed = preference + economic + nearby + attendance + discipline + balanced + remote
  const withoutExam = roundScore(fixed + diversePerformance)

  return {
    preference,
    economic,
    nearby,
    attendance,
    discipline,
    balanced,
    remote,
    rewards: roundScore(rewards),
    competition: roundScore(competition),
    competitionRaw: roundScore(competitionRaw),
    fitness,
    diversePerformance: roundScore(diversePerformance),
    withoutExam,
    totalMaximum: ADMISSION_MAX_SCORES.total,
    withoutExamMaximum: ADMISSION_MAX_SCORES.withoutExam,
    pendingCompetitionCount: competitions.filter((entry) => entry.reviewStatus === 'pending').length,
    rejectedCompetitionCount: competitions.filter((entry) => entry.reviewStatus === 'rejected').length,
    duplicateCompetitionCount: Math.max(0, competitions.length - competitionItems.length),
    semesterMetrics,
    balancedMetrics,
    fitnessMetrics,
  }
}

export function emptyAdmissionCheck() {
  return {
    id: null,
    preferenceOrder: '',
    economicWeakness: null,
    nearbyEnrollment: null,
    noTruancySemesters: 0,
    disciplineStatus: '',
    semesterRecords: emptySemesterRecords(),
    balancedDomains: [],
    balancedScores: emptyBalancedScores(),
    remoteSchoolBand: '',
    majorMerits: 0,
    minorMerits: 0,
    commendations: 0,
    fitnessQualifiedItems: 0,
    fitnessGender: '',
    fitnessRecords: emptyFitnessRecords(),
    reviewStatus: 'self_reported',
    adminNote: '',
    updatedAt: null,
  }
}
