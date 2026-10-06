import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  Award,
  Calculator,
  CheckCircle2,
  CircleAlert,
  ClipboardCheck,
  Plus,
  RefreshCw,
  Save,
  ShieldCheck,
  Trash2,
  Trophy,
} from 'lucide-react'
import {
  ADMISSION_SEMESTERS,
  BALANCED_DOMAIN_OPTIONS,
  COMPETITION_AWARD_OPTIONS,
  FITNESS_STANDARDS,
  TEAM_SCALE_OPTIONS,
  calculateAdmissionScores,
  competitionEntryScore,
  fitnessRecordResult,
} from '../lib/admissionScoring.js'
import { COMPETITION_TIER_LABELS } from '../lib/admissionCompetitionCatalog.js'
import {
  deleteMyAdmissionCompetition,
  loadMyAdmissionSelfCheck,
  saveMyAdmissionCompetition,
  saveMyAdmissionSelfCheck,
} from '../services/admissionService.js'

const reviewLabels = {
  listed: '表列項目，自我填報',
  pending: '其他競賽，待管理者確認',
  approved: '管理者已確認',
  rejected: '不列入目前試算',
}

function scoreText(value) {
  return Number.isInteger(value) ? String(value) : Number(value).toFixed(2).replace(/0+$/, '').replace(/\.$/, '')
}

function awardLabel(entry) {
  return COMPETITION_AWARD_OPTIONS[entry.tier]
    ?.find((option) => option.value === entry.awardLevel)?.label || '未設定名次'
}

function BooleanSelect({ id, label, value, onChange, yesLabel = '符合', noLabel = '不符合', hint }) {
  return (
    <label className="admission-field" htmlFor={id}>
      <span>{label}</span>
      <select id={id} value={value === null ? '' : String(value)} onChange={(event) => onChange(event.target.value === '' ? null : event.target.value === 'true')}>
        <option value="">尚未選擇</option>
        <option value="true">{yesLabel}</option>
        <option value="false">{noLabel}</option>
      </select>
      {hint && <small>{hint}</small>}
    </label>
  )
}

function CountSelect({ id, label, value, maximum, onChange, unit = '次', hint }) {
  return (
    <label className="admission-field" htmlFor={id}>
      <span>{label}</span>
      <select id={id} value={value} onChange={(event) => onChange(Number(event.target.value))}>
        {Array.from({ length: maximum + 1 }, (_, index) => <option value={index} key={index}>{index} {unit}</option>)}
      </select>
      {hint && <small>{hint}</small>}
    </label>
  )
}

function ScoreCard({ label, value, maximum, tone = '' }) {
  return <article className={`admission-score-card ${tone}`}><span>{label}</span><strong>{scoreText(value)}<small>／{maximum}</small></strong></article>
}

function SemesterRecordsEditor({ records, metrics, onChange }) {
  return (
    <fieldset className="admission-data-fieldset">
      <legend>出缺席與記過紀錄</legend>
      <p>逐學期輸入曠課及尚未銷過的獎懲次數；勾選「均已銷過」後，該學期的記過次數不列入計算。</p>
      <div className="admission-table-scroll">
        <table className="admission-semester-table">
          <thead><tr><th>學期</th><th>曠課節數</th><th>警告次數</th><th>小過次數</th><th>大過次數</th><th>記過均已銷過</th></tr></thead>
          <tbody>{records.map((record, index) => <tr className={record.disciplineCleared ? 'is-cleared' : ''} key={record.semester}>
            <th>{ADMISSION_SEMESTERS.find((item) => item.key === record.semester)?.label}</th>
            {['truancyPeriods', 'warningCount', 'minorDemeritCount', 'majorDemeritCount'].map((field) => <td key={field}><input aria-label={`${record.semester}-${field}`} type="number" inputMode="numeric" min="0" max="99" value={record[field] ?? ''} onChange={(event) => onChange(index, field, event.target.value)} /></td>)}
            <td><label className="admission-cleared-check"><input type="checkbox" checked={record.disciplineCleared === true} onChange={(event) => onChange(index, 'disciplineCleared', event.target.checked)} /><span>均已銷過</span></label></td>
          </tr>)}</tbody>
        </table>
      </div>
      <div className="admission-calculated-note"><strong>目前自動計算：</strong>無曠課 {metrics.attendance} 學期；未銷過紀錄為警告 {metrics.outstandingWarnings} 次、小過 {metrics.outstandingMinorDemerits} 次、大過 {metrics.outstandingMajorDemerits} 次。</div>
    </fieldset>
  )
}

