import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  CheckCircle2,
  CircleAlert,
  ClipboardCheck,
  RefreshCw,
  Search,
  ShieldCheck,
  Trophy,
  Users,
} from 'lucide-react'
import {
  COMPETITION_AWARD_OPTIONS,
  TEAM_SCALE_OPTIONS,
  calculateAdmissionScores,
  competitionEntryScore,
} from '../lib/admissionScoring.js'
import { COMPETITION_TIER_LABELS } from '../lib/admissionCompetitionCatalog.js'
import {
  loadAdminAdmissionWorkspace,
  reviewAdmissionCompetition,
  reviewAdmissionSelfCheck,
} from '../services/admissionService.js'

function scoreText(value) {
  return Number.isInteger(value) ? String(value) : Number(value).toFixed(2).replace(/0+$/, '').replace(/\.$/, '')
}

function statusLabel(status) {
  return {
    self_reported: '學生自填',
    reviewed: '已檢核',
    needs_info: '需補資料',
    listed: '表列項目',
    pending: '待確認',
    approved: '已確認',
    rejected: '不採計',
  }[status] || status
}

function awardLabel(entry) {
  return COMPETITION_AWARD_OPTIONS[entry.tier]
    ?.find((option) => option.value === entry.awardLevel)?.label || '未設定名次'
}

function CompetitionReview({ entry, onSaved, onError }) {
  const [note, setNote] = useState(entry.adminNote || '')
  const [saving, setSaving] = useState(false)

  async function save(reviewStatus) {
    setSaving(true)
    try {
      await reviewAdmissionCompetition({ entryId: entry.id, reviewStatus, adminNote: note })
      await onSaved(`${entry.competitionName}已更新為「${statusLabel(reviewStatus)}」。`)
    } catch (error) {
      onError(error.message)
    } finally {
      setSaving(false)
    }
  }

  return (
    <article className={`admission-admin-competition is-${entry.reviewStatus}`}>
      <div><span>{COMPETITION_TIER_LABELS[entry.tier]}・{entry.schoolYear} 學年度</span><strong>{entry.competitionName}</strong><p>{awardLabel(entry)}・{TEAM_SCALE_OPTIONS[entry.teamScale]?.label}・{entry.competitionDetail || '未填競賽細項'}・試算 {scoreText(competitionEntryScore(entry))} 分</p><small>目前狀態：{statusLabel(entry.reviewStatus)}</small></div>
      <label><span>管理者備註</span><input type="text" maxLength="1000" value={note} onChange={(event) => setNote(event.target.value)} /></label>
      <div><button type="button" disabled={saving} onClick={() => save('approved')}><CheckCircle2 />確認採計</button><button type="button" className="is-danger" disabled={saving} onClick={() => save('rejected')}><CircleAlert />不列入</button></div>
    </article>
  )
}

