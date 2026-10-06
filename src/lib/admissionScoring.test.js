import { describe, expect, it } from 'vitest'
import {
  calculateBalancedMetrics,
  calculateFitnessMetrics,
  calculateAdmissionScores,
  calculateSemesterMetrics,
  competitionEntryScore,
  fitnessRecordResult,
  parseFitnessTime,
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

  it('依各學期曠課與未銷過紀錄計算出缺席及無記過積分', () => {
    const metrics = calculateSemesterMetrics({
      semesterRecords: [
        { truancyPeriods: 0, warningCount: 1, minorDemeritCount: 0, majorDemeritCount: 0, disciplineCleared: false },
        { truancyPeriods: 2, warningCount: 2, minorDemeritCount: 1, majorDemeritCount: 0, disciplineCleared: true },
        { truancyPeriods: 0, warningCount: 0, minorDemeritCount: 0, majorDemeritCount: 0, disciplineCleared: false },
      ],
    })
    expect(metrics.attendance).toBe(2)
    expect(metrics.outstandingWarnings).toBe(1)
    expect(metrics.outstandingMinorDemerits).toBe(0)
    expect(metrics.discipline).toBe(1)
  })

  it('已銷過的記過紀錄不列入目前累積紀錄', () => {
    const metrics = calculateSemesterMetrics({
      semesterRecords: [
        { truancyPeriods: 0, warningCount: 3, minorDemeritCount: 1, majorDemeritCount: 0, disciplineCleared: true },
      ],
    })
    expect(metrics.outstandingWarnings).toBe(0)
    expect(metrics.outstandingMinorDemerits).toBe(0)
    expect(metrics.discipline).toBe(5)
  })

  it('均衡學習依目前已輸入學期平均判斷，每領域 3 分且上限 9 分', () => {
    const metrics = calculateBalancedMetrics({
      balancedScores: [
        { health: 60, arts: 59, integrated: 80, technology: 100 },
        { health: 70, arts: 61, integrated: 40, technology: 100 },
        { health: '', arts: 60, integrated: '', technology: '' },
      ],
    })
    expect(metrics.domainResults.find((item) => item.key === 'health').average).toBe(65)
    expect(metrics.domainResults.find((item) => item.key === 'arts').average).toBe(60)
    expect(metrics.domainResults.find((item) => item.key === 'integrated').average).toBe(60)
    expect(metrics.passedDomains).toEqual(['health', 'arts', 'integrated', 'technology'])
    expect(metrics.score).toBe(9)
  })

  it('體適能依性別、年齡及數值方向判斷，跑步時間須小於等於門檻', () => {
    expect(parseFitnessTime('11:16')).toBe(676)
    expect(parseFitnessTime('5:23')).toBe(323)
    expect(fitnessRecordResult({
      age: 13,
      curlUps: 17,
      sitAndReach: 17,
      standingLongJump: 148,
      cardioType: 'run',
      cardioResult: '11:16',
    }, 'male').passedItems).toEqual(['muscular', 'power', 'cardio'])
    expect(fitnessRecordResult({
      age: 14,
      curlUps: 11,
      sitAndReach: 23,
      standingLongJump: 121,
      cardioType: 'run',
      cardioResult: '5:24',
    }, 'female').passedItems).toEqual(['flexibility'])
  })

  it('體適能跨學期同一項只算一次，任兩項通過即達 6 分上限', () => {
    const metrics = calculateFitnessMetrics({
      fitnessGender: 'female',
      fitnessRecords: [
        { age: 13, curlUps: 13, cardioType: 'run', cardioResult: '' },
        { age: 14, curlUps: 12, sitAndReach: 23, cardioType: 'run', cardioResult: '' },
      ],
    })
    expect(metrics.qualifiedItems.sort()).toEqual(['flexibility', 'muscular'])
    expect(metrics.qualifiedItemCount).toBe(2)
    expect(metrics.score).toBe(6)
  })
})
