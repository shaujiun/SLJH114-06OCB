import { useCallback, useEffect, useMemo, useState } from 'react'
import { Eye, EyeOff, FileSpreadsheet, RefreshCw, Upload, Users } from 'lucide-react'
import {
  importGradeWorkbook,
  loadAdminGradeOverview,
  loadAdminGradeResults,
  parseGradeWorkbook,
  setGradeExamPublished,
} from '../services/gradeService.js'

function scoreText(value, missing = '—') {
  return value === null || value === undefined || value === '' ? missing : Number(value).toLocaleString('zh-TW')
}

export default function GradeManagement({ dashboard, onNotice }) {
  const defaultCohortYear = dashboard.academicYear.schoolYear - Math.max(0, dashboard.classInfo.gradeLevel - 7)
  const [overview, setOverview] = useState(null)
  const [selectedExamId, setSelectedExamId] = useState('')
  const [results, setResults] = useState([])
  const [cohortStartSchoolYear, setCohortStartSchoolYear] = useState(defaultCohortYear)
  const [file, setFile] = useState(null)
  const [fileInputKey, setFileInputKey] = useState(0)
  const [preview, setPreview] = useState(null)
  const [loading, setLoading] = useState(true)
  const [loadingResults, setLoadingResults] = useState(false)
  const [parsing, setParsing] = useState(false)
  const [importing, setImporting] = useState(false)
  const [publishing, setPublishing] = useState(false)

  const loadOverview = useCallback(async ({ keepSelection = true } = {}) => {
    setLoading(true)
    try {
      const data = await loadAdminGradeOverview({ classId: dashboard.classInfo.id })
      setOverview(data)
      setSelectedExamId((current) => (
        keepSelection && data.exams.some((exam) => exam.id === current)
          ? current
          : data.exams.at(-1)?.id || ''
      ))
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setLoading(false)
    }
  }, [dashboard.classInfo.id, onNotice])

  useEffect(() => { loadOverview() }, [loadOverview])

  useEffect(() => {
    let active = true
    async function loadResults() {
      if (!selectedExamId) {
        setResults([])
        return
      }
      setLoadingResults(true)
      try {
        const data = await loadAdminGradeResults({ examId: selectedExamId })
        if (active) setResults(data)
      } catch (error) {
        if (active) onNotice('error', error.message)
      } finally {
        if (active) setLoadingResults(false)
      }
    }
    loadResults()
    return () => { active = false }
  }, [selectedExamId, onNotice])

  const selectedExam = overview?.exams.find((exam) => exam.id === selectedExamId)
  const unmatchedStudents = useMemo(() => {
    const unique = new Map()
    for (const item of preview?.unmatched || []) {
      unique.set(`${item.seatNumber}|${item.fullName}`, item)
    }
    return [...unique.values()].sort((left, right) => left.seatNumber - right.seatNumber)
  }, [preview])

  async function analyzeFile() {
    if (!file) {
      onNotice('error', '請先選擇成績 Excel 檔案。')
      return
    }
    setParsing(true)
    setPreview(null)
    try {
      const parsed = await parseGradeWorkbook(file, {
        students: overview.students,
        cohortStartSchoolYear: Number(cohortStartSchoolYear),
      })
      setPreview(parsed)
      onNotice('success', `已辨識 ${parsed.exams.length} 次考試，請先檢查預覽再匯入。`)
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setParsing(false)
    }
  }

  async function handleImport() {
    if (!preview?.exams.length) return
    setImporting(true)
    try {
      const result = await importGradeWorkbook({
        classId: dashboard.classInfo.id,
        sourceFileName: file.name,
        exams: preview.exams,
      })
      await loadOverview({ keepSelection: false })
      setPreview(null)
      setFile(null)
      setFileInputKey((current) => current + 1)
      onNotice('success', `已匯入 ${result.examCount} 次考試、${result.resultCount} 筆學生成績；尚未發布給學生。`)
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setImporting(false)
    }
  }

  async function togglePublished() {
    if (!selectedExam) return
    setPublishing(true)
    try {
      await setGradeExamPublished({ examId: selectedExam.id, published: !selectedExam.isPublished })
      await loadOverview()
      onNotice('success', selectedExam.isPublished ? '這次成績已下架，學生暫時無法查看。' : '這次成績已發布，學生現在可以查看。')
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setPublishing(false)
    }
  }

  if (loading || !overview) {
    return <div className="admin-loading"><RefreshCw className="is-spinning" />正在讀取成績管理資料…</div>
  }

  return (
    <div className="grade-management">
      <section className="admin-panel grade-import-panel">
        <div className="admin-panel-heading">
          <div><span className="panel-icon"><FileSpreadsheet /></span><div><h2>匯入成績 Excel</h2><p>先分析與預覽，不會立即讓學生看到</p></div></div>
          <span className="status-pill">僅管理員</span>
        </div>
        <div className="grade-import-controls">
          <label><span>入學學年度</span><input type="number" min="100" max="999" value={cohortStartSchoolYear} onChange={(event) => setCohortStartSchoolYear(event.target.value)} /></label>
          <label className="grade-file-control"><span>成績檔案</span><input key={fileInputKey} type="file" accept=".xlsx" onChange={(event) => { setFile(event.target.files?.[0] || null); setPreview(null) }} /></label>
          <button type="button" className="approve-button" disabled={!file || parsing} onClick={analyzeFile}><FileSpreadsheet />{parsing ? '分析中…' : '分析 Excel'}</button>
        </div>
        <p className="grade-import-note">有學號時優先用學號配對；目前附件沒有學號，會以座號與姓名配對。重新匯入同一次考試可修正成績或補上校排。</p>

        {preview && <div className="grade-import-preview">
          <div className="grade-preview-summary">
            <strong>匯入預覽</strong>
            <span>{preview.exams.length} 次考試</span>
            <span>{preview.exams.reduce((sum, exam) => sum + exam.rows.length, 0)} 筆可匯入</span>
            <span className={unmatchedStudents.length ? 'has-warning' : ''}>{unmatchedStudents.length} 位尚未配對</span>
          </div>
          <div className="grade-preview-exams">{preview.exams.map((exam) => <article key={exam.key}><strong>{exam.label}</strong><span>{exam.rows.length} 位學生</span><small>{exam.rows.some((row) => row.sourceSheet === '各次段考平均') ? '含歷次平均資料' : '完整成績表'}</small></article>)}</div>
          {unmatchedStudents.length > 0 && <details className="grade-unmatched-list"><summary>查看尚未建立或無法配對的學生</summary><div>{unmatchedStudents.map((student) => <span key={`${student.seatNumber}-${student.fullName}`}>{student.seatNumber} 號・{student.fullName}</span>)}</div></details>}
          <div className="grade-import-submit"><p>未配對學生會自動略過，日後建立學生後可再次匯入補齊。</p><button type="button" className="approve-button" disabled={importing || !preview.exams.length} onClick={handleImport}><Upload />{importing ? '匯入中…' : '確認匯入成績'}</button></div>
        </div>}
      </section>

      <section className="admin-panel grade-class-panel">
        <div className="admin-panel-heading">
          <div><span className="panel-icon"><Users /></span><div><h2>全班段考成績</h2><p>選擇已匯入的考試，查詢或發布給學生</p></div></div>
          {selectedExam && <span className={`grade-publish-state ${selectedExam.isPublished ? 'is-published' : ''}`}>{selectedExam.isPublished ? '學生可見' : '尚未發布'}</span>}
        </div>
        <div className="grade-query-toolbar">
          <label><span>選擇考試</span><select value={selectedExamId} onChange={(event) => setSelectedExamId(event.target.value)}><option value="">尚無已匯入成績</option>{overview.exams.map((exam) => <option key={exam.id} value={exam.id}>{exam.label}{exam.isPublished ? '（已發布）' : ''}</option>)}</select></label>
          {selectedExam && <button type="button" className={selectedExam.isPublished ? 'secondary-button' : 'approve-button'} disabled={publishing || !results.length} onClick={togglePublished}>{selectedExam.isPublished ? <EyeOff /> : <Eye />}{publishing ? '處理中…' : selectedExam.isPublished ? '下架成績' : '發布給學生'}</button>}
        </div>
        {loadingResults && <div className="admin-loading"><RefreshCw className="is-spinning" />正在讀取全班成績…</div>}
        {!loadingResults && selectedExam && !results.length && <div className="admin-empty-state"><span><FileSpreadsheet /></span><div><strong>這次考試尚無學生成績</strong><p>請重新匯入包含這次考試的 Excel。</p></div></div>}
        {!loadingResults && results.length > 0 && <div className="grade-table-scroll"><table className="grade-score-table"><thead><tr><th>座號</th><th>姓名</th><th>國文</th><th>作文</th><th>英語</th><th>數學</th><th>自然</th><th>歷史</th><th>地理</th><th>公民</th><th>總分</th><th>加權總分</th><th>班排</th><th>校排</th></tr></thead><tbody>{results.map((result) => <tr key={result.id}><td>{result.seatNumber}</td><th scope="row">{result.fullName}</th><td>{scoreText(result.chineseScore)}</td><td>{scoreText(result.compositionScore)}</td><td>{scoreText(result.englishScore)}</td><td>{scoreText(result.mathScore)}</td><td>{scoreText(result.scienceScore)}</td><td>{scoreText(result.historyScore)}</td><td>{scoreText(result.geographyScore)}</td><td>{scoreText(result.civicsScore)}</td><td>{scoreText(result.totalScore)}</td><td>{scoreText(result.weightedTotalScore)}</td><td>{scoreText(result.classRank)}</td><td>{scoreText(result.schoolRank)}</td></tr>)}</tbody></table></div>}
      </section>
    </div>
  )
}
