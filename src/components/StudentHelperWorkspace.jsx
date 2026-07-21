import { useMemo, useState } from 'react'
import { ArrowLeft, ClipboardPenLine, GraduationCap, ShieldCheck } from 'lucide-react'
import { getEligibleHelperTermIds, getHelperSubjectPermissions } from '../services/studentService.js'
import AssignmentManagement from './AssignmentManagement.jsx'

export default function StudentHelperWorkspace({ dashboard, onBack }) {
  const eligibleTermIds = useMemo(
    () => getEligibleHelperTermIds(dashboard.helperAssignments, dashboard.terms),
    [dashboard.helperAssignments, dashboard.terms],
  )
  const eligibleTerms = useMemo(
    () => dashboard.terms.filter((term) => eligibleTermIds.includes(term.id)),
    [dashboard.terms, eligibleTermIds],
  )
  const initialTermId = eligibleTerms.some((term) => term.id === dashboard.defaultTermId)
    ? dashboard.defaultTermId
    : eligibleTerms[0]?.id || ''
  const [termId, setTermId] = useState(initialTermId)
  const selectedTerm = eligibleTerms.find((term) => term.id === termId)
  const classSubjects = getHelperSubjectPermissions(
    dashboard.helperAssignments,
    dashboard.classSubjects,
    termId,
  )
  const isHomeworkLeader = dashboard.helperAssignments.some((assignment) => (
    assignment.academicTermId === termId && assignment.helperRole === 'homework_leader'
  ))

  return (
    <section className="student-helper-workspace">
      <div className="student-helper-toolbar">
        <button type="button" onClick={onBack}><ArrowLeft aria-hidden="true" />返回我的聯絡簿</button>
        <label>
          <span>操作學期</span>
          <select value={termId} onChange={(event) => setTermId(event.target.value)}>
            {eligibleTerms.map((term) => <option value={term.id} key={term.id}>第 {term.semester} 學期</option>)}
          </select>
        </label>
      </div>

      <div className="student-helper-permission-card">
        <span className="student-helper-permission-icon"><ClipboardPenLine aria-hidden="true" /></span>
        <div>
          <p className="eyebrow">MY CLASS DUTY</p>
          <h1>{isHomeworkLeader ? '作業長工作區' : '科目小老師工作區'}</h1>
          <p>{isHomeworkLeader ? '可協助登記本學期全部科目的作業。' : '只可協助登記導師指派的科目。'}</p>
          <div className="student-helper-subjects"><GraduationCap aria-hidden="true" />{classSubjects.map((subject) => <span key={subject.id}>{subject.name}{subject.allowedTargetGroups.length === 1 && subject.allowedTargetGroups[0] !== 'common' ? ` ${subject.allowedTargetGroups[0]} 組` : ''}</span>)}</div>
        </div>
        <span className="student-helper-safety"><ShieldCheck aria-hidden="true" />無法進入教師設定</span>
      </div>

      {selectedTerm && classSubjects.length > 0 && (
        <AssignmentManagement
          key={termId}
          dashboard={{ ...dashboard, terms: [selectedTerm], classSubjects }}
          submissionStage="helper"
          hideTermPicker
        />
      )}
    </section>
  )
}
