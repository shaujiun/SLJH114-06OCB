import { describe, expect, it } from 'vitest'
import {
  learningResourceAudienceLabel,
  learningResourceAudienceOptionsForSubject,
  normalizeLearningResourceAudience,
} from './learningResourceAudiences.js'

describe('學習資源顯示對象', () => {
  it('既有或未知資料安全回復為共同', () => {
    expect(normalizeLearningResourceAudience()).toBe('common')
    expect(normalizeLearningResourceAudience('legacy')).toBe('common')
    expect(learningResourceAudienceLabel('legacy', { short: true })).toBe('共同')
  })

  it('數學只提供共同與數學 A、B 組', () => {
    expect(learningResourceAudienceOptionsForSubject('math').map((item) => item.value)).toEqual([
      'common',
      'math_a',
      'math_b',
    ])
  })

  it('英語只提供共同與英語 A、B 組', () => {
    expect(learningResourceAudienceOptionsForSubject('english').map((item) => item.value)).toEqual([
      'common',
      'english_a',
      'english_b',
    ])
  })

  it('通用及其他科目只能選共同', () => {
    expect(learningResourceAudienceOptionsForSubject('').map((item) => item.value)).toEqual(['common'])
    expect(learningResourceAudienceOptionsForSubject('science').map((item) => item.value)).toEqual(['common'])
  })
})