function BalancedScoresEditor({ records, metrics, onChange }) {
  return (
    <fieldset className="admission-data-fieldset admission-balanced-scores">
      <legend>均衡學習各學期成績</legend>
      <p>系統以目前已輸入的學期成績計算各領域平均；平均達 60 分者每領域 3 分，四領域擇優採計三領域，最高 9 分。</p>
      <div className="admission-table-scroll">
        <table className="admission-semester-table">
          <thead><tr><th>領域</th>{ADMISSION_SEMESTERS.map((semester) => <th key={semester.key}>{semester.label.replace('年級', '').replace('學期', '')}</th>)}<th>目前平均</th><th>結果</th></tr></thead>
          <tbody>{BALANCED_DOMAIN_OPTIONS.map((domain) => {
            const result = metrics.domainResults.find((item) => item.key === domain.key)
            return <tr key={domain.key}><th>{domain.label}</th>{records.map((record, index) => <td key={record.semester}><input aria-label={`${domain.label}-${record.semester}`} type="number" inputMode="decimal" min="0" max="100" step="0.1" value={record[domain.key] ?? ''} onChange={(event) => onChange(index, domain.key, event.target.value)} /></td>)}<td><strong>{result?.average === null ? '—' : result?.average}</strong></td><td><span className={`admission-result-pill ${result?.passed ? 'is-passed' : ''}`}>{result?.average === null ? '未輸入' : result.passed ? '及格＋3' : '未達 60'}</span></td></tr>
          })}</tbody>
        </table>
      </div>
    </fieldset>
  )
}

const fitnessItemLabels = {
  muscular: '肌力與肌耐力',
  flexibility: '柔軟度',
  power: '瞬發力',
  cardio: '心肺耐力',
}

function formatSeconds(seconds) {
  const minutes = Math.floor(seconds / 60)
  return `${minutes}:${String(seconds % 60).padStart(2, '0')}`
}

function FitnessScoresEditor({ gender, records, metrics, onGenderChange, onChange }) {
  return (
    <fieldset className="admission-data-fieldset admission-fitness-scores">
      <legend>體適能各學期成績</legend>
      <div className="admission-fitness-heading">
        <label className="admission-field"><span>評分表性別</span><select value={gender} onChange={(event) => onGenderChange(event.target.value)}><option value="">請選擇</option><option value="male">男生</option><option value="female">女生</option></select><small>原評分表依性別及測驗當時年齡設定不同門檻。</small></label>
        <div className="admission-calculated-note"><strong>已達門檻：</strong>{metrics.qualifiedItems.length ? metrics.qualifiedItems.map((item) => fitnessItemLabels[item]).join('、') : '尚無'}；任一項 3 分，最高 6 分。</div>
      </div>
      <div className="admission-fitness-grid">{records.map((record, index) => {
        const result = fitnessRecordResult(record, gender)
        const standard = FITNESS_STANDARDS[gender]?.[Number(record.age)]
        const runLabel = gender === 'female' ? '800 公尺跑步' : gender === 'male' ? '1600 公尺跑步' : '跑步'
        return <article className="admission-fitness-card" key={record.semester}>
          <header><strong>{ADMISSION_SEMESTERS.find((item) => item.key === record.semester)?.label}</strong>{result.passedItems.length > 0 && <span>{result.passedItems.length} 項達標</span>}</header>
          <div className="admission-fitness-fields">
            <label><span>當時年齡</span><select value={record.age ?? ''} onChange={(event) => onChange(index, 'age', event.target.value)}><option value="">請選擇</option>{[13, 14, 15, 16].map((age) => <option value={age} key={age}>{age} 歲</option>)}</select></label>
            <label><span>仰臥捲腹</span><input type="number" min="0" inputMode="numeric" value={record.curlUps ?? ''} onChange={(event) => onChange(index, 'curlUps', event.target.value)} /><small>次</small></label>
            <label><span>坐姿體前彎</span><input type="number" min="0" step="0.1" inputMode="decimal" value={record.sitAndReach ?? ''} onChange={(event) => onChange(index, 'sitAndReach', event.target.value)} /><small>公分</small></label>
            <label><span>立定跳遠</span><input type="number" min="0" step="0.1" inputMode="decimal" value={record.standingLongJump ?? ''} onChange={(event) => onChange(index, 'standingLongJump', event.target.value)} /><small>公分</small></label>
            <label><span>心肺耐力方式</span><select value={record.cardioType || 'run'} onChange={(event) => onChange(index, 'cardioType', event.target.value)}><option value="run">{runLabel}</option><option value="shuttle">漸速耐力折返跑</option></select></label>
            <label><span>{record.cardioType === 'shuttle' ? '折返跑成績' : '跑步時間'}</span><input type="text" inputMode={record.cardioType === 'shuttle' ? 'numeric' : 'text'} placeholder={record.cardioType === 'shuttle' ? '輸入趟數' : '例如 11:16'} value={record.cardioResult ?? ''} onChange={(event) => onChange(index, 'cardioResult', event.target.value)} /><small>{record.cardioType === 'shuttle' ? '趟' : '分：秒'}</small></label>
          </div>
          {standard ? <p className="admission-fitness-standard">本列門檻：捲腹 ≥ {standard.curlUps} 次、體前彎 ≥ {standard.sitAndReach} 公分、跳遠 ≥ {standard.standingLongJump} 公分、跑步 ≤ {formatSeconds(standard.runSeconds)} 或折返跑 ≥ {standard.shuttleRun} 趟。</p> : <p className="admission-fitness-standard">選擇性別與當時年齡後，系統才會判斷是否達標。</p>}
        </article>
      })}</div>
    </fieldset>
  )
}

