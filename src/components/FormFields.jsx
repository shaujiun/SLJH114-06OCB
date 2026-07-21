import { useState } from 'react'
import { Eye, EyeOff } from 'lucide-react'

export function TextField({
  id,
  label,
  error,
  hint,
  className = '',
  ...inputProps
}) {
  const describedBy = [error ? `${id}-error` : '', hint ? `${id}-hint` : '']
    .filter(Boolean)
    .join(' ') || undefined

  return (
    <div className={`field ${className}`}>
      <label htmlFor={id}>{label}</label>
      <input
        id={id}
        aria-invalid={Boolean(error)}
        aria-describedby={describedBy}
        {...inputProps}
      />
      {hint && <span className="field-hint" id={`${id}-hint`}>{hint}</span>}
      {error && <span className="field-error" id={`${id}-error`} role="alert">{error}</span>}
    </div>
  )
}

export function PasswordField({ id, label, error, hint, ...inputProps }) {
  const [visible, setVisible] = useState(false)
  const describedBy = [error ? `${id}-error` : '', hint ? `${id}-hint` : '']
    .filter(Boolean)
    .join(' ') || undefined

  return (
    <div className="field">
      <label htmlFor={id}>{label}</label>
      <div className="password-wrap">
        <input
          id={id}
          type={visible ? 'text' : 'password'}
          aria-invalid={Boolean(error)}
          aria-describedby={describedBy}
          {...inputProps}
        />
        <button
          className="password-toggle"
          type="button"
          onClick={() => setVisible((value) => !value)}
          aria-label={visible ? '隱藏密碼' : '顯示密碼'}
        >
          {visible ? <EyeOff aria-hidden="true" /> : <Eye aria-hidden="true" />}
        </button>
      </div>
      {hint && <span className="field-hint" id={`${id}-hint`}>{hint}</span>}
      {error && <span className="field-error" id={`${id}-error`} role="alert">{error}</span>}
    </div>
  )
}
