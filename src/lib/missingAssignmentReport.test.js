import { describe, expect, it } from 'vitest'
import { filterMissingStudentRows, renderMissingAssignmentPrintHtml } from './missingAssignmentReport.js'

const students = [
  {
    seatNumber: 2, missingCount: 2,
    assignments: [
      { id: 'a', assignmentDate: '2026-09-19', subjectName: '數學', content: '習作 1' },
      { id: 'c', assignmentDate: '2026-09-23', subjectName: '自然', content: '講義' },
    ],
  },
  {
    seatNumber: 7, missingCount: 2,
    assignments: [
      { id: 'a', assignmentDate: '2026-09-19', subjectName: '數學', content: '習作 1' },
      { id: 'b', assignmentDate: '2026-09-21', subjectName: '英文', content: '單字 2' },
    ],
  },
]

describe('缺交名單篩選與列印', () => {
  it('日期起迄包含邊界；座號只留下該學生在日期內的缺交作業', () => {
    expect(filterMissingStudentRows(students, {
      startDate: '2026-09-19', endDate: '2026-09-21', seatNumber: '7',
    })).toEqual([students[1]])
    expect(filterMissingStudentRows(students, {
      startDate: '2026-09-19', endDate: '2026-09-21', seatNumber: '2',
    })).toEqual([{ ...students[0], assignments: [students[0].assignments[0]], missingCount: 1 }])
  })

  it('日期與座號留空時保留完整名單，不符合條件的學生不出現', () => {
    expect(filterMissingStudentRows(students)).toEqual(students)
    expect(filterMissingStudentRows(students, { seatNumber: '9' })).toEqual([])
  })

  it('列印檔只包含篩選結果，並將作業文字安全轉義', () => {
    const filtered = filterMissingStudentRows(students, { seatNumber: '7', startDate: '2026-09-19', endDate: '2026-09-19' })
      .map((student) => ({ ...student, assignments: student.assignments.map((assignment) => ({ ...assignment, content: '<script>alert("x")</script>' })) }))
    const html = renderMissingAssignmentPrintHtml({
      students: filtered, termLabel: '第 1 學期',
      startDate: '2026-09-19', endDate: '2026-09-19', seatNumber: '7', printedAt: '2026/9/22 12:00',
    })
    expect(html).toContain('作業日期：2026-09-19 ～ 2026-09-19')
    expect(html).toContain('座號：7 號')
    expect(html).toContain('共 1 位學生、1 筆缺交')
    expect(html).toContain('&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;')
    expect(html).not.toContain('<script>')
    expect(html).not.toContain('單字 2')
    expect(html).not.toContain('自然')
  })

  it('無缺交時也可產生載明篩選條件的列印頁', () => {
    const html = renderMissingAssignmentPrintHtml({ students: [], termLabel: '第 1 學期', printedAt: '現在' })
    expect(html).toContain('此篩選條件沒有缺交紀錄')
    expect(html).toContain('全部日期')
  })
})
