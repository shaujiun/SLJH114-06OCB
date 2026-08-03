import { describe, expect, it } from 'vitest'
import {
  buildAutomaticGradeAnalysis,
  buildGradeTrendSeries,
  buildLongTermGradeProgress,
  calculateSubjectAverages,
  compareGradeExams,
  parseGradeWorkbookRows,
} from './gradeService.js'

const students = [
  { id: 'student-1', studentId: '114098', seatNumber: 1, fullName: '余承澤' },
  { id: 'student-2', studentId: '114099', seatNumber: 2, fullName: '何字杰' },
]

describe('成績 Excel 解析', () => {
  it('從歷次平均工作表辨識六次七科成績', () => {
    const sheets = new Map([['各次段考平均', [
      [null, '座號', '姓名', '國文1', '國文2', '國文3', '國文4', '國文5', '國文6', '國平', '英語1', '英語2', '英語3', '英語4', '英語5', '英語6'],
      [null, 1, '余承澤', 84, 86, 91, 89, 95, 83, 88, 83, 86, 80, 70, 77, 87],
    ]]])
    const parsed = parseGradeWorkbookRows({ sheets, students })
    expect(parsed.exams.map((exam) => exam.key)).toEqual([
      'g7-s1-e1', 'g7-s1-e2', 'g7-s2-e1', 'g7-s2-e2', 'g7-s3-e1', 'g7-s3-e2',
    ])
    expect(parsed.exams[0].rows[0]).toMatchObject({ chineseScore: 84, englishScore: 83, compositionScore: null })
  })

  it('依選擇的入學學年度建立考試學年度', () => {
    const sheets = new Map([['各次段考平均', [
      [null, '座號', '姓名', '國文1'],
      [null, 1, '余承澤', 84],
    ]]])
    const parsed = parseGradeWorkbookRows({ sheets, students, cohortStartSchoolYear: 115 })
    expect(parsed.exams[0].schoolYear).toBe(115)
  })

  it('完整成績表會補上作文、加權總分與排名', () => {
    const sheets = new Map([
      ['各次段考平均', [
        [null, '座號', '姓名', '國文1', '國文2', '英語1', '英語2', '數學1', '數學2', '自然1', '自然2', '歷史1', '歷史2', '地理1', '地理2', '公民1', '公民2'],
        [null, 1, '余承澤', 84, 86, 83, 86, 80, 93, 78, 90, 76, 70, 74, 80, 90, 92],
      ]],
      ['114-1二段', [
        [null, '座號', '姓名', '國文', '國排名', '作文', '作排名', '英語', '英排名', '英聽', '聽排名', '英總', '數學', '數排名', '自然', '自排名', '歷史', '歷排名', '地理', '地排名', '公民', '公排名', '總分', '班排名', '校排名'],
        [null, 1, '余承澤', 86, 3, 8, 3, 66, 3, 20, 1, 86, 93, 1, 90, 1, 70, 8, 80, 4, 92, 2, 1572, 1, 10],
      ]],
    ])
    const parsed = parseGradeWorkbookRows({ sheets, students })
    const result = parsed.exams.find((exam) => exam.key === 'g7-s1-e2').rows[0]
    expect(result).toMatchObject({
      compositionScore: 8,
      englishWrittenScore: 66,
      englishListeningScore: 20,
      englishScore: 86,
      totalScore: 597,
      weightedTotalScore: 1572,
      classRank: 1,
      schoolRank: 10,
    })
  })

  it('未建立的學生會留在預覽錯誤，不會形成可匯入資料', () => {
    const sheets = new Map([['114-3二段', [
      [null, '座號', '姓名', '國文'],
      [null, 20, '尚未建立學生', 80],
    ]]])
    const parsed = parseGradeWorkbookRows({ sheets, students })
    expect(parsed.exams).toHaveLength(0)
    expect(parsed.unmatched).toEqual([expect.objectContaining({ seatNumber: 20, fullName: '尚未建立學生' })])
  })

  it('略過只有公式零值與排名的空白成績範本', () => {
    const sheets = new Map([['114-1二段', [
      [null, '座號', '姓名', '國文', '作文', '英語', '英聽', '英總', '數學', '自然', '歷史', '地理', '公民', '總分', '班排名'],
      [null, 1, '余承澤', null, null, null, null, 0, null, null, null, null, null, 0, 1],
    ]]])
    expect(() => parseGradeWorkbookRows({ sheets, students })).toThrow('找不到可辨識的段考或模擬考成績')
  })

  it('辨識常見模擬考工作表名稱並匯入成績', () => {
    const sheets = new Map([['第 1 次模擬考', [
      [null, '座號', '姓名', '國文', '英語', '數學', '自然', '歷史', '地理', '公民', '加權總分', '班排', '校排'],
      [null, 1, '余承澤', 82, 79, 88, 76, 80, 85, 83, 1375, 3, 48],
    ]]])
    const parsed = parseGradeWorkbookRows({ sheets, students })
    expect(parsed.exams).toHaveLength(1)
    expect(parsed.exams[0]).toMatchObject({ key: 'mock-1', examType: 'mock', label: '第一次模擬考', schoolYear: 116 })
    expect(parsed.exams[0].rows[0]).toMatchObject({ mathScore: 88, classRank: 3, schoolRank: 48 })
  })
})

