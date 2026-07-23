import { requireSupabase } from '../lib/supabase.js'

const gradeNames = { 7: '七', 8: '八', 9: '九' }
const examNames = { 1: '一段', 2: '二段' }

export const gradeSubjectDefinitions = [
  { key: 'chineseScore', label: '國文' },
  { key: 'englishScore', label: '英語' },
  { key: 'mathScore', label: '數學' },
  { key: 'scienceScore', label: '自然' },
  { key: 'historyScore', label: '歷史' },
  { key: 'geographyScore', label: '地理' },
  { key: 'civicsScore', label: '公民' },
]

export const gradeExamCatalog = [
  ...[7, 8, 9].flatMap((gradeLevel) => [1, 2, 3].flatMap((semester) => [1, 2].map((examNumber) => ({
    key: `g${gradeLevel}-s${semester}-e${examNumber}`,
    label: `${gradeNames[gradeLevel]}-${semester} ${examNames[examNumber]}`,
    examType: 'term',
    schoolYear: 114 + gradeLevel - 7,
    gradeLevel,
    semester,
    examNumber,
    sortOrder: (gradeLevel - 7) * 6 + (semester - 1) * 2 + examNumber,
  })))),
  ...[1, 2, 3, 4].map((examNumber) => ({
    key: `mock-${examNumber}`,
    label: `第${['一', '二', '三', '四'][examNumber - 1]}次模擬考`,
    examType: 'mock',
    schoolYear: 116,
    gradeLevel: 9,
    semester: null,
    examNumber,
    sortOrder: 100 + examNumber,
  })),
]

const examByKey = new Map(gradeExamCatalog.map((exam) => [exam.key, exam]))
const summaryExamCatalog = gradeExamCatalog.filter((exam) => exam.examType === 'term').slice(0, 17)

function normalizeText(value) {
  if (value === null || value === undefined) return ''
  return String(value).trim().replace(/\s+/g, ' ')
}

function numberOrNull(value) {
  if (value === null || value === undefined || value === '') return null
  const number = Number(value)
  return Number.isFinite(number) ? number : null
}

function integerOrNull(value) {
  const number = numberOrNull(value)
  return number === null ? null : Math.round(number)
}

function headerMap(row) {
  return new Map((row || []).map((value, index) => [normalizeText(value), index]))
}

function headerValue(row, headers, ...names) {
  for (const name of names) {
    const index = headers.get(name)
    if (index !== undefined) return row[index]
  }
  return null
}

function findStudentMatcher(students) {
  const byStudentId = new Map()
  const bySeatAndName = new Map()
  for (const student of students || []) {
    byStudentId.set(normalizeText(student.studentId), student)
    bySeatAndName.set(`${Number(student.seatNumber)}|${normalizeText(student.fullName)}`, student)
  }
  return ({ studentIdCode, seatNumber, fullName }) => {
    const normalizedStudentId = normalizeText(studentIdCode)
    if (normalizedStudentId && byStudentId.has(normalizedStudentId)) {
      return byStudentId.get(normalizedStudentId)
    }
    return bySeatAndName.get(`${Number(seatNumber)}|${normalizeText(fullName)}`) || null
  }
}

function emptyResult({ exam, student, sourceSheet, sourceRow }) {
  return {
    examKey: exam.key,
    studentId: student.id,
    studentIdCode: student.studentId,
    seatNumber: student.seatNumber,
    fullName: student.fullName,
    chineseScore: null,
    compositionScore: null,
    englishWrittenScore: null,
    englishListeningScore: null,
    englishScore: null,
    mathScore: null,
    scienceScore: null,
    historyScore: null,
    geographyScore: null,
    civicsScore: null,
    totalScore: null,
    weightedTotalScore: null,
    classRank: null,
    schoolRank: null,
    sourceSheet,
    sourceRow,
  }
}

function calculateTotal(result) {
  const scores = gradeSubjectDefinitions.map((subject) => result[subject.key])
  return scores.every((score) => score !== null)
    ? scores.reduce((sum, score) => sum + score, 0)
    : null
}