function CompetitionEditor({ catalog, entry, onSaved, onCancel }) {
  const currentSchoolYear = new Date().getFullYear() - 1911
  const [form, setForm] = useState(() => ({
    id: entry?.id || null,
    tier: entry?.tier || 'county',
    catalogCode: entry?.catalogCode || '',
    customName: entry?.catalogId ? '' : entry?.competitionName || '',
    competitionDetail: entry?.competitionDetail || '',
    schoolYear: entry?.schoolYear || currentSchoolYear,
    awardLevel: entry?.awardLevel || 'first',
    teamScale: entry?.teamScale || 'individual',
  }))
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const tierCatalog = catalog.filter((item) => item.tier === form.tier)
  const selectedCatalog = tierCatalog.find((item) => item.code === form.catalogCode)
  const awardOptions = COMPETITION_AWARD_OPTIONS[form.tier] || []
  const isCustom = form.catalogCode === 'custom'

  function changeTier(tier) {
    setForm((current) => ({
      ...current,
      tier,
      catalogCode: '',
      customName: '',
      awardLevel: COMPETITION_AWARD_OPTIONS[tier][0].value,
    }))
  }

  async function handleSubmit(event) {
    event.preventDefault()
    if (!form.catalogCode || (isCustom && form.customName.trim().length < 2)) {
      setError('請選擇競賽；若選擇其他競賽，請輸入完整名稱。')
      return
    }
    setSaving(true)
    setError('')
    try {
      await saveMyAdmissionCompetition({
        ...form,
        catalogCode: isCustom ? null : form.catalogCode,
      })
      await onSaved()
    } catch (saveError) {
      setError(saveError.message)
    } finally {
      setSaving(false)
    }
  }

  return (
    <form className="admission-competition-editor" onSubmit={handleSubmit}>
      <div className="admission-editor-grid">
        <label className="admission-field"><span>競賽層級</span><select value={form.tier} onChange={(event) => changeTier(event.target.value)}>{Object.entries(COMPETITION_TIER_LABELS).map(([value, label]) => <option value={value} key={value}>{label}</option>)}</select></label>
        <label className="admission-field admission-field-wide"><span>競賽名稱</span><select value={form.catalogCode} onChange={(event) => setForm({ ...form, catalogCode: event.target.value })}><option value="">請選擇競賽</option>{tierCatalog.map((item) => <option value={item.code} key={item.code}>{item.name}</option>)}<option value="custom">其他競賽（待管理者確認）</option></select>{selectedCatalog?.detailNote && <small>採計細項：{selectedCatalog.detailNote}</small>}</label>
        {isCustom && <label className="admission-field admission-field-wide"><span>其他競賽完整名稱</span><input type="text" maxLength="200" value={form.customName} onChange={(event) => setForm({ ...form, customName: event.target.value })} /><small>其他競賽在管理者確認前不列入積分。</small></label>}
        <label className="admission-field"><span>參加學年度</span><select value={form.schoolYear} onChange={(event) => setForm({ ...form, schoolYear: Number(event.target.value) })}>{Array.from({ length: 5 }, (_, index) => currentSchoolYear - 2 + index).map((year) => <option value={year} key={year}>{year} 學年度</option>)}</select></label>
        <label className="admission-field"><span>名次或等第</span><select value={form.awardLevel} onChange={(event) => setForm({ ...form, awardLevel: event.target.value })}>{awardOptions.map((option) => <option value={option.value} key={option.value}>{option.label}（{option.score} 分）</option>)}</select></label>
        <label className="admission-field"><span>個人／團體人數</span><select value={form.teamScale} onChange={(event) => setForm({ ...form, teamScale: event.target.value })}>{Object.entries(TEAM_SCALE_OPTIONS).map(([value, option]) => <option value={value} key={value}>{option.label}</option>)}</select></label>
        <label className="admission-field admission-field-wide"><span>競賽細項</span><input type="text" maxLength="300" placeholder="例如：國語朗讀、生活科技、國中男子組" value={form.competitionDetail} onChange={(event) => setForm({ ...form, competitionDetail: event.target.value })} /><small>請依獎狀或競賽證明填寫，以利後續核對採計細項。</small></label>
      </div>
      {error && <p className="admission-inline-error"><CircleAlert />{error}</p>}
      <div className="admission-editor-actions"><button type="submit" disabled={saving}><Save />{saving ? '儲存中…' : '儲存競賽紀錄'}</button>{onCancel && <button type="button" className="secondary-button" onClick={onCancel}>取消</button>}</div>
    </form>
  )
}

