import { useMemo, useState } from 'react'
import { CheckSquare, FileSpreadsheet, Upload, X } from 'lucide-react'
import {
  calendarOfficeMeta,
  importCalendarEvents,
  inferAcademicYear,
  parseCalendarWorkbook,
} from '../services/calendarImportService.js'

const decisionLabels = {
  include: '建議匯入',
  review: '待確認',
  exclude: '建議排除',
}

export default function CalendarImportPanel({ classId, onImported, onNotice }) {
  const [file, setFile] = useState(null)
  const [academicYear, setAcademicYear] = useState(114)
  const [grade, setGrade] = useState(8)
  const [rows, setRows] = useState([])
  const [filter, setFilter] = useState('all')
  const [analyzing, setAnalyzing] = useState(false)
  const [importing, setImporting] = useState(false)

  const selectedCount = rows.filter((row) => row.selected).length
  const visibleRows = useMemo(() => rows.filter((row) => {
    if (filter === 'selected') return row.selected
    if (filter === 'review') return row.decision === 'review'
    if (filter === 'include') return row.decision === 'include'
    if (filter === 'exclude') return row.decision === 'exclude'
    return true
  }), [filter, rows])

  const counts = useMemo(() => rows.reduce((result, row) => {
    result[row.decision] += 1
    return result
  }, { include: 0, review: 0, exclude: 0 }), [rows])

  function chooseFile(event) {
    const nextFile = event.target.files?.[0] || null
    setFile(nextFile)
    setRows([])
    if (nextFile) setAcademicYear(inferAcademicYear(nextFile.name, academicYear))
  }

  async function analyze() {
    if (!file) {
      onNotice('error', '請先選擇 Excel 檔案。')
      return
    }
    setAnalyzing(true)
    try {
      const parsed = await parseCalendarWorkbook(file, { academicYear: Number(academicYear), grade: Number(grade) })
      setRows(parsed)
      setFilter('all')
      onNotice('success', `已分析 ${parsed.length} 筆活動，請確認勾選內容後再匯入。`)
    } catch (error) {
      setRows([])
      onNotice('error', error.message)
    } finally {
      setAnalyzing(false)
    }
  }

  function toggleRow(importId) {
    setRows((current) => current.map((row) => row.importId === importId ? { ...row, selected: !row.selected } : row))
  }

  function setVisibleSelection(selected) {
    const visibleIds = new Set(visibleRows.map((row) => row.importId))
    setRows((current) => current.map((row) => visibleIds.has(row.importId) ? { ...row, selected } : row))
  }

  function restoreSuggestions() {
    setRows((current) => current.map((row) => ({ ...row, selected: row.decision === 'include' })))
  }

  async function submitImport() {
    const selectedRows = rows.filter((row) => row.selected)
    if (!selectedRows.length) {
      onNotice('error', '請至少勾選一筆要匯入的活動。')
      return
    }
    if (!window.confirm(`確定將選取的 ${selectedRows.length} 筆活動匯入班級行事曆嗎？`)) return
    setImporting(true)
    try {
      const result = await importCalendarEvents({ classId, sourceFileName: file.name, events: selectedRows })
      const firstDate = selectedRows.map((row) => row.startsOn).sort()[0]
      await onImported(firstDate)
      onNotice('success', `匯入完成：新增 ${result.importedCount || 0} 筆，略過重複 ${result.skippedCount || 0} 筆。`)
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setImporting(false)
    }
  }

  return (
    <section className="calendar-import-panel">
      <div className="student-panel-title">
        <span><FileSpreadsheet /></span>
        <div><h3>從 Excel 匯入校務活動</h3><p>只讀取學期工作表，先預覽並篩選對象，不會直接寫入行事曆。</p></div>
      </div>

      <div className="calendar-import-controls">
        <label className="calendar-file-picker">
          <span>Excel 檔案（.xlsx）</span>
          <input type="file" accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" onChange={chooseFile} />
        </label>
        <label><span>民國學年度</span><input type="number" min="100" max="999" value={academicYear} onChange={(event) => { setAcademicYear(event.target.value); setRows([]) }} /></label>
        <label><span>要匯入的年級</span><select value={grade} onChange={(event) => { setGrade(Number(event.target.value)); setRows([]) }}><option value="7">七年級</option><option value="8">八年級</option><option value="9">九年級</option></select></label>
        <button className="secondary-button" type="button" disabled={!file || analyzing || importing} onClick={analyze}><Upload />{analyzing ? '分析中…' : '分析 Excel'}</button>
      </div>

      {file && <p className="calendar-import-file-name">目前檔案：{file.name}</p>}

      {!!rows.length && (
        <>
          <div className="calendar-import-summary">
            <button className={filter === 'all' ? 'is-active' : ''} type="button" onClick={() => setFilter('all')}>全部 {rows.length}</button>
            <button className={filter === 'include' ? 'is-active' : ''} type="button" onClick={() => setFilter('include')}>建議匯入 {counts.include}</button>
            <button className={filter === 'review' ? 'is-active' : ''} type="button" onClick={() => setFilter('review')}>待確認 {counts.review}</button>
            <button className={filter === 'exclude' ? 'is-active' : ''} type="button" onClick={() => setFilter('exclude')}>建議排除 {counts.exclude}</button>
            <button className={filter === 'selected' ? 'is-active' : ''} type="button" onClick={() => setFilter('selected')}>已勾選 {selectedCount}</button>
          </div>

          <div className="calendar-import-actions">
            <button type="button" onClick={() => setVisibleSelection(true)}><CheckSquare />勾選目前結果</button>
            <button type="button" onClick={() => setVisibleSelection(false)}><X />取消目前結果</button>
            <button type="button" onClick={restoreSuggestions}>恢復系統建議</button>
          </div>

          <div className="calendar-import-table-wrap">
            <table className="calendar-import-table">
              <thead><tr><th>匯入</th><th>日期</th><th>處室／活動</th><th>對象</th><th>系統判斷</th><th>時間／地點</th><th>來源</th></tr></thead>
              <tbody>
                {visibleRows.map((row) => {
                  const office = calendarOfficeMeta(row.sourceOffice)
                  return (
                    <tr className={`is-${row.decision}${row.selected ? ' is-selected' : ''}`} key={row.importId}>
                      <td><input type="checkbox" checked={row.selected} aria-label={`匯入 ${row.title}`} onChange={() => toggleRow(row.importId)} /></td>
                      <td>{row.startsOn === row.endsOn ? row.startsOn : <>{row.startsOn}<br />～{row.endsOn}</>}</td>
                      <td><strong className={`calendar-import-office office-${office.style || 'none'}`}>{office.prefix || '【未填】'}{row.sourceOffice || '未填處室'}</strong><span>{row.title}</span></td>
                      <td>{row.sourceAudience || <em>空白</em>}</td>
                      <td><strong>{decisionLabels[row.decision]}</strong><span>{row.decisionReason}</span></td>
                      <td>{row.isAllDay ? (row.description.replace('原行事曆時間：', '') || '全天') : `${row.startTime}－${row.endTime}`}{row.location && <><br />{row.location}</>}</td>
                      <td>{row.sourceSheet}<br />第 {row.sourceRow} 列</td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>

          <div className="calendar-import-submit">
            <p>將匯入 <strong>{selectedCount}</strong> 筆；重複資料會自動略過。</p>
            <button className="approve-button" type="button" disabled={!selectedCount || importing} onClick={submitImport}><Upload />{importing ? '匯入中…' : `確認匯入 ${selectedCount} 筆`}</button>
          </div>
        </>
      )}
    </section>
  )
}
