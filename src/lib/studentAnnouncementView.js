const announcementMonthFormatter = new Intl.DateTimeFormat('en-US', {
  timeZone: 'Asia/Taipei',
  year: 'numeric',
  month: '2-digit',
})

export function announcementMonthKey(publishedAt) {
  const date = new Date(publishedAt)
  if (!publishedAt || Number.isNaN(date.getTime())) return ''
  const parts = Object.fromEntries(
    announcementMonthFormatter.formatToParts(date).map(({ type, value }) => [type, value]),
  )
  return `${parts.year}-${parts.month}`
}

export function announcementMonthOptions(announcements = []) {
  return [...new Set(announcements.map((item) => announcementMonthKey(item.publishedAt)).filter(Boolean))]
    .sort((left, right) => right.localeCompare(left))
    .map((value) => {
      const [year, month] = value.split('-')
      return { value, label: `${year} 年 ${Number(month)} 月` }
    })
}

export function announcementPreview(content, maxCharacters = 96) {
  const normalized = String(content || '').replace(/\s+/g, ' ').trim()
  if (!normalized) return ''
  const sentences = normalized.match(/[^。！？!?]+[。！？!?]?/g) || [normalized]
  const firstTwo = sentences.slice(0, 2).join('').trim()
  const characters = Array.from(firstTwo)
  const shortened = characters.length > maxCharacters
    ? characters.slice(0, maxCharacters).join('').trimEnd()
    : firstTwo
  return shortened + (shortened.length < normalized.length ? '…' : '')
}

export function announcementsForMonth(announcements = [], month = 'all') {
  return month === 'all'
    ? announcements
    : announcements.filter((item) => announcementMonthKey(item.publishedAt) === month)
}
