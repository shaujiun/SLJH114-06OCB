import { useMemo } from 'react'
import { Award, Route } from 'lucide-react'
import { buildLongTermGradeProgress } from '../services/gradeService.js'

function Change({ value, unit = '分' }) {
  if (value === null) return <span className="grade-progress-change is-neutral">需至少 2 次資料</span>
  if (value === 0) return <span className="grade-progress-change is-neutral">持平</span>
  return <span className={`grade-progress-change ${value > 0 ? 'is-better' : 'is-lower'}`}>{value > 0 ? '進步' : '退步'} {Math.abs(value).toLocaleString('zh-TW')} {unit}</span>
}

function RankTrendChart({ results, ranks }) {
  const availableRanks = ranks.filter((rank) => rank.points.length)
  if (!availableRanks.length) return <p className="grade-rank-empty">目前尚無班排或校排資料；日後補入排名後，趨勢會自動顯示。</p>
  const chart = { top: 35, right: 32, bottom: 94, left: 62, height: 330 }
  const width = Math.max(720, results.length * 122 + chart.left + chart.right)
  const innerWidth = width - chart.left - chart.right
  const innerHeight = chart.height - chart.top - chart.bottom
  const xByExamId = new Map(results.map((result, index) => [result.examId, chart.left + (results.length <= 1 ? innerWidth / 2 : index * innerWidth / (results.length - 1))]))
  const maxRank = Math.max(5, ...availableRanks.flatMap((rank) => rank.points.map((point) => point.value)))
  const yPosition = (value) => chart.top + (Math.max(1, value) - 1) / Math.max(1, maxRank - 1) * innerHeight
  const pathFor = (points) => points.map((point, index) => `${index ? 'L' : 'M'} ${xByExamId.get(point.examId)} ${yPosition(point.value)}`).join(' ')
  const guides = [...new Set([1, Math.ceil(maxRank / 2), maxRank])]

  return <div className="grade-rank-chart-scroll" tabIndex="0" aria-label="班排與校排歷次趨勢，可左右捲動"><svg style={{ minWidth: `${width}px` }} viewBox={`0 0 ${width} ${chart.height}`} role="img" aria-label="班排與校排長期趨勢圖">
    {guides.map((rank) => <g key={rank}><line className="grade-rank-grid" x1={chart.left} y1={yPosition(rank)} x2={width - chart.right} y2={yPosition(rank)} /><text className="grade-rank-axis-label" x={chart.left - 10} y={yPosition(rank)} textAnchor="end" dominantBaseline="middle">第 {rank} 名</text></g>)}
    {results.map((result) => <text key={result.examId} className="grade-rank-exam-label" x={xByExamId.get(result.examId)} y={chart.top + innerHeight + 22} textAnchor="end" transform={`rotate(-35 ${xByExamId.get(result.examId)} ${chart.top + innerHeight + 22})`}>{result.exam.label}</text>)}
    {availableRanks.map((rank) => <g key={rank.key}><path className={`grade-rank-line is-${rank.key}`} d={pathFor(rank.points)} />{rank.points.map((point) => <circle key={point.examId} className={`grade-rank-point is-${rank.key}`} cx={xByExamId.get(point.examId)} cy={yPosition(point.value)} r="5"><title>{`${point.examLabel}・${rank.label}第 ${point.value} 名`}</title></circle>)}</g>)}
  </svg></div>
}

export default function GradeProgressSummary({ results, rankVisibility = {} }) {
  const progress = useMemo(() => buildLongTermGradeProgress(results), [results])
  const visibleRanks = progress.ranks.filter((rank) => (
    rank.key === 'classRank' ? rankVisibility.showClassRank : rankVisibility.showSchoolRank
  ))
  return <div className="grade-progress-summary">
    <div className="grade-progress-heading"><Route /><div><h3>各科長期進退步</h3><p>以第一次有成績的考試與最近一次比較，缺考不列入計算。</p></div></div>
    <div className="grade-progress-subjects">{progress.subjects.map((subject) => <article key={subject.key}>
      <div><strong>{subject.label}</strong><span>{subject.points.length} 次資料</span></div>
      <p>最初 <b>{subject.first?.value ?? '—'}</b><i>→</i>最近 <b>{subject.latest?.value ?? '—'}</b></p>
      <Change value={subject.totalChange} />
      <small>平均 {subject.average ?? '—'} 分・最高 {subject.best?.value ?? '—'} 分</small>
    </article>)}</div>

    {visibleRanks.length > 0 && <>
      <div className="grade-rank-heading"><Award /><div><h3>{visibleRanks.map((rank) => rank.label).join('與')}趨勢</h3><p>名次數字越小越前面；尚未匯入的排名不列入。</p></div></div>
      <div className="grade-rank-summary">{visibleRanks.map((rank) => <article key={rank.key}><span>{rank.label}</span><strong>{rank.first?.value ? `第 ${rank.first.value} 名` : '尚無資料'} → {rank.latest?.value ? `第 ${rank.latest.value} 名` : '尚無資料'}</strong><Change value={rank.totalImprovement} unit="名" /></article>)}</div>
      <RankTrendChart results={results} ranks={visibleRanks} />
    </>}
  </div>
}
