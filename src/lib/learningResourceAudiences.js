export const learningResourceAudienceOptions = [
  { value: 'common', label: '共同（所有學生）', shortLabel: '共同' },
  { value: 'math_a', label: '數學 A 組', shortLabel: '數學 A 組' },
  { value: 'math_b', label: '數學 B 組', shortLabel: '數學 B 組' },
  { value: 'english_a', label: '英語 A 組', shortLabel: '英語 A 組' },
  { value: 'english_b', label: '英語 B 組', shortLabel: '英語 B 組' },
]

const optionsByValue = Object.fromEntries(
  learningResourceAudienceOptions.map((option) => [option.value, option]),
)

export function isValidLearningResourceAudience(value) {
  return Object.hasOwn(optionsByValue, value)
}

export function normalizeLearningResourceAudience(value) {
  return isValidLearningResourceAudience(value) ? value : 'common'
}

export function learningResourceAudienceLabel(value, { short = false } = {}) {
  const option = optionsByValue[normalizeLearningResourceAudience(value)]
  return short ? option.shortLabel : option.label
}

export function learningResourceAudienceOptionsForSubject(subjectCode) {
  const normalizedSubject = String(subjectCode || '').trim().toLowerCase()
  if (normalizedSubject === 'math') {
    return learningResourceAudienceOptions.filter((option) => (
      option.value === 'common' || option.value.startsWith('math_')
    ))
  }
  if (normalizedSubject === 'english') {
    return learningResourceAudienceOptions.filter((option) => (
      option.value === 'common' || option.value.startsWith('english_')
    ))
  }
  return learningResourceAudienceOptions.slice(0, 1)
}
