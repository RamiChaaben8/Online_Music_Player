import { useState } from 'react'
import { Link } from 'react-router-dom'
import { Music2, ArrowLeft, Mail, CheckCircle2 } from 'lucide-react'
import { useAuthStore } from '../../stores/authStore'

const inputStyle = {
  width: '100%',
  padding: '14px 16px',
  backgroundColor: 'var(--color-highlight)',
  border: '1px solid transparent',
  borderRadius: '6px',
  color: 'var(--color-text)',
  fontSize: '15px',
  outline: 'none',
  transition: 'border-color 0.2s',
  boxSizing: 'border-box',
}

const labelStyle = {
  display: 'block',
  marginBottom: '6px',
  fontSize: '13px',
  fontWeight: '600',
  color: 'var(--color-subtext)',
  letterSpacing: '0.06em',
  textTransform: 'uppercase',
}

export default function ForgotPasswordPage() {
  const { sendPasswordReset, clearError } = useAuthStore()

  const [email,       setEmail]       = useState('')
  const [submitting,  setSubmitting]  = useState(false)
  const [localError,  setLocalError]  = useState('')
  const [sent,        setSent]        = useState(false)

  async function handleSubmit(e) {
    e.preventDefault()
    clearError()
    setLocalError('')

    if (!email.trim())               return setLocalError('Please enter your email address.')
    if (!/\S+@\S+\.\S+/.test(email)) return setLocalError('Please enter a valid email address.')

    setSubmitting(true)
    try {
      await sendPasswordReset(email)
      setSent(true)
    } catch (err) {
      setLocalError(err.message)
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div
      style={{
        minHeight: '100vh',
        backgroundColor: 'var(--color-main)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '24px 16px',
      }}
    >
      <div
        style={{
          width: '100%',
          maxWidth: '420px',
          backgroundColor: 'var(--color-sidebar)',
          borderRadius: '12px',
          padding: '48px 40px 40px',
          boxShadow: '0 8px 40px rgba(0,0,0,0.5)',
        }}
      >
        {/* ── Logo ─────────────────────────────────────────────────────────── */}
        <div style={{ textAlign: 'center', marginBottom: '36px' }}>
          <div
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              justifyContent: 'center',
              width: '56px',
              height: '56px',
              backgroundColor: 'var(--color-button)',
              borderRadius: '50%',
              marginBottom: '16px',
            }}
          >
            <Music2 size={28} color="#000" />
          </div>
          <h1
            style={{
              margin: 0,
              fontSize: '28px',
              fontWeight: '800',
              color: 'var(--color-text)',
              letterSpacing: '-0.5px',
            }}
          >
            Utify
          </h1>
        </div>

        {/* ── Success state ─────────────────────────────────────────────────── */}
        {sent ? (
          <div style={{ textAlign: 'center' }}>
            <div
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                justifyContent: 'center',
                width: '64px',
                height: '64px',
                backgroundColor: 'rgba(29,185,84,0.12)',
                borderRadius: '50%',
                marginBottom: '20px',
              }}
            >
              <CheckCircle2 size={32} color="var(--color-button)" />
            </div>

            <h2
              style={{
                margin: '0 0 12px',
                fontSize: '22px',
                fontWeight: '700',
                color: 'var(--color-text)',
              }}
            >
              Check your inbox
            </h2>
            <p
              style={{
                margin: '0 0 8px',
                fontSize: '15px',
                color: 'var(--color-subtext)',
                lineHeight: '1.5',
              }}
            >
              We sent a password reset link to:
            </p>
            <p
              style={{
                margin: '0 0 28px',
                fontSize: '15px',
                fontWeight: '600',
                color: 'var(--color-text)',
                wordBreak: 'break-all',
              }}
            >
              {email}
            </p>
            <p
              style={{
                margin: '0 0 28px',
                fontSize: '13px',
                color: 'var(--color-subtext)',
                lineHeight: '1.5',
              }}
            >
              Didn't receive it? Check your spam folder or{' '}
              <button
                type="button"
                onClick={() => { setSent(false); setLocalError('') }}
                style={{
                  background: 'none',
                  border: 'none',
                  cursor: 'pointer',
                  color: 'var(--color-button)',
                  fontSize: '13px',
                  fontWeight: '600',
                  padding: 0,
                  textDecoration: 'underline',
                }}
              >
                try again
              </button>
              .
            </p>

            <Link
              to="/login"
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '8px',
                color: 'var(--color-subtext)',
                fontSize: '14px',
                textDecoration: 'none',
                fontWeight: '500',
              }}
            >
              <ArrowLeft size={16} />
              Back to sign in
            </Link>
          </div>
        ) : (
          <>
            {/* ── Instructions ───────────────────────────────────────────── */}
            <div style={{ textAlign: 'center', marginBottom: '28px' }}>
              <div
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  width: '56px',
                  height: '56px',
                  backgroundColor: 'var(--color-highlight)',
                  borderRadius: '50%',
                  marginBottom: '16px',
                }}
              >
                <Mail size={26} color="var(--color-subtext)" />
              </div>
              <h2
                style={{
                  margin: '0 0 8px',
                  fontSize: '22px',
                  fontWeight: '700',
                  color: 'var(--color-text)',
                }}
              >
                Reset your password
              </h2>
              <p
                style={{
                  margin: 0,
                  fontSize: '14px',
                  color: 'var(--color-subtext)',
                  lineHeight: '1.5',
                }}
              >
                Enter the email you signed up with and we'll send you a reset link.
              </p>
            </div>

            {/* ── Error banner ─────────────────────────────────────────────── */}
            {localError && (
              <div
                role="alert"
                style={{
                  backgroundColor: 'rgba(232,23,58,0.12)',
                  border: '1px solid var(--color-error)',
                  borderRadius: '6px',
                  padding: '12px 14px',
                  marginBottom: '24px',
                  color: 'var(--color-error)',
                  fontSize: '14px',
                  lineHeight: '1.4',
                }}
              >
                {localError}
              </div>
            )}

            {/* ── Form ─────────────────────────────────────────────────────── */}
            <form onSubmit={handleSubmit} noValidate>
              <div style={{ marginBottom: '24px' }}>
                <label htmlFor="forgot-email" style={labelStyle}>Email address</label>
                <input
                  id="forgot-email"
                  type="email"
                  autoComplete="email"
                  placeholder="you@example.com"
                  value={email}
                  onChange={(e) => { setEmail(e.target.value); setLocalError('') }}
                  disabled={submitting}
                  style={inputStyle}
                  onFocus={(e) => (e.target.style.borderColor = 'var(--color-button)')}
                  onBlur={(e)  => (e.target.style.borderColor = 'transparent')}
                  // eslint-disable-next-line jsx-a11y/no-autofocus
                  autoFocus
                />
              </div>

              <button
                type="submit"
                disabled={submitting}
                style={{
                  width: '100%',
                  padding: '14px',
                  backgroundColor: submitting ? 'var(--color-highlight-elevated)' : 'var(--color-button)',
                  color: submitting ? 'var(--color-subtext)' : '#000',
                  border: 'none',
                  borderRadius: '50px',
                  fontSize: '15px',
                  fontWeight: '700',
                  cursor: submitting ? 'not-allowed' : 'pointer',
                  letterSpacing: '0.03em',
                  transition: 'background-color 0.2s, transform 0.1s',
                  marginBottom: '28px',
                }}
                onMouseEnter={(e) => { if (!submitting) e.currentTarget.style.backgroundColor = 'var(--color-button-active)' }}
                onMouseLeave={(e) => { if (!submitting) e.currentTarget.style.backgroundColor = 'var(--color-button)' }}
                onMouseDown={(e)  => { if (!submitting) e.currentTarget.style.transform = 'scale(0.98)' }}
                onMouseUp={(e)    => { if (!submitting) e.currentTarget.style.transform = 'scale(1)' }}
              >
                {submitting ? 'Sending…' : 'Send Reset Email'}
              </button>
            </form>

            {/* ── Back link ─────────────────────────────────────────────────── */}
            <div style={{ textAlign: 'center' }}>
              <Link
                to="/login"
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '6px',
                  color: 'var(--color-subtext)',
                  fontSize: '14px',
                  textDecoration: 'none',
                  fontWeight: '500',
                  transition: 'color 0.2s',
                }}
                onMouseEnter={(e) => (e.currentTarget.style.color = 'var(--color-text)')}
                onMouseLeave={(e) => (e.currentTarget.style.color = 'var(--color-subtext)')}
              >
                <ArrowLeft size={16} />
                Back to sign in
              </Link>
            </div>
          </>
        )}
      </div>
    </div>
  )
}