function addResult(resultMap, exam, result) {
  const examResults = resultMap.get(exam.key) || new Map()
  const current = examResults.get(result.studentId)
  const merged = current ? { ...current, ...Object.fromEntries(
    Object.entries(result).filter(([, value]) => value !== null && value !== ''),
  ) } : result
  merged.totalScore = calculateTotal(merged)
  examResults.set(result.studentId, merged)
  resultMap.set(exam.key, examResults)
}

function parseSummarySheet(rows, { students, resultMap, unmatched }) {
  const headers = rows[0] || []
  const seatIndex = headers.findIndex((value) => normalizeText(value) === '座號')
  const nameIndex = headers.findIndex((value) => normalizeText(value) === '姓名')
  if (seatIndex < 0 || nameIndex < 0) return
  const matchStudent = findStudentMatcher(students)
  const subjectPrefixes = new Map([
    ['國文', 'chineseScore'], ['英語', 'englishScore'], ['數學', 'mathScore'],
    ['自然', 'scienceScore'], ['歷史', 'historyScore'], ['地理', 'geographyScore'], ['公民', 'civicsScore'],
  ])
  const scoreColumns = new Map()
  headers.forEach((header, index) => {
    const match = /^(國文|英語|數學|自然|歷史|地理|公民)(\d+)$/.exec(normalizeText(header))
    if (!match) return
    const examIndex = Number(match[2]) - 1
    if (!summaryExamCatalog[examIndex]) return
    const columns = scoreColumns.get(examIndex) || {}
    columns[subjectPrefixes.get(match[1])] = index
    scoreColumns.set(examIndex, columns)
  })

  rows.slice(1).forEach((row, offset) => {
    const seatNumber = integerOrNull(row[seatIndex])
    const fullName = normalizeText(row[nameIndex])
    if (!seatNumber || !fullName) return
    const student = matchStudent({ seatNumber, fullName })
    for (const [examIndex, columns] of scoreColumns) {
      const exam = summaryExamCatalog[examIndex]
      const hasScore = Object.values(columns).some((index) => numberOrNull(row[index]) !== null)
      if (!hasScore) continue
      if (!student) {
        unmatched.push({ examKey: exam.key, examLabel: exam.label, sourceSheet: '各次段考平均', sourceRow: offset + 2, seatNumber, fullName })
        continue
      }
      const result = emptyResult({ exam, student, sourceSheet: '各次段考平均', sourceRow: offset + 2 })
      for (const [field, index] of Object.entries(columns)) result[field] = numberOrNull(row[index])
      addResult(resultMap, exam, result)
    }
  })
}

function examFromSheetName(sheetName, cohortStartSchoolYear) {
  const match = /^(\d{3})-(\d)(?:-)?([一二12])段$/.exec(normalizeText(sheetName))
  if (!match) return null
  const schoolYear = Number(match[1])
  const gradeLevel = 7 + schoolYear - Number(cohortStartSchoolYear)
  const semester = Number(match[2])
  const examNumber = ['一', '1'].includes(match[3]) ? 1 : 2
  return examByKey.get(`g${gradeLevel}-s${semester}-e${examNumber}`) || null
}

