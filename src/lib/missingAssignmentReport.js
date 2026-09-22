export function filterMissingStudentRows(rows, { startDate = '', endDate = '', seatNumbers = [] } = {}) {
  const selectedSeats = new Set(seatNumbers.map(Number))
  return (rows || [])
    .filter((student) => selectedSeats.size === 0 || selectedSeats.has(student.seatNumber))
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

function renderStudentCard(student) {
  const assignments = student.assignments.map((assignment) => `<li><time>${escapeHtml(assignment.assignmentDate)}</time><span>${escapeHtml(assignment.subjectName)}</span><strong>${escapeHtml(assignment.content)}</strong></li>`).join('')
  return `<section class="card"><header><strong>${escapeHtml(student.seatNumber)} 號</strong><small>${escapeHtml(student.missingCount)} 筆缺交</small></header><ul>${assignments}</ul></section>`
}

export function renderMissingAssignmentPrintHtml({ students, termLabel, startDate = '', endDate = '', seatNumbers = [], printedAt }) {
  const dateLabel = startDate || endDate
    ? `${startDate || '最早'} ～ ${endDate || '最新'}`
    : '全部日期'
  const seatLabel = seatNumbers.length ? `${[...seatNumbers].sort((left, right) => left - right).join('、')} 號` : '全班'
  const count = students.reduce((total, student) => total + student.missingCount, 0)
  const body = students.length
    ? Array.from({ length: Math.ceil(students.length / 2) }, (_, index) => `<div class="pair">${students.slice(index * 2, index * 2 + 2).map(renderStudentCard).join('')}</div>`).join('')
    : '<p class="empty">此篩選條件沒有缺交紀錄。</p>'

  return `<!doctype html><html lang="zh-Hant"><head><meta charset="utf-8"><title>作業缺交名單</title><style>
    @page { size: A4 portrait; margin: 16mm 14mm; }
    * { box-sizing: border-box; }
    body { margin: 0; color: #17212b; font: 10.5pt/1.45 "Microsoft JhengHei", "Noto Sans TC", sans-serif; }
    h1 { margin: 0 0 5mm; font-size: 20pt; }
    .meta { display: flex; flex-wrap: wrap; gap: 2mm 8mm; margin-bottom: 6mm; font-size: 10pt; }
    .summary { margin: 0 0 4mm; font-weight: bold; }
    .pair { display: flex; align-items: stretch; gap: 4mm; margin-bottom: 4mm; break-inside: avoid; page-break-inside: avoid; }
    .card { width: calc(50% - 2mm); min-width: 0; border: 1px solid #718096; border-radius: 2mm; overflow: hidden; }
    .card header { display: flex; align-items: baseline; justify-content: space-between; gap: 2mm; padding: 2mm 3mm; background: #e8edf2; }
    .card header strong { font-size: 14pt; }
    .card header small { font-size: 8pt; }
    .card ul { margin: 0; padding: 2mm 3mm; list-style: none; }
    .card li { padding: 1.5mm 0; overflow-wrap: anywhere; }
    .card li + li { border-top: 1px dashed #b7c2ce; }
    .card time { display: inline-block; margin-right: 2mm; font-weight: bold; }
    .card li span { margin-right: 2mm; color: #276155; font-weight: bold; }
    .card li strong { display: block; font-weight: 500; }
    .empty { text-align: center; padding: 9mm; }
    .note { margin-top: 5mm; color: #475569; font-size: 9pt; }
    @media print { body { print-color-adjust: exact; -webkit-print-color-adjust: exact; } }
  </style></head><body>
    <h1>作業缺交名單</h1>
    <div class="meta"><span>學期：${escapeHtml(termLabel)}</span><span>作業日期：${escapeHtml(dateLabel)}</span><span>座號篩選：${escapeHtml(seatLabel)}</span><span>列印時間：${escapeHtml(printedAt)}</span></div>
    <p class="summary">共 ${students.length} 位學生、${count} 筆缺交</p>
    <div class="cards">${body}</div>
    <p class="note">本名單為列印當下、已到期且尚未繳交的作業；學生補交後，請重新產生名單。</p>
  </body></html>`
}
