import { describe, expect, it } from 'vitest'
import {
  ADMISSION_COMPETITION_CATALOG,
  competitionByCode,
  competitionsForTier,
} from './admissionCompetitionCatalog.js'

describe('雲林區競賽目錄', () => {
  it('收錄文件列出的國際、全國與雲林縣級競賽', () => {
    expect(competitionsForTier('international')).toHaveLength(32)
    expect(competitionsForTier('national')).toHaveLength(35)
    expect(competitionsForTier('county')).toHaveLength(21)
    expect(ADMISSION_COMPETITION_CATALOG).toHaveLength(88)
  })

  it('保留縣級競賽的採計細項提示', () => {
    expect(competitionByCode('county-18')).toMatchObject({
      name: '雲林縣科技教育創意實作競賽',
      detailNote: expect.stringContaining('生活科技'),
    })
  })
})
