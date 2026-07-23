import { useEffect, useMemo, useState } from 'react'
import { BarChart3, BrainCircuit, CheckCircle2, RefreshCw, TrendingUp } from 'lucide-react'
import {
  buildAutomaticGradeAnalysis,
  calculateSubjectAverages,
  gradeSubjectDefinitions,
  loadStudentGrades,
} from '../services/gradeService.js'

function displayScore(value, missing = '—') {
  return value === null || value === undefined || value === '' ? missing : Number(value).toLocaleString('zh-TW')
}

function radarPoint(index, value, radius = 112, center = 145) {
  const angle = -Math.PI / 2 + index * Math.PI * 2 / gradeSubjectDefinitions.length
  const scaledRadius = radius * Math.max(0, Math.min(100, Number(value) || 0)) / 100
  return `${center + Math.cos(angle) * scaledRadius},${center + Math.sin(angle) * scaledRadius}`
}

function GradeRadarChart({ result }) {
  const values = gradeSubjectDefinitions.map((subject) => result?.[subject.key])
  const validPoints = values.flatMap((value, index) => (
    value === null || value === undefined || value === ''
      ? []
      : [{ key: gradeSubjectDefinitions[index].key, point: radarPoint(index, value) }]
  ))
  const allSubjectsPresent = validPoints.length === gradeSubjectDefinitions.length
  return (
    <div className="grade-radar-card">
      <h3>七科雷達圖</h3>
      <svg viewBox="0 0 290 290" role="img" aria-label={`${result.exam.label}七科雷達圖`}>
        {[20, 40, 60, 80, 100].map((level) => <polygon key={level} className="grade-radar-grid" points={gradeSubjectDefinitions.map((_, index) => radarPoint(index, level)).join(' ')} />)}
        {gradeSubjectDefinitions.map((subject, index) => <line key={subject.key} className="grade-radar-axis" x1="145" y1="145" x2={radarPoint(index, 100).split(',')[0]} y2={radarPoint(index, 100).split(',')[1]} />)}
        {allSubjectsPresent
          ? <polygon className="grade-radar-result" points={validPoints.map((item) => item.point).join(' ')} />
          : <polyline className="grade-radar-result is-partial" points={validPoints.map((item) => item.point).join(' ')} />}
        {validPoints.map((item) => {
          const [cx, cy] = item.point.split(',')
          return <circle key={item.key} className="grade-radar-point" cx={cx} cy={cy} r="4" />
        })}
        {gradeSubjectDefinitions.map((subject, index) => {
          const [x, y] = radarPoint(index, 118).split(',').map(Number)
          return <text key={subject.key} x={x} y={y} textAnchor="middle" dominantBaseline="middle">{subject.label}</text>
        })}
      </svg>
      <p>作文獨立顯示；缺考科目不以 0 分計入雷達圖。</p>
    </div>
  )
}

export default function StudentGrades({ studentId }) {
  const [results, setResults] = useState([])
  const [selectedExamId, setSelectedExamId] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    let active = true
    async function load() {
      setLoading(true)
      try {
        const data = await loadStudentGrades({ studentId })
        if (!active) return
        setResults(data)
        setSelectedExamId((current) => data.some((result) => result.examId === current) ? current : data.at(-1)?.examId || '')
        setError('')
      } catch (loadError) {
        if (active) setError(loadError.message)
      } finally {
        if (active) setLoading(false)
      }
    }
    load()
    return () => { active = false }
  }, [studentId])

  const selected = results.find((result) => result.examId === selectedExamId)
  const averages = useMemo(() => calculateSubjectAverages(results), [results])
  const analysis = useMemo(() => buildAutomaticGradeAnalysis(results), [results])

  if (loading) return <div className="student-home-loading"><RefreshCw className="is-spinning" /><strong>正在整理個人成績…</strong></div>
  if (error) return <div className="student-home-empty"><BarChart3 /><strong>{error}</strong></div>
  if (!results.length) return <section className="student-home-panel student-grades-empty"><div className="student-home-empty"><CheckCircle2 /><strong>目前還沒有已發布的成績</strong><span>老師完成匯入並發布後，才會顯示在這裡。</span></div></section>

  return (
    <div className="student-grades-view">
      <section className="student-home-panel student-grade-detail">
        <div className="student-home-panel-heading"><div><span><BarChart3 /></span><div><h2>個人成績</h2><p>選擇已發布的段考或模擬考</p></div></div><strong>{results.length} 次</strong></div>
        <label className="student-grade-select"><span>選擇考試</span><select value={selectedExamId} onChange={(event) => setSelectedExamId(event.target.value)}>{results.map((result) => <option key={result.examId} value={result.examId}>{result.exam.label}</option>)}</select></label>
        {selected && <div className="student-grade-selected-grid">
          <div className="grade-table-scroll"><table className="grade-score-table is-student"><thead><tr><th>國文</th><th>作文</th><th>英語</th><th>數學</th><th>自然</th><th>歷史</th><th>地理</th><th>公民</th><th>總分</th><th>加權總分</th><th>班排</th><th>校排</th></tr></thead><tbody><tr><td>{displayScore(selected.chineseScore, '缺考')}</td><td>{displayScore(selected.compositionScore, '缺考')}</td><td>{displayScore(selected.englishScore, '缺考')}</td><td>{displayScore(selected.mathScore, '缺考')}</td><td>{displayScore(selected.scienceScore, '缺考')}</td><td>{displayScore(selected.historyScore, '缺考')}</td><td>{displayScore(selected.geographyScore, '缺考')}</td><td>{displayScore(selected.civicsScore, '缺考')}</td><td>{displayScore(selected.totalScore)}</td><td>{displayScore(selected.weightedTotalScore)}</td><td>{displayScore(selected.classRank)}</td><td>{displayScore(selected.schoolRank)}</td></tr></tbody></table></div>
          <GradeRadarChart result={selected} />
        </div>}
      </section>

      <section className="student-home-panel student-grade-history">
        <div className="student-home-panel-heading"><div><span><TrendingUp /></span><div><h2>歷次七科成績</h2><p>橫向比較每一次已發布的考試</p></div></div></div>
        <div className="grade-table-scroll"><table className="grade-score-table is-history"><thead><tr><th>考試</th>{gradeSubjectDefinitions.map((subject) => <th key={subject.key}>{subject.label}</th>)}</tr></thead><tbody>{results.map((result) => <tr key={result.id}><th scope="row">{result.exam.label}</th>{gradeSubjectDefinitions.map((subject) => <td key={subject.key}>{displayScore(result[subject.key], '缺考')}</td>)}</tr>)}<tr className="grade-average-row"><th scope="row">目前平均</th>{averages.map((subject) => <td key={subject.key}>{displayScore(subject.average)}</td>)}</tr></tbody></table></div>
      </section>

      <section className="student-home-panel student-grade-analysis">
        <div className="student-home-panel-heading"><div><span><BrainCircuit /></span><div><h2>個人學習分析</h2><p>在站內依歷次成績自動整理，不傳送到外部 AI</p></div></div></div>
        <h3>{analysis.headline}</h3>
        <ul>{analysis.messages.map((message) => <li key={message}>{message}</li>)}</ul>
      </section>
    </div>
  )
}