function parseDetailedSheet(rows, { sheetName, exam, students, resultMap, unmatched }) {
  const headerRowIndex = rows.findIndex((row) => {
    const labels = new Set((row || []).map(normalizeText))
    return labels.has('座號') && labels.has('姓名') && labels.has('國文')
  })
  if (headerRowIndex < 0) return
  const headers = headerMap(rows[headerRowIndex])
  const matchStudent = findStudentMatcher(students)

  rows.slice(headerRowIndex + 1).forEach((row, offset) => {
    const seatNumber = integerOrNull(headerValue(row, headers, '座號'))
    const fullName = normalizeText(headerValue(row, headers, '姓名'))
    const studentIdCode = normalizeText(headerValue(row, headers, '學號'))
    if (!seatNumber || !fullName) return
    const student = matchStudent({ studentIdCode, seatNumber, fullName })
    if (!student) {
      unmatched.push({ examKey: exam.key, examLabel: exam.label, sourceSheet: sheetName, sourceRow: headerRowIndex + offset + 2, seatNumber, fullName, studentIdCode })
      return
    }
    const result = emptyResult({ exam, student, sourceSheet: sheetName, sourceRow: headerRowIndex + offset + 2 })
    result.chineseScore = numberOrNull(headerValue(row, headers, '國文'))
    result.compositionScore = numberOrNull(headerValue(row, headers, '作文'))
    result.englishWrittenScore = numberOrNull(headerValue(row, headers, '英語', '英語筆試'))
    result.englishListeningScore = numberOrNull(headerValue(row, headers, '英聽', '英語聽力'))
    result.englishScore = numberOrNull(headerValue(row, headers, '英總', '英語總分'))
    if (result.englishScore === null && result.englishWrittenScore !== null && result.englishListeningScore !== null) {
      result.englishScore = result.englishWrittenScore + result.englishListeningScore
    }
    result.mathScore = numberOrNull(headerValue(row, headers, '數學'))
    result.scienceScore = numberOrNull(headerValue(row, headers, '自然'))
    result.historyScore = numberOrNull(headerValue(row, headers, '歷史'))
    result.geographyScore = numberOrNull(headerValue(row, headers, '地理'))
    result.civicsScore = numberOrNull(headerValue(row, headers, '公民'))
    result.weightedTotalScore = numberOrNull(headerValue(row, headers, '加權總分', '總分'))
    result.classRank = integerOrNull(headerValue(row, headers, '班排', '班排名'))
    result.schoolRank = integerOrNull(headerValue(row, headers, '校排', '校排名'))
    const independentlyRecordedScores = [
      result.chineseScore,
      result.compositionScore,
      result.englishWrittenScore,
      result.englishListeningScore,
      result.mathScore,
      result.scienceScore,
      result.historyScore,
      result.geographyScore,
      result.civicsScore,
    ]
    const hasRecordedScore = independentlyRecordedScores.some((score) => score !== null)
      || (result.englishScore !== null && result.englishScore !== 0)
    if (!hasRecordedScore) return
    addResult(resultMap, exam, result)
  })
}

export function parseGradeWorkbookRows({ sheets, students, cohortStartSchoolYear = 114 }) {
  const resultMap = new Map()
  const unmatched = []
  const summaryRows = sheets.get('各次段考平均')
  if (summaryRows) parseSummarySheet(summaryRows, { students, resultMap, unmatched })

  for (const [sheetName, rows] of sheets) {
    const exam = examFromSheetName(sheetName, cohortStartSchoolYear)
    if (exam) parseDetailedSheet(rows, { sheetName, exam, students, resultMap, unmatched })
  }

  const exams = [...resultMap.entries()].map(([examKey, studentsById]) => {
    const exam = examByKey.get(examKey)
    return {
      ...exam,
      schoolYear: Number(cohortStartSchoolYear) + exam.gradeLevel - 7,
      rows: [...studentsById.values()].sort((left, right) => left.seatNumber - right.seatNumber),
    }
  }).sort((left, right) => left.sortOrder - right.sortOrder)

  if (!exams.length && !unmatched.length) throw new Error('Excel 中找不到可辨識的段考成績。')
  return { exams, unmatched }
}

export async function parseGradeWorkbook(file, options) {
  if (!file || !/\.xlsx$/i.test(file.name || '')) throw new Error('請選擇 .xlsx 格式的 Excel 檔案。')
  const { default: readXlsxFile, readSheetNames } = await import('read-excel-file/browser')
  const sheetNames = await readSheetNames(file)
  const relevantNames = sheetNames.filter((name) => (
    name === '各次段考平均' || examFromSheetName(name, options?.cohortStartSchoolYear || 114)
  ))
  const sheets = new Map()
  for (const sheetName of relevantNames) {
    sheets.set(sheetName, await readXlsxFile(file, { sheet: sheetName }))
  }
  return parseGradeWorkbookRows({ ...options, sheets })
}

