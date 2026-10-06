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

function numberWithin(value, minimum, maximum) {
  const number = Number(value)
  if (!Number.isFinite(number)) return minimum
  return Math.min(maximum, Math.max(minimum, number))
}

function roundScore(value) {
  return Math.round((Number(value) + Number.EPSILON) * 100) / 100
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
  const attendance = numberWithin(check.noTruancySemesters, 0, 5)
  const discipline = DISCIPLINE_OPTIONS[check.disciplineStatus] || 0
  const balancedDomains = Array.isArray(check.balancedDomains)
    ? new Set(check.balancedDomains.filter(Boolean)).size
    : 0
  const balanced = Math.min(balancedDomains, 3) * 3
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
  const fitness = Math.min(
    numberWithin(check.fitnessQualifiedItems, 0, 4) * 3,
    ADMISSION_MAX_SCORES.fitness,
  )
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
    balancedDomains: [],
    remoteSchoolBand: '',
    majorMerits: 0,
    minorMerits: 0,
    commendations: 0,
    fitnessQualifiedItems: 0,
    reviewStatus: 'self_reported',
    adminNote: '',
    updatedAt: null,
  }
}
