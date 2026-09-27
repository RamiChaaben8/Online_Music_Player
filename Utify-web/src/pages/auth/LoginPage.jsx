import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { Eye, EyeOff, Music2 } from 'lucide-react'
import { useAuthStore } from '../../stores/authStore'
import { auth } from '../../firebase'

// ── Shared field styles ──────────────────────────────────────────────────────
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

export default function LoginPage() {
  const navigate = useNavigate()
  const { signInWithEmail, loading, clearError } = useAuthStore()

  async function navigateAfterSignIn() {
    const token = await auth.currentUser?.getIdTokenResult()
    const isAdmin = token?.claims.admin === true || token?.claims.role === 'admin'
    navigate(isAdmin ? '/admin' : '/', { replace: true })
  }

  const [email,         setEmail]         = useState('')
  const [password,      setPassword]      = useState('')
  const [showPass,      setShowPass]      = useState(false)
  const [localError,    setLocalError]    = useState('')
  const [submitting,    setSubmitting]    = useState(false)

  // Clear errors when user types
  const handleEmailChange = (e)    => { setEmail(e.target.value);    setLocalError('') }
  const handlePasswordChange = (e) => { setPassword(e.target.value); setLocalError('') }

  // ── Email / password sign-in ───────────────────────────────────────────────
  async function handleSubmit(e) {
    e.preventDefault()
    clearError()
    setLocalError('')

    // Client-side validation
    if (!email.trim())    return setLocalError('Please enter your email address.')
    if (!password)        return setLocalError('Please enter your password.')
    if (password.length < 6) return setLocalError('Password must be at least 6 characters.')

    setSubmitting(true)
    try {
      await signInWithEmail(email, password)
      await navigateAfterSignIn()
    } catch (err) {
      setLocalError(err.message)
    } finally {
      setSubmitting(false)
    }
  }

  const isWorking = submitting

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
        <div style={{ textAlign: 'center', marginBottom: '40px' }}>
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
          <p style={{ margin: '8px 0 0', color: 'var(--color-subtext)', fontSize: '15px' }}>
            Sign in to your account
          </p>
        </div>

        {/* ── Error banner ─────────────────────────────────────────────────── */}
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

        {/* ── Form ─────────────────────────────────────────────────────────── */}
        <form onSubmit={handleSubmit} noValidate>
          {/* Email */}
          <div style={{ marginBottom: '20px' }}>
            <label htmlFor="login-email" style={labelStyle}>Email</label>
            <input
              id="login-email"
              type="email"
              autoComplete="email"
              placeholder="you@example.com"
              value={email}
              onChange={handleEmailChange}
              disabled={isWorking}
              style={inputStyle}
              onFocus={(e)  => (e.target.style.borderColor = 'var(--color-button)')}
              onBlur={(e)   => (e.target.style.borderColor = 'transparent')}
            />
          </div>

          {/* Password */}
          <div style={{ marginBottom: '12px' }}>
            <label htmlFor="login-password" style={labelStyle}>Password</label>
            <div style={{ position: 'relative' }}>
              <input
                id="login-password"
                type={showPass ? 'text' : 'password'}
                autoComplete="current-password"
                placeholder="Your password"
                value={password}
                onChange={handlePasswordChange}
                disabled={isWorking}
                style={{ ...inputStyle, paddingRight: '44px' }}
                onFocus={(e) => (e.target.style.borderColor = 'var(--color-button)')}
                onBlur={(e)  => (e.target.style.borderColor = 'transparent')}
              />
              <button
                type="button"
                onClick={() => setShowPass((v) => !v)}
                aria-label={showPass ? 'Hide password' : 'Show password'}
                style={{
                  position: 'absolute',
                  right: '12px',
                  top: '50%',
                  transform: 'translateY(-50%)',
                  background: 'none',
                  border: 'none',
                  cursor: 'pointer',
                  color: 'var(--color-subtext)',
                  padding: '4px',
                  display: 'flex',
                  alignItems: 'center',
                }}
              >
                {showPass ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>
          </div>

          {/* Forgot password */}
          <div style={{ textAlign: 'right', marginBottom: '28px' }}>
            <Link
              to="/forgot-password"
              style={{
                fontSize: '13px',
                color: 'var(--color-button)',
                textDecoration: 'none',
                fontWeight: '500',
              }}
            >
              Forgot password?
            </Link>
          </div>

          {/* Sign In button */}
          <button
            type="submit"
            disabled={isWorking}
            style={{
              width: '100%',
              padding: '14px',
              backgroundColor: isWorking ? 'var(--color-highlight-elevated)' : 'var(--color-button)',
              color: isWorking ? 'var(--color-subtext)' : '#000',
              border: 'none',
              borderRadius: '50px',
              fontSize: '15px',
              fontWeight: '700',
              cursor: isWorking ? 'not-allowed' : 'pointer',
              letterSpacing: '0.03em',
              transition: 'background-color 0.2s, transform 0.1s',
              marginBottom: '16px',
            }}
            onMouseEnter={(e) => { if (!isWorking) e.currentTarget.style.backgroundColor = 'var(--color-button-active)' }}
            onMouseLeave={(e) => { if (!isWorking) e.currentTarget.style.backgroundColor = 'var(--color-button)' }}
            onMouseDown={(e)  => { if (!isWorking) e.currentTarget.style.transform = 'scale(0.98)' }}
            onMouseUp={(e)    => { if (!isWorking) e.currentTarget.style.transform = 'scale(1)' }}
          >
            {submitting ? 'Signing in…' : 'Sign In'}
          </button>
        </form>

        {/* ── Footer ───────────────────────────────────────────────────────── */}
        <p style={{ textAlign: 'center', margin: 0, fontSize: '14px', color: 'var(--color-subtext)' }}>
          Don't have an account?{' '}
          <Link
            to="/signup"
            style={{ color: 'var(--color-button)', fontWeight: '600', textDecoration: 'none' }}
          >
            Sign up
          </Link>
        </p>
      </div>
    </div>
  )
}