function mapExam(row) {
  return {
    id: row.id,
    key: row.exam_key,
    label: row.display_name,
    examType: row.exam_type,
    schoolYear: row.school_year,
    gradeLevel: row.grade_level,
    semester: row.semester,
    examNumber: row.exam_number,
    sortOrder: row.sort_order,
    isPublished: row.is_published,
    publishedAt: row.published_at,
    updatedAt: row.updated_at,
  }
}

function mapResult(row) {
  const exam = Array.isArray(row.grade_exam_periods) ? row.grade_exam_periods[0] : row.grade_exam_periods
  return {
    id: row.id,
    examId: row.exam_id,
    exam: exam ? mapExam(exam) : null,
    studentId: row.student_id,
    studentIdCode: row.snapshot_student_id_code,
    seatNumber: row.snapshot_seat_number,
    fullName: row.snapshot_full_name,
    classLabel: row.snapshot_class_label,
    chineseScore: row.chinese_score,
    compositionScore: row.composition_score,
    englishWrittenScore: row.english_written_score,
    englishListeningScore: row.english_listening_score,
    englishScore: row.english_score,
    mathScore: row.math_score,
    scienceScore: row.science_score,
    historyScore: row.history_score,
    geographyScore: row.geography_score,
    civicsScore: row.civics_score,
    totalScore: row.total_score,
    weightedTotalScore: row.weighted_total_score,
    classRank: row.class_rank,
    schoolRank: row.school_rank,
    updatedAt: row.updated_at,
  }
}

export async function loadAdminGradeOverview({ classId }) {
  const client = requireSupabase()
  const [examsResult, studentsResult] = await Promise.all([
    client.from('grade_exam_periods').select('*').eq('class_id', classId).order('sort_order'),
    client.from('students').select('id,student_id_code,seat_number,full_name').eq('class_id', classId).eq('is_active', true).order('seat_number'),
  ])
  if (examsResult.error) throw new Error('無法讀取已匯入的考試清單。')
  if (studentsResult.error) throw new Error('無法讀取成績匯入學生名單。')
  return {
    exams: (examsResult.data || []).map(mapExam),
    students: (studentsResult.data || []).map((student) => ({
      id: student.id,
      studentId: student.student_id_code,
      seatNumber: student.seat_number,
      fullName: student.full_name,
    })),
  }
}

export async function loadAdminGradeResults({ examId }) {
  if (!examId) return []
  const client = requireSupabase()
  const { data, error } = await client.from('student_grade_results').select('*').eq('exam_id', examId).order('snapshot_seat_number')
  if (error) throw new Error('無法讀取這次考試的全班成績。')
  return (data || []).map(mapResult)
}

export async function importGradeWorkbook({ classId, sourceFileName, exams }) {
  if (!classId || !exams?.length) throw new Error('沒有可匯入的成績。')
  const client = requireSupabase()
  const { data, error } = await client.rpc('admin_import_grade_workbook', {
    p_class_id: classId,
    p_source_file_name: normalizeText(sourceFileName).slice(0, 255),
    p_exams: exams.map((exam) => ({
      exam_key: exam.key,
      display_name: exam.label,
      exam_type: exam.examType,
      school_year: exam.schoolYear,
      grade_level: exam.gradeLevel,
      semester: exam.semester,
      exam_number: exam.examNumber,
      sort_order: exam.sortOrder,
      rows: exam.rows.map((row) => ({
        student_id: row.studentId,
        chinese_score: row.chineseScore,
        composition_score: row.compositionScore,
        english_written_score: row.englishWrittenScore,
        english_listening_score: row.englishListeningScore,
        english_score: row.englishScore,
        math_score: row.mathScore,
        science_score: row.scienceScore,
        history_score: row.historyScore,
        geography_score: row.geographyScore,
        civics_score: row.civicsScore,
        total_score: row.totalScore,
        weighted_total_score: row.weightedTotalScore,
        class_rank: row.classRank,
        school_rank: row.schoolRank,
        source_sheet: row.sourceSheet,
        source_row: row.sourceRow,
      })),
    })),
  })
  if (error) {
    const message = error.message || ''
    if (message.includes('permission_denied')) throw new Error('目前帳號沒有匯入成績的權限。')
    if (message.includes('invalid_student')) throw new Error('匯入名單包含不屬於本班的學生，請重新分析 Excel。')
    if (message.includes('invalid_grade_import')) throw new Error('成績格式或分數範圍有誤，請檢查預覽內容。')
    throw new Error('成績匯入失敗，請稍後再試。')
  }
  return data
}

