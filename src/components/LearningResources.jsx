import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  BookOpenText,
  CheckCircle2,
  PlayCircle,
  RefreshCw,
} from 'lucide-react'
import { loadStudentLearningResources } from '../services/learningResourceService.js'
import LearningResourceCard from './LearningResourceCard.jsx'

export default function LearningResources({ classId }) {
  const [resources, setResources] = useState([])
  const [resourceType, setResourceType] = useState('method')
  const [subjectId, setSubjectId] = useState('all')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    try {
      setResources(await loadStudentLearningResources({ classId }))
      setError('')
    } catch (loadError) {
      setError(loadError.message)
    } finally {
      setLoading(false)
    }
  }, [classId])

  useEffect(() => { load() }, [load])

  const typeResources = useMemo(
    () => resources.filter((resource) => resource.resourceType === resourceType),
    [resourceType, resources],
  )
  const subjects = useMemo(() => {
    const subjectMap = new Map()
    typeResources.forEach((resource) => {
      if (resource.subject?.id) subjectMap.set(resource.subject.id, resource.subject)
    })
    return [...subjectMap.values()].sort((left, right) => (
      String(left.name).localeCompare(String(right.name), 'zh-TW')
    ))
  }, [typeResources])
  const visibleResources = useMemo(
    () => typeResources.filter((resource) => (
      subjectId === 'all'
      || (subjectId === 'general' && !resource.classSubjectId)
      || resource.classSubjectId === subjectId
    )),
    [subjectId, typeResources],
  )

  useEffect(() => {
    if (
      subjectId !== 'all'
      && subjectId !== 'general'
      && !subjects.some((subject) => subject.id === subjectId)
    ) {
      setSubjectId('all')
    }
  }, [subjectId, subjects])

  return (
    <section className="student-learning-resources">
      <div className="student-home-panel-heading learning-resources-heading">
        <div>
          <span><BookOpenText /></span>
          <div><h2>學習資源</h2><p>挑選適合自己的方法與影片，慢慢累積學習力</p></div>
        </div>
        <button type="button" aria-label="重新整理學習資源" onClick={load} disabled={loading}>
          <RefreshCw className={loading ? 'is-spinning' : ''} />
        </button>
      </div>

      <div className="learning-resource-type-tabs" role="tablist" aria-label="學習資源類型">
        <button
          className={resourceType === 'method' ? 'is-active' : ''}
          type="button"
          onClick={() => { setResourceType('method'); setSubjectId('all') }}
        >
          <BookOpenText />學習方法
        </button>
        <button
          className={resourceType === 'video' ? 'is-active' : ''}
          type="button"
          onClick={() => { setResourceType('video'); setSubjectId('all') }}
        >
          <PlayCircle />學習影片
        </button>
      </div>

      <div className="learning-resource-subject-tabs" aria-label="依科目篩選">
        <button className={subjectId === 'all' ? 'is-active' : ''} type="button" onClick={() => setSubjectId('all')}>全部</button>
        {typeResources.some((resource) => !resource.classSubjectId) && (
          <button className={subjectId === 'general' ? 'is-active' : ''} type="button" onClick={() => setSubjectId('general')}>通用</button>
        )}
        {subjects.map((subject) => (
          <button
            className={subjectId === subject.id ? 'is-active' : ''}
            type="button"
            key={subject.id}
            onClick={() => setSubjectId(subject.id)}
          >
            {subject.name}
          </button>
        ))}
      </div>

      {loading && <div className="student-home-loading"><RefreshCw className="is-spinning" /><strong>正在整理學習資源…</strong></div>}
      {!loading && error && <div className="admin-notice is-error">{error}</div>}
      {!loading && !error && !visibleResources.length && (
        <div className="student-home-empty learning-resource-empty">
          <CheckCircle2 />
          <strong>目前還沒有這一類學習資源</strong>
          <span>老師發布後會出現在這裡。</span>
        </div>
      )}
      {!loading && !error && (
        <div className="learning-resource-student-grid">
          {visibleResources.map((resource) => (
            <LearningResourceCard resource={resource} key={resource.id} />
          ))}
        </div>
      )}
    </section>
  )
}
