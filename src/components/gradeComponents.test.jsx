import { renderToStaticMarkup } from 'react-dom/server'
import { describe, expect, it } from 'vitest'
import GradeExamComparison from './GradeExamComparison.jsx'
import GradeProgressSummary from './GradeProgressSummary.jsx'

const results = [
  {
    id: 'result-term', examId: 'term-1',
    exam: { label: '八-1 一段', examType: 'term', sortOrder: 7 },
    chineseScore: 70, englishScore: 65, mathScore: 60, scienceScore: 75,
    historyScore: 80, geographyScore: 72, civicsScore: 78,
    totalScore: 500, weightedTotalScore: 1250, classRank: 12, schoolRank: null,
  },
  {
    id: 'result-mock', examId: 'mock-1',
    exam: { label: '第一次模擬考', examType: 'mock', sortOrder: 101 },
    chineseScore: 76, englishScore: 62, mathScore: 70, scienceScore: 75,
    historyScore: 82, geographyScore: 80, civicsScore: 82,
    totalScore: 527, weightedTotalScore: 1310, classRank: 8, schoolRank: 56,
  },
]

describe('學生端成績比較介面', () => {
  it('同時有段考與模擬考時顯示逐科差距', () => {
    const html = renderToStaticMarkup(<GradeExamComparison results={results} />)
    expect(html).toContain('段考 × 模擬考比較')
    expect(html).toContain('八-1 一段')
    expect(html).toContain('第一次模擬考')
    expect(html).toContain('＋6 分')
  })

  it('缺少模擬考時顯示等待資料說明', () => {
    const html = renderToStaticMarkup(<GradeExamComparison results={results.slice(0, 1)} />)
    expect(html).toContain('目前還不能進行交叉比較')
    expect(html).toContain('老師發布模擬考成績後')
  })

  it('顯示各科與排名長期進退步摘要', () => {
    const html = renderToStaticMarkup(<GradeProgressSummary results={results} />)
    expect(html).toContain('各科長期進退步')
    expect(html).toContain('班排與校排趨勢')
    expect(html).toContain('進步 10 分')
    expect(html).toContain('進步 4 名')
  })
})
