export function filterMissingStudentRows(rows, { startDate = '', endDate = '', seatNumber = '' } = {}) {
  return (rows || [])
    .filter((student) => seatNumber === '' || student.seatNumber === Number(seatNumber))
    .map((student) => {
      const assignments = student.assignments.filter((assignment) => (
        (!startDate || assignment.assignmentDate >= startDate)
        && (!endDate || assignment.assignmentDate <= endDate)
      ))
      return { ...student, assignments, missingCount: assignments.length }
    })
    .filter((student) => student.missingCount > 0)
}

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (character) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[character])
}

export function renderMissingAssignmentPrintHtml({ students, termLabel, startDate = '', endDate = '', seatNumber = '', printedAt }) {
  const dateLabel = startDate || endDate
    ? `${startDate || '最早'} ～ ${endDate || '最新'}`
    : '全部日期'
  const seatLabel = seatNumber === '' ? '全班' : `${seatNumber} 號`
  const count = students.reduce((total, student) => total + student.missingCount, 0)
  const body = students.length
    ? students.flatMap((student) => student.assignments.map((assignment) => `<tr><td>${escapeHtml(`${student.seatNumber} 號`)}</td><td>${escapeHtml(assignment.assignmentDate)}</td><td>${escapeHtml(assignment.subjectName)}</td><td>${escapeHtml(assignment.content)}</td></tr>`)).join('')
    : '<tr><td colspan="4" class="empty">此篩選條件沒有缺交紀錄。</td></tr>'

  return `<!doctype html><html lang="zh-Hant"><head><meta charset="utf-8"><title>作業缺交名單</title><style>
    @page { size: A4 portrait; margin: 16mm 14mm; }
    * { box-sizing: border-box; }
    body { margin: 0; color: #17212b; font: 12pt/1.5 "Microsoft JhengHei", "Noto Sans TC", sans-serif; }
    h1 { margin: 0 0 5mm; font-size: 20pt; }
    .meta { display: flex; flex-wrap: wrap; gap: 2mm 8mm; margin-bottom: 6mm; font-size: 10pt; }
    .summary { margin: 0 0 4mm; font-weight: bold; }
    table { width: 100%; border-collapse: collapse; table-layout: fixed; }
    th, td { border: 1px solid #718096; padding: 2.5mm; text-align: left; vertical-align: top; overflow-wrap: anywhere; }
    th { background: #e8edf2; }
    th:nth-child(1) { width: 23mm; } th:nth-child(2) { width: 29mm; } th:nth-child(3) { width: 28mm; }
    tr { break-inside: avoid; page-break-inside: avoid; }
    .empty { text-align: center; padding: 9mm; }
    .note { margin-top: 5mm; color: #475569; font-size: 9pt; }
    @media print { body { print-color-adjust: exact; -webkit-print-color-adjust: exact; } }
  </style></head><body>
    <h1>作業缺交名單</h1>
    <div class="meta"><span>學期：${escapeHtml(termLabel)}</span><span>作業日期：${escapeHtml(dateLabel)}</span><span>座號：${escapeHtml(seatLabel)}</span><span>列印時間：${escapeHtml(printedAt)}</span></div>
    <p class="summary">共 ${students.length} 位學生、${count} 筆缺交</p>
    <table><thead><tr><th>座號</th><th>作業日期</th><th>科目</th><th>作業名稱</th></tr></thead><tbody>${body}</tbody></table>
    <p class="note">本名單為列印當下、已到期且尚未繳交的作業；學生補交後，請重新產生名單。</p>
  </body></html>`
}