export default function AdmissionSelfCheckManagement({ classId, onNotice }) {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState('all')
  const [selectedStudentId, setSelectedStudentId] = useState('')
  const [adminNote, setAdminNote] = useState('')
  const [reviewing, setReviewing] = useState(false)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const result = await loadAdminAdmissionWorkspace(classId)
      setData(result)
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setLoading(false)
    }
  }, [classId, onNotice])

  useEffect(() => { load() }, [load])

  const rows = useMemo(() => {
    if (!data) return []
    return data.students.map((student) => {
      const check = data.checks.find((item) => item.studentId === student.id)
      const competitions = data.competitions.filter((item) => item.studentId === student.id)
      const scores = calculateAdmissionScores(check || {}, competitions)
      return { student, check, competitions, scores }
    })
  }, [data])

  const visibleRows = useMemo(() => rows.filter((row) => {
    const keyword = search.trim().toLocaleLowerCase('zh-Hant')
    const matchesSearch = !keyword
      || String(row.student.seatNumber).includes(keyword)
      || row.student.fullName.toLocaleLowerCase('zh-Hant').includes(keyword)
      || row.student.studentId.toLocaleLowerCase('zh-Hant').includes(keyword)
    const matchesStatus = statusFilter === 'all'
      || (statusFilter === 'not_started' && !row.check)
      || (statusFilter === 'pending' && (row.check?.reviewStatus !== 'reviewed' || row.scores.pendingCompetitionCount > 0))
      || (statusFilter === 'reviewed' && row.check?.reviewStatus === 'reviewed')
    return matchesSearch && matchesStatus
  }), [rows, search, statusFilter])

  const selected = rows.find((row) => row.student.id === selectedStudentId)

  useEffect(() => {
    setAdminNote(selected?.check?.adminNote || '')
  }, [selected?.check?.id, selected?.check?.adminNote])

  async function reviewCheck(reviewStatus) {
    if (!selected?.check) return
    setReviewing(true)
    try {
      await reviewAdmissionSelfCheck({ selfCheckId: selected.check.id, reviewStatus, adminNote })
      await load()
      onNotice('success', `${selected.student.seatNumber} 號 ${selected.student.fullName} 已更新為「${statusLabel(reviewStatus)}」。`)
    } catch (error) {
      onNotice('error', error.message)
    } finally {
      setReviewing(false)
    }
  }

  async function competitionReviewed(message) {
    await load()
    onNotice('success', message)
  }

  if (loading) return <div className="admin-loading"><RefreshCw className="is-spinning" />正在整理全班超額比序自我檢核資料…</div>
  if (!data) return null

  const startedCount = rows.filter((row) => row.check).length
  const reviewedCount = rows.filter((row) => row.check?.reviewStatus === 'reviewed').length
  const pendingCompetitionCount = data.competitions.filter((entry) => entry.reviewStatus === 'pending').length

  return (
    <div className="admission-admin-workspace">
      <section className="admission-admin-intro">
        <div><p className="eyebrow">ADMISSION SELF-CHECK ADMIN</p><h2>超額比序自我檢核工作區</h2><p>查看學生自填內容、目前試算積分及待確認競賽。此處的檢核標記不取代正式招生審查。</p></div>
        <button type="button" onClick={load}><RefreshCw />重新整理</button>
      </section>

      <section className="admission-admin-summary">
        <article><Users /><span>全班學生</span><strong>{rows.length}</strong></article>
        <article><ClipboardCheck /><span>已開始填寫</span><strong>{startedCount}</strong></article>
        <article><ShieldCheck /><span>已檢核</span><strong>{reviewedCount}</strong></article>
        <article className={pendingCompetitionCount ? 'is-warning' : ''}><Trophy /><span>其他競賽待確認</span><strong>{pendingCompetitionCount}</strong></article>
      </section>

      <section className="admission-admin-list-panel">
        <div className="admission-admin-filters">
          <label><Search /><input type="search" placeholder="搜尋座號、姓名或學號" value={search} onChange={(event) => setSearch(event.target.value)} /></label>
          <select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value)}><option value="all">全部學生</option><option value="not_started">尚未填寫</option><option value="pending">待檢核／待補資料</option><option value="reviewed">已檢核</option></select>
        </div>
        <div className="admission-admin-table-wrap"><table><thead><tr><th>座號</th><th>學生</th><th>目前積分</th><th>競賽</th><th>狀態</th><th></th></tr></thead><tbody>{visibleRows.map((row) => <tr className={selectedStudentId === row.student.id ? 'is-selected' : ''} key={row.student.id}><td>{row.student.seatNumber}</td><td><strong>{row.student.fullName}</strong><small>{row.student.studentId}</small></td><td>{row.check ? `${scoreText(row.scores.withoutExam)}／60` : '尚未填寫'}</td><td>{row.competitions.length} 筆{row.scores.pendingCompetitionCount ? `・${row.scores.pendingCompetitionCount} 待確認` : ''}</td><td><span className={`admission-status is-${row.check?.reviewStatus || 'not-started'}`}>{row.check ? statusLabel(row.check.reviewStatus) : '未開始'}</span></td><td><button type="button" disabled={!row.check} onClick={() => setSelectedStudentId(row.student.id)}>查看</button></td></tr>)}</tbody></table></div>
        {!visibleRows.length && <p className="admission-admin-empty">沒有符合篩選條件的學生。</p>}
      </section>

      {selected?.check && <section className="admission-admin-detail">
        <header><div><span>{selected.student.seatNumber} 號</span><h2>{selected.student.fullName}</h2><p>最後更新：{selected.check.updatedAt ? new Date(selected.check.updatedAt).toLocaleString('zh-TW') : '未記錄'}</p></div><strong>{scoreText(selected.scores.withoutExam)}<small>／60</small></strong></header>
        <div className="admission-admin-breakdown">
          <span>志願序<strong>{scoreText(selected.scores.preference)}／8</strong></span>
          <span>經濟弱勢<strong>{scoreText(selected.scores.economic)}／1</strong></span>
          <span>就近入學<strong>{scoreText(selected.scores.nearby)}／5</strong></span>
          <span>出缺席<strong>{scoreText(selected.scores.attendance)}／5</strong></span>
          <span>無記過<strong>{scoreText(selected.scores.discipline)}／5</strong></span>
          <span>均衡學習<strong>{scoreText(selected.scores.balanced)}／9</strong></span>
          <span>偏遠小校<strong>{scoreText(selected.scores.remote)}／2</strong></span>
          <span>獎勵紀錄<strong>{scoreText(selected.scores.rewards)}／15</strong></span>
          <span>競賽成績<strong>{scoreText(selected.scores.competition)}／9</strong></span>
          <span>體適能<strong>{scoreText(selected.scores.fitness)}／6</strong></span>
          <span className="is-total">多元表現採計<strong>{scoreText(selected.scores.diversePerformance)}／25</strong></span>
        </div>
        <div className="admission-admin-review-box"><label><span>給學生的檢核備註</span><textarea maxLength="1000" rows="3" value={adminNote} onChange={(event) => setAdminNote(event.target.value)} /></label><div><button type="button" disabled={reviewing} onClick={() => reviewCheck('reviewed')}><CheckCircle2 />標記已檢核</button><button type="button" className="is-warning" disabled={reviewing} onClick={() => reviewCheck('needs_info')}><CircleAlert />請學生補資料</button></div></div>
        <section className="admission-admin-competitions"><h3>競賽紀錄</h3>{!selected.competitions.length && <p>這位學生尚未新增競賽。</p>}{selected.competitions.map((entry) => <CompetitionReview entry={entry} onSaved={competitionReviewed} onError={(message) => onNotice('error', message)} key={`${entry.id}-${entry.reviewStatus}-${entry.adminNote}`} />)}</section>
      </section>}
    </div>
  )
}
