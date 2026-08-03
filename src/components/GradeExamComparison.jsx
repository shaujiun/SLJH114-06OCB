import { useEffect, useMemo, useState } from 'react'
import { GitCompareArrows } from 'lucide-react'
import { compareGradeExams } from '../services/gradeService.js'

function displayValue(value, missing = '尚無資料') {
  return value === null || value === undefined || value === '' ? missing : Number(value).toLocaleString('zh-TW')
}

function Difference({ value, rank = false }) {
  if (value === null) return <span className="grade-comparison-missing">無法比較</span>
  if (value === 0) return <span className="grade-comparison-difference is-same">持平</span>
  const label = `${value > 0 ? '＋' : '－'}${Math.abs(value).toLocaleString('zh-TW')}`
  return <span className={`grade-comparison-difference ${value > 0 ? 'is-better' : 'is-lower'}`}>{label}{rank ? ' 名' : ' 分'}</span>
}

export default function GradeExamComparison({ results }) {
  const termResults = useMemo(() => results.filter((result) => result.exam?.examType === 'term'), [results])
  const mockResults = useMemo(() => results.filter((result) => result.exam?.examType === 'mock'), [results])
  const [termExamId, setTermExamId] = useState(termResults.at(-1)?.examId || '')
  const [mockExamId, setMockExamId] = useState(mockResults.at(-1)?.examId || '')

  useEffect(() => {
    setTermExamId((current) => termResults.some((result) => result.examId === current) ? current : termResults.at(-1)?.examId || '')
  }, [termResults])

  useEffect(() => {
    setMockExamId((current) => mockResults.some((result) => result.examId === current) ? current : mockResults.at(-1)?.examId || '')
  }, [mockResults])

  const termResult = termResults.find((result) => result.examId === termExamId)
  const mockResult = mockResults.find((result) => result.examId === mockExamId)
  const comparison = useMemo(() => compareGradeExams(termResult, mockResult), [termResult, mockResult])

  return (
    <section className="student-home-panel student-grade-comparison">
      <div className="student-home-panel-heading">
        <div><span><GitCompareArrows /></span><div><h2>段考 × 模擬考比較</h2><p>選擇各一次考試，逐科查看分數差距</p></div></div>
      </div>

      {!termResults.length || !mockResults.length ? (
        <div className="grade-comparison-empty">
          <GitCompareArrows />
          <div>
            <strong>目前還不能進行交叉比較</strong>
            <span>
              {!termResults.length ? '尚未發布段考成績。' : `目前已有 ${termResults.length} 次段考；`}
              {!mockResults.length ? '老師發布模擬考成績後，這裡會自動開放比較。' : `已有 ${mockResults.length} 次模擬考。`}
            </span>
          </div>
        </div>
      ) : (
        <>
          <div className="grade-comparison-selectors">
            <label><span>段考</span><select value={termExamId} onChange={(event) => setTermExamId(event.target.value)}>{termResults.map((result) => <option key={result.examId} value={result.examId}>{result.exam.label}</option>)}</select></label>
            <label><span>模擬考</span><select value={mockExamId} onChange={(event) => setMockExamId(event.target.value)}>{mockResults.map((result) => <option key={result.examId} value={result.examId}>{result.exam.label}</option>)}</select></label>
          </div>

          {comparison && <>
            <div className="grade-table-scroll"><table className="grade-score-table is-comparison"><thead><tr><th>科目</th><th>{termResult.exam.label}</th><th>{mockResult.exam.label}</th><th>差距</th></tr></thead><tbody>{comparison.subjects.map((subject) => <tr key={subject.key}><th scope="row">{subject.label}</th><td>{displayValue(subject.termScore, '缺考')}</td><td>{displayValue(subject.mockScore, '缺考')}</td><td><Difference value={subject.difference} /></td></tr>)}</tbody></table></div>

            <div className="grade-comparison-summary">
              {comparison.scoreSummaries.map((item) => <article key={item.key}><span>{item.label}</span><strong>{displayValue(item.termValue)} → {displayValue(item.mockValue)}</strong><Difference value={item.difference} /></article>)}
              {comparison.ranks.map((item) => <article key={item.key}><span>{item.label}</span><strong>{displayValue(item.termValue)} → {displayValue(item.mockValue)}</strong><Difference value={item.improvement} rank /></article>)}
            </div>
            <p className="grade-comparison-note">差距為「模擬考－段考」；排名的正數代表名次向前。不同考試難度可能不同，請搭配長期趨勢一起判讀。</p>
          </>}
        </>
      )}
    </section>
  )
}
