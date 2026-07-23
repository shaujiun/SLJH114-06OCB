import { describe, expect, it } from 'vitest'
import {
  buildAutomaticGradeAnalysis,
  calculateSubjectAverages,
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
    expect(() => parseGradeWorkbookRows({ sheets, students })).toThrow('找不到可辨識的段考成績')
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

  it('提供強項、待加強科目與進步提醒', () => {
    const analysis = buildAutomaticGradeAnalysis(results)
    expect(analysis.headline).toContain('自然')
    expect(analysis.messages.join('')).toContain('數學')
    expect(analysis.messages.join('')).toContain('進步')
  })
})
