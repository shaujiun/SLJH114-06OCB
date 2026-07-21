import { describe, expect, it } from 'vitest'
import {
  calendarEventDisplayTitle,
  calendarEventOfficeClass,
  decideAudience,
  inferAcademicYear,
  parseSemesterRows,
  parseTimeRange,
} from './calendarImportService.js'

describe('校務行事曆 Excel 對象判斷', () => {
  it.each([
    '八年級學生',
    '全校學生',
    '七八年級學生',
    '七、八年級學生',
    '八九年級學生',
    '全校師生',
    '各班',
    '國一國二',
  ])('八年級匯入會預選「%s」', (audience) => {
    expect(decideAudience(audience, 8).decision).toBe('include')
  })

  it('其他年級與教師活動預設排除，空白資料留待確認', () => {
    expect(decideAudience('九年級學生', 8).decision).toBe('exclude')
    expect(decideAudience('全校教師', 8).decision).toBe('exclude')
    expect(decideAudience('', 8).decision).toBe('review')
    expect(decideAudience('參與學生', 8).decision).toBe('review')
  })
})

describe('校務行事曆 Excel 解析', () => {
  it('可從檔名判斷民國學年度', () => {
    expect(inferAcademicYear('114學年石榴國中校務活動行事曆.xlsx')).toBe(114)
  })

  it('可辨識半形與全形時間區間', () => {
    expect(parseTimeRange('08:00-12:00')).toEqual({ startTime: '08:00', endTime: '12:00' })
    expect(parseTimeRange('7：50～8：35')).toEqual({ startTime: '07:50', endTime: '08:35' })
    expect(parseTimeRange('第6~8節')).toBeNull()
  })

  it('Excel 單一時間儲存格會保留為簡短時間文字', () => {
    const rows = [
      ['標題'],
      ['週', '月', '日', '星期', '處室', '活動名稱', '對象', '時間(24H)', '地點'],
      [1, 8, 1, '五', '教務處', '晚間活動', '八年級學生', new Date(1899, 11, 30, 20, 0), null],
    ]
    const [parsed] = parseSemesterRows(rows, { sheetName: '第一學期', academicYear: 114, grade: 8 })
    expect(parsed.description).toBe('原行事曆時間：20:00')
  })

  it('同日期後續活動會沿用月份與日期，跨年月份會換算西元年', () => {
    const rows = [
      ['標題'],
      ['週', '月', '日', '星期', '處室', '活動名稱', '對象', '時間(24H)', '地點'],
      [1, 12, 1, '一', '教務處', '閱讀活動', '八年級學生', '08:00-09:00', '共讀站'],
      [null, null, null, null, '學務處', '宣導活動', '全校學生', '依課表', '活動中心'],
      [2, 1, 5, '一', '全校活動', '返校日', '全校師生', null, null],
    ]
    const parsed = parseSemesterRows(rows, { sheetName: '第二學期', academicYear: 114, grade: 8 })
    expect(parsed).toHaveLength(3)
    expect(parsed[0]).toMatchObject({ startsOn: '2025-12-01', isAllDay: false, selected: true })
    expect(parsed[1]).toMatchObject({ startsOn: '2025-12-01', isAllDay: true, description: '原行事曆時間：依課表' })
    expect(parsed[2].startsOn).toBe('2026-01-05')
  })

  it('第三學期延伸到 7 月時仍屬於學年度結束年', () => {
    const rows = [
      ['標題'],
      ['週', '月', '日', '星期', '處室', '活動名稱', '對象', '時間(24H)', '地點'],
      [1, 7, 22, '三', '教務處', '補考', '全校學生', null, null],
    ]
    const [parsed] = parseSemesterRows(rows, { sheetName: '第三學期', academicYear: 114, grade: 8 })
    expect(parsed.startsOn).toBe('2026-07-22')
  })

  it('處室會產生顯示標記與顏色類別', () => {
    const event = { title: '第一次段考', sourceOffice: '教務處' }
    expect(calendarEventDisplayTitle(event)).toBe('【教】第一次段考')
    expect(calendarEventOfficeClass(event)).toBe(' office-academic')
  })
})
