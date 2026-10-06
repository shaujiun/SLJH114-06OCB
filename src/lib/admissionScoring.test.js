import { describe, expect, it } from 'vitest'
import {
  calculateAdmissionScores,
  competitionEntryScore,
  preferenceScore,
  scoredCompetitionEntries,
} from './admissionScoring.js'

describe('雲林區超額比序計分', () => {
  it('依志願序區間給 8 至 4 分', () => {
    expect([1, 10, 11, 20, 21, 30, 31, 40, 41, 50].map(preferenceScore))
      .toEqual([8, 8, 7, 7, 6, 6, 5, 5, 4, 4])
    expect(preferenceScore(0)).toBe(0)
    expect(preferenceScore(51)).toBe(0)
  })

  it('依團體人數折算競賽成績', () => {
    expect(competitionEntryScore({ tier: 'national', awardLevel: 'first', teamScale: 'individual', reviewStatus: 'listed' })).toBe(7)
    expect(competitionEntryScore({ tier: 'national', awardLevel: 'second', teamScale: 'team_4_19', reviewStatus: 'approved' })).toBe(3)
    expect(competitionEntryScore({ tier: 'county', awardLevel: 'first', teamScale: 'team_20_plus', reviewStatus: 'listed' })).toBe(0.75)
    expect(competitionEntryScore({ tier: 'national', awardLevel: 'first', teamScale: 'individual', reviewStatus: 'pending' })).toBe(0)
  })

  it('同學年度同一競賽只採最高一次', () => {
    const scored = scoredCompetitionEntries([
      { schoolYear: 114, catalogCode: 'national-01', tier: 'national', awardLevel: 'third', teamScale: 'individual', reviewStatus: 'listed' },
      { schoolYear: 114, catalogCode: 'national-01', tier: 'national', awardLevel: 'first', teamScale: 'team_4_19', reviewStatus: 'listed' },
      { schoolYear: 115, catalogCode: 'national-01', tier: 'national', awardLevel: 'first', teamScale: 'individual', reviewStatus: 'listed' },
    ])
    expect(scored.map((item) => item.score)).toEqual([5, 7])
  })

  it('競賽最高 9 分，多元表現合計最高 25 分，不含會考最高 60 分', () => {
    const scores = calculateAdmissionScores({
      preferenceOrder: 1,
      economicWeakness: true,
      nearbyEnrollment: true,
      noTruancySemesters: 5,
      disciplineStatus: 'none',
      balancedDomains: ['health', 'arts', 'integrated'],
      remoteSchoolBand: 'seven_or_less',
      majorMerits: 4,
      minorMerits: 0,
      commendations: 0,
      fitnessQualifiedItems: 2,
    }, [
      { schoolYear: 114, catalogCode: 'national-01', tier: 'national', awardLevel: 'first', teamScale: 'individual', reviewStatus: 'listed' },
      { schoolYear: 115, catalogCode: 'national-02', tier: 'national', awardLevel: 'first', teamScale: 'individual', reviewStatus: 'listed' },
    ])

    expect(scores.competition).toBe(9)
    expect(scores.rewards).toBe(15)
    expect(scores.fitness).toBe(6)
    expect(scores.diversePerformance).toBe(25)
    expect(scores.withoutExam).toBe(60)
  })
})