describe('個人成績分析', () => {
  const results = [
    { chineseScore: 70, englishScore: 60, mathScore: 50, scienceScore: 80, historyScore: 75, geographyScore: 72, civicsScore: 78 },
    { chineseScore: 75, englishScore: 68, mathScore: 62, scienceScore: 82, historyScore: 77, geographyScore: 74, civicsScore: 80 },
  ]

  it('計算七科歷次平均', () => {
    expect(calculateSubjectAverages(results)).toContainEqual(expect.objectContaining({ key: 'mathScore', average: 56 }))
  })

  it('缺考不以零分納入平均', () => {
    const withAbsence = [...results, { chineseScore: null }]
    expect(calculateSubjectAverages(withAbsence)).toContainEqual(expect.objectContaining({ key: 'chineseScore', average: 72.5, count: 2 }))
  })

  it('建立七科歷次折線資料並保留缺考空值', () => {
    const trendResults = [
      { examId: 'exam-1', exam: { label: '七-1 一段' }, chineseScore: 70, englishScore: null },
      { examId: 'exam-2', exam: { label: '七-1 二段' }, chineseScore: 80, englishScore: 75 },
    ]
    const series = buildGradeTrendSeries(trendResults)
    expect(series).toHaveLength(7)
    expect(series[0]).toMatchObject({
      key: 'chineseScore',
      points: [
        { examId: 'exam-1', examLabel: '七-1 一段', value: 70 },
        { examId: 'exam-2', examLabel: '七-1 二段', value: 80 },
      ],
    })
    expect(series[1].points[0].value).toBeNull()
  })

  it('提供強項、待加強科目與進步提醒', () => {
    const analysis = buildAutomaticGradeAnalysis(results)
    expect(analysis.headline).toContain('自然')
    expect(analysis.messages.join('')).toContain('數學')
    expect(analysis.messages.join('')).toContain('進步')
    expect(analysis.messages).toHaveLength(4)
  })

  it('依成績內容提供三至五點分析', () => {
    const withDecline = [
      results[0],
      { ...results[1], englishScore: 52 },
    ]
    const analysis = buildAutomaticGradeAnalysis(withDecline)
    expect(analysis.messages.length).toBeGreaterThanOrEqual(3)
    expect(analysis.messages.length).toBeLessThanOrEqual(5)
    expect(analysis.messages).toHaveLength(5)
    expect(analysis.messages.join('')).toContain('本次比上一次少')
  })
})

describe('成績交叉比較與長期趨勢', () => {
  const termResult = {
    examId: 'term-1',
    exam: { label: '八-1 一段', examType: 'term', sortOrder: 7 },
    chineseScore: 70,
    englishScore: 65,
    mathScore: 60,
    scienceScore: 75,
    historyScore: 80,
    geographyScore: 72,
    civicsScore: 78,
    totalScore: 500,
    weightedTotalScore: 1250,
    classRank: 12,
    schoolRank: null,
  }
  const mockResult = {
    examId: 'mock-1',
    exam: { label: '第一次模擬考', examType: 'mock', sortOrder: 101 },
    chineseScore: 76,
    englishScore: 62,
    mathScore: 70,
    scienceScore: 75,
    historyScore: null,
    geographyScore: 80,
    civicsScore: 82,
    totalScore: null,
    weightedTotalScore: 1310,
    classRank: 8,
    schoolRank: 56,
  }

  it('逐科計算模擬考減段考的分數差距，缺考不比較', () => {
    const comparison = compareGradeExams(termResult, mockResult)
    expect(comparison.subjects.find((subject) => subject.key === 'chineseScore')).toMatchObject({ difference: 6 })
    expect(comparison.subjects.find((subject) => subject.key === 'englishScore')).toMatchObject({ difference: -3 })
    expect(comparison.subjects.find((subject) => subject.key === 'historyScore')).toMatchObject({ difference: null })
    expect(comparison.scoreSummaries.find((item) => item.key === 'weightedTotalScore')).toMatchObject({ difference: 60 })
    expect(comparison.ranks.find((item) => item.key === 'classRank')).toMatchObject({ improvement: 4 })
    expect(comparison.ranks.find((item) => item.key === 'schoolRank')).toMatchObject({ improvement: null })
  })

  it('整理各科最初、最近、最佳與長期進退步幅度', () => {
    const progress = buildLongTermGradeProgress([termResult, mockResult])
    expect(progress.subjects.find((subject) => subject.key === 'mathScore')).toMatchObject({
      average: 65,
      totalChange: 10,
      recentChange: 10,
      best: expect.objectContaining({ value: 70 }),
    })
    expect(progress.subjects.find((subject) => subject.key === 'historyScore')).toMatchObject({
      totalChange: null,
      recentChange: null,
    })
  })

  it('排名數字下降時判定為名次進步，並略過尚未提供的校排', () => {
    const progress = buildLongTermGradeProgress([termResult, mockResult])
    expect(progress.ranks.find((rank) => rank.key === 'classRank')).toMatchObject({
      totalImprovement: 4,
      recentImprovement: 4,
      best: expect.objectContaining({ value: 8 }),
    })
    expect(progress.ranks.find((rank) => rank.key === 'schoolRank')).toMatchObject({
      totalImprovement: null,
      recentImprovement: null,
      first: expect.objectContaining({ value: 56 }),
    })
  })
})
