import { useMemo, useState } from 'react'
import { buildGradeTrendSeries } from '../services/gradeService.js'

const subjectColors = {
  chineseScore: '#b63f4b',
  englishScore: '#2f6fae',
  mathScore: '#7549a8',
  scienceScore: '#278266',
  historyScore: '#b96a24',
  geographyScore: '#167f99',
  civicsScore: '#6d7132',
}

const chart = {
  top: 24,
  right: 28,
  bottom: 105,
  left: 58,
  height: 410,
}

function pathFor(points, xPosition, yPosition) {
  let continues = false
  return points.map((point, index) => {
    if (point.value === null) {
      continues = false
      return ''
    }
    const command = continues ? 'L' : 'M'
    continues = true
    return `${command} ${xPosition(index)} ${yPosition(point.value)}`
  }).filter(Boolean).join(' ')
}

export default function GradeTrendChart({ results }) {
  const [selectedSubject, setSelectedSubject] = useState('all')
  const series = useMemo(() => buildGradeTrendSeries(results), [results])
  const width = Math.max(760, results.length * 128 + chart.left + chart.right)
  const innerWidth = width - chart.left - chart.right
  const innerHeight = chart.height - chart.top - chart.bottom
  const xPosition = (index) => chart.left + (
    results.length <= 1 ? innerWidth / 2 : index * innerWidth / (results.length - 1)
  )
  const yPosition = (value) => chart.top + (100 - Math.max(0, Math.min(100, value))) / 100 * innerHeight
  const visibleSeries = selectedSubject === 'all'
    ? series
    : series.filter((subject) => subject.key === selectedSubject)

  return (
    <div className="grade-trend-chart">
      <div className="grade-trend-controls" aria-label="折線圖科目選擇">
        <button
          className={selectedSubject === 'all' ? 'is-active' : ''}
          type="button"
          onClick={() => setSelectedSubject('all')}
        >
          全部七科
        </button>
        {series.map((subject) => (
          <button
            className={selectedSubject === subject.key ? 'is-active' : ''}
            type="button"
            key={subject.key}
            onClick={() => setSelectedSubject(subject.key)}
          >
            <i style={{ backgroundColor: subjectColors[subject.key] }} />
            {subject.label}
          </button>
        ))}
      </div>

      <div className="grade-trend-scroll" tabIndex="0" aria-label="各科歷次成績折線圖，可左右捲動">
        <svg
          style={{ minWidth: `${width}px` }}
          viewBox={`0 0 ${width} ${chart.height}`}
          role="img"
          aria-label={`共 ${results.length} 次考試的七科成績趨勢`}
        >
          {[0, 20, 40, 60, 80, 100].map((score) => {
            const y = yPosition(score)
            return (
              <g key={score}>
                <line className="grade-trend-grid" x1={chart.left} y1={y} x2={width - chart.right} y2={y} />
                <text className="grade-trend-axis-label" x={chart.left - 10} y={y} textAnchor="end" dominantBaseline="middle">{score}</text>
              </g>
            )
          })}

          {results.map((result, index) => {
            const x = xPosition(index)
            return (
              <g key={result.examId}>
                <line className="grade-trend-x-guide" x1={x} y1={chart.top} x2={x} y2={chart.top + innerHeight} />
                <text
                  className="grade-trend-exam-label"
                  x={x}
                  y={chart.top + innerHeight + 20}
                  textAnchor="end"
                  transform={`rotate(-35 ${x} ${chart.top + innerHeight + 20})`}
                >
                  {result.exam.label}
                </text>
              </g>
            )
          })}

          {visibleSeries.map((subject) => {
            const color = subjectColors[subject.key]
            return (
              <g key={subject.key}>
                <path
                  className="grade-trend-line"
                  d={pathFor(subject.points, xPosition, yPosition)}
                  style={{ stroke: color }}
                />
                {subject.points.map((point, index) => point.value === null ? null : (
                  <g key={point.examId}>
                    <circle
                      className="grade-trend-point"
                      cx={xPosition(index)}
                      cy={yPosition(point.value)}
                      r={selectedSubject === 'all' ? 4 : 6}
                      style={{ fill: color }}
                    >
                      <title>{`${point.examLabel}・${subject.label} ${point.value} 分`}</title>
                    </circle>
                    {selectedSubject !== 'all' && (
                      <text
                        className="grade-trend-value"
                        x={xPosition(index)}
                        y={yPosition(point.value) - 12}
                        textAnchor="middle"
                      >
                        {point.value}
                      </text>
                    )}
                  </g>
                ))}
              </g>
            )
          })}
        </svg>
      </div>
      <p className="grade-trend-note">缺考不以 0 分連線；點選單一科目可顯示各次分數。</p>
    </div>
  )
}