export default function AdmissionSelfCheck({ studentId }) {
  const [data, setData] = useState(null)
  const [check, setCheck] = useState(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [editingEntry, setEditingEntry] = useState(null)
  const [showCompetitionEditor, setShowCompetitionEditor] = useState(false)
  const [notice, setNotice] = useState(null)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const result = await loadMyAdmissionSelfCheck(studentId)
      setData(result)
      setCheck(result.check)
      setNotice(null)
    } catch (error) {
      setNotice({ type: 'error', message: error.message })
    } finally {
      setLoading(false)
    }
  }, [studentId])

  useEffect(() => { load() }, [load])

  const scores = useMemo(
    () => calculateAdmissionScores(check || {}, data?.competitions || []),
    [check, data?.competitions],
  )

  function update(field, value) {
    setCheck((current) => ({ ...current, [field]: value }))
    setNotice(null)
  }

  function updateRecord(collection, index, field, value) {
    setCheck((current) => ({
      ...current,
      [collection]: current[collection].map((record, recordIndex) => (
        recordIndex === index ? { ...record, [field]: value } : record
      )),
    }))
    setNotice(null)
  }

  async function saveCheck(event) {
    event.preventDefault()
    setSaving(true)
    setNotice(null)
    try {
      await saveMyAdmissionSelfCheck(check)
      await load()
      setNotice({ type: 'success', message: '自我檢核資料已儲存，分數已重新計算。' })
    } catch (error) {
      setNotice({ type: 'error', message: error.message })
    } finally {
      setSaving(false)
    }
  }

  async function removeCompetition(entry) {
    if (!window.confirm(`確定刪除「${entry.competitionName}」嗎？`)) return
    try {
      await deleteMyAdmissionCompetition(entry.id)
      await load()
      setNotice({ type: 'success', message: '競賽紀錄已刪除。' })
    } catch (error) {
      setNotice({ type: 'error', message: error.message })
    }
  }

  async function competitionSaved() {
    setEditingEntry(null)
    setShowCompetitionEditor(false)
    await load()
    setNotice({ type: 'success', message: '競賽紀錄已儲存並重新計分。' })
  }

  if (loading) return <section className="admission-loading"><RefreshCw className="is-spinning" /><strong>正在讀取超額比序自我檢核表…</strong></section>
  if (!data || !check) return <section className="admission-loading"><CircleAlert /><strong>{notice?.message || '無法讀取自我檢核表。'}</strong><button type="button" onClick={load}>重新讀取</button></section>

  return (
    <div className="admission-self-check">
      <section className="admission-hero">
        <div><p className="eyebrow">YUNLIN ADMISSION SELF-CHECK</p><h1>超額比序自我檢核表</h1><p>依雲林區免試入學比序項目先行試算，實際採計仍以學校及當年度招生簡章審查為準。</p></div>
        <div className="admission-total"><span>目前累積積分</span><strong>{scoreText(scores.withoutExam)}<small>／60</small></strong><em>不含教育會考 30 分</em></div>
      </section>

      <section className="admission-exam-goal"><ShieldCheck /><div><strong>教育會考不在此表輸入</strong><p>請自行評估會考要考的等級，並以此為目標努力。</p></div></section>
      {notice && <div className={`admin-notice is-${notice.type}`}>{notice.message}</div>}
      {check.reviewStatus === 'needs_info' && <div className="admission-review-message is-needs-info"><CircleAlert /><div><strong>管理者請你補充資料</strong><p>{check.adminNote || '請檢查自我檢核內容或競賽紀錄。'}</p></div></div>}
      {check.reviewStatus === 'reviewed' && <div className="admission-review-message is-reviewed"><CheckCircle2 /><div><strong>管理者已檢核本次資料</strong>{check.adminNote && <p>{check.adminNote}</p>}</div></div>}

      <section className="admission-score-grid" aria-label="積分摘要">
        <ScoreCard label="一般項目" value={scores.preference + scores.economic + scores.nearby + scores.attendance + scores.discipline + scores.balanced + scores.remote} maximum={35} />
        <ScoreCard label="獎勵紀錄" value={scores.rewards} maximum={15} />
        <ScoreCard label="競賽成績" value={scores.competition} maximum={9} />
        <ScoreCard label="體適能" value={scores.fitness} maximum={6} />
        <ScoreCard label="多元表現合計" value={scores.diversePerformance} maximum={25} tone="is-accent" />
      </section>

      <form className="admission-form" onSubmit={saveCheck}>
        <section className="admission-section">
          <header><span><Calculator /></span><div><h2>基本比序項目</h2><p>請依目前可確認的資料選擇；尚未確定可先保留未選。</p></div></header>
          <div className="admission-form-grid">
            <label className="admission-field"><span>預估志願序</span><select value={check.preferenceOrder} onChange={(event) => update('preferenceOrder', event.target.value)}><option value="">尚未選擇</option>{Array.from({ length: 50 }, (_, index) => <option value={index + 1} key={index + 1}>第 {index + 1} 志願</option>)}</select><small>第 1～10 志願 8 分，之後每 10 個志願遞減 1 分。</small></label>
            <BooleanSelect id="admission-economic" label="經濟弱勢" value={check.economicWeakness} onChange={(value) => update('economicWeakness', value)} yesLabel="具中低或低收入戶資格" hint="須以畢業當年度有效證明為準。" />
            <BooleanSelect id="admission-nearby" label="就近入學" value={check.nearbyEnrollment} onChange={(value) => update('nearbyEnrollment', value)} hint="雲林區及符合共同就學區資格者可得 5 分。" />
            <label className="admission-field"><span>偏遠小校</span><select value={check.remoteSchoolBand} onChange={(event) => update('remoteSchoolBand', event.target.value)}><option value="">尚未選擇</option><option value="seven_or_less">核定偏遠學校且 7 班以下－2 分</option><option value="eight_to_twelve">核定偏遠學校且 8 至 12 班－1 分</option><option value="other">不符合－0 分</option></select><small>是否符合須依畢業學年度核定及班級數認定。</small></label>
          </div>
          <SemesterRecordsEditor records={check.semesterRecords} metrics={scores.semesterMetrics} onChange={(index, field, value) => updateRecord('semesterRecords', index, field, value)} />
          <BalancedScoresEditor records={check.balancedScores} metrics={scores.balancedMetrics} onChange={(index, field, value) => updateRecord('balancedScores', index, field, value)} />
        </section>

        <section className="admission-section">
          <header><span><Award /></span><div><h2>獎勵紀錄與體適能</h2><p>獎勵、競賽、體適能三項合計最高採計 25 分。</p></div></header>
          <div className="admission-form-grid is-three">
            <CountSelect id="admission-major-merit" label="大功" value={check.majorMerits} maximum={20} onChange={(value) => update('majorMerits', value)} unit="支" hint="每支 4.5 分" />
            <CountSelect id="admission-minor-merit" label="小功" value={check.minorMerits} maximum={30} onChange={(value) => update('minorMerits', value)} unit="支" hint="每支 1.5 分" />
            <CountSelect id="admission-commendation" label="嘉獎" value={check.commendations} maximum={40} onChange={(value) => update('commendations', value)} unit="支" hint="每支 0.5 分；獎勵最高 15 分" />
          </div>
          <FitnessScoresEditor gender={check.fitnessGender} records={check.fitnessRecords} metrics={scores.fitnessMetrics} onGenderChange={(value) => update('fitnessGender', value)} onChange={(index, field, value) => updateRecord('fitnessRecords', index, field, value)} />
        </section>

        <button className="admission-primary-save" type="submit" disabled={saving}><Save />{saving ? '儲存中…' : '儲存自我檢核資料'}</button>
      </form>

      <section className="admission-section admission-competitions">
        <header><span><Trophy /></span><div><h2>競賽成績</h2><p>可新增三年內多項比賽；同學年度同一性質或同一項目只採最高一次，競賽最高 9 分。</p><small>實際採計由雲林縣教育處認定，本系統只能提供參考。</small></div><button type="button" onClick={() => { setEditingEntry(null); setShowCompetitionEditor(true) }}><Plus />新增競賽</button></header>
        {scores.pendingCompetitionCount > 0 && <p className="admission-competition-warning"><CircleAlert />有 {scores.pendingCompetitionCount} 筆其他競賽尚待管理者確認，目前未計分。</p>}
        {scores.duplicateCompetitionCount > 0 && <p className="admission-competition-warning"><CircleAlert />偵測到同學年度重複競賽，已自動只採分數最高的一筆。</p>}
        {(showCompetitionEditor || editingEntry) && <CompetitionEditor key={editingEntry?.id || 'new'} catalog={data.catalog} entry={editingEntry} onSaved={competitionSaved} onCancel={() => { setEditingEntry(null); setShowCompetitionEditor(false) }} />}
        {!data.competitions.length && <div className="admission-empty"><Trophy /><strong>尚未新增競賽紀錄</strong><p>參加比賽並獲獎後，可逐筆新增。</p></div>}
        <div className="admission-competition-list">{data.competitions.map((entry) => <article className={`is-${entry.reviewStatus}`} key={entry.id}><div className="admission-competition-main"><span>{COMPETITION_TIER_LABELS[entry.tier]}</span><div><strong>{entry.competitionName}</strong><p>{entry.schoolYear} 學年度・{awardLabel(entry)}・{TEAM_SCALE_OPTIONS[entry.teamScale]?.label}{entry.competitionDetail ? `・${entry.competitionDetail}` : ''}</p><small>{reviewLabels[entry.reviewStatus]}{entry.adminNote ? `：${entry.adminNote}` : ''}</small></div></div><div className="admission-competition-score"><strong>{scoreText(competitionEntryScore(entry))}</strong><span>分</span></div><div className="admission-competition-actions"><button type="button" onClick={() => { setShowCompetitionEditor(false); setEditingEntry(entry) }}>編輯</button><button type="button" className="is-danger" onClick={() => removeCompetition(entry)}><Trash2 />刪除</button></div></article>)}</div>
      </section>

      <details className="admission-source-note"><summary><ClipboardCheck />查看計分依據與重要提醒</summary><div><p>依據「雲林區高級中等學校免試入學比序項目積分對照表」及「雲林區十二年國民基本教育免試入學比序項目採計作業補充說明及競賽成績採計參照表」（中華民國 113 年 5 月 16 日修正）建置。</p><ul><li>採計期間、證明文件、競賽細項及當年度簡章仍由學校與主管機關正式認定。</li><li>獎勵與競賽不得以同一事由重複採認。</li><li>參加獎、邀請賽及不在公告採計範圍的競賽不一定能計分。</li><li>這裡顯示的是自我檢核試算，不是正式免試入學成績證明。</li></ul></div></details>
    </div>
  )
}