export async function setGradeExamPublished({ examId, published }) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('admin_set_grade_exam_published', {
    p_exam_id: examId,
    p_published: Boolean(published),
  })
  if (error) throw new Error(published ? '成績發布失敗，請稍後再試。' : '成績下架失敗，請稍後再試。')
  return data
}

export async function loadStudentGrades({ studentId }) {
  const client = requireSupabase()
  const { data, error } = await client
    .from('student_grade_results')
    .select('*,grade_exam_periods!inner(*)')
    .eq('student_id', studentId)
    .eq('grade_exam_periods.is_published', true)
    .order('sort_order', { referencedTable: 'grade_exam_periods' })
  if (error) throw new Error('無法讀取個人成績，請重新整理後再試。')
  return (data || []).map(mapResult).sort((left, right) => left.exam.sortOrder - right.exam.sortOrder)
}

export function calculateSubjectAverages(results) {
  return gradeSubjectDefinitions.map((subject) => {
    const values = (results || []).map((result) => numberOrNull(result[subject.key])).filter((value) => value !== null)
    return {
      ...subject,
      average: values.length ? Math.round(values.reduce((sum, value) => sum + value, 0) / values.length * 10) / 10 : null,
      count: values.length,
    }
  })
}

const studyTips = {
  chineseScore: '每天安排短篇閱讀，整理段落主旨與容易誤判的題型。',
  englishScore: '分散背誦單字並朗讀例句，每週回頭複習曾經答錯的題目。',
  mathScore: '先整理錯題類型，再以少量多次的方式重做同類題目。',
  scienceScore: '把實驗步驟、現象與原因連成圖表，避免只背結論。',
  historyScore: '用時間軸串起人物、事件與因果，練習用自己的話說明。',
  geographyScore: '將地圖、位置與統計圖一起閱讀，建立區域之間的比較。',
  civicsScore: '用生活案例對照名詞與制度，並練習判斷題目中的關鍵條件。',
}

export function buildAutomaticGradeAnalysis(results) {
  const averages = calculateSubjectAverages(results).filter((item) => item.average !== null)
  if (!averages.length) return { headline: '成績資料尚不足', messages: ['再累積一次考試後，就能開始觀察各科趨勢。'] }
  const strongest = [...averages].sort((a, b) => b.average - a.average)[0]
  const focus = [...averages].sort((a, b) => a.average - b.average)[0]
  const latest = results.at(-1)
  const previous = results.at(-2)
  const comparable = previous && latest
    ? gradeSubjectDefinitions.map((subject) => {
      const latestScore = numberOrNull(latest[subject.key])
      const previousScore = numberOrNull(previous[subject.key])
      return { ...subject, change: latestScore === null || previousScore === null ? null : latestScore - previousScore }
    }).filter((item) => item.change !== null)
    : []
  const improved = [...comparable].sort((a, b) => b.change - a.change)[0]
  const messages = [
    `目前平均表現最穩定的是${strongest.label}（${strongest.average} 分），請繼續保持原本有效的準備方式。`,
    `${focus.label}是現階段最值得優先加強的科目。${studyTips[focus.key]}`,
  ]
  if (improved?.change > 0) messages.push(`${improved.label}比上一次進步 ${Math.round(improved.change * 10) / 10} 分，持續的小進步會累積成很大的改變。`)
  else messages.push('一次成績只是學習過程的訊號，找出一個能立刻調整的小習慣，就已經是在前進。')
  return { headline: `${strongest.label}是目前強項，下一步先照顧${focus.label}`, messages }
}
