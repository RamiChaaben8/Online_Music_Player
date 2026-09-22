import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { Eye, EyeOff, Music2 } from 'lucide-react'
import { useAuthStore } from '../../stores/authStore'

// ── Inline Google "G" SVG logo ──────────────────────────────────────────────
function GoogleIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 18 18" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
      <path
        d="M17.64 9.2c0-.637-.057-1.251-.164-1.84H9v3.481h4.844c-.209 1.125-.843 2.078-1.796 2.717v2.258h2.908c1.702-1.567 2.684-3.875 2.684-6.615z"
        fill="#4285F4"
      />
      <path
        d="M9 18c2.43 0 4.467-.806 5.956-2.184l-2.908-2.258c-.806.54-1.837.86-3.048.86-2.344 0-4.328-1.584-5.036-3.711H.957v2.332A8.997 8.997 0 0 0 9 18z"
        fill="#34A853"
      />
      <path
        d="M3.964 10.707A5.41 5.41 0 0 1 3.682 9c0-.593.102-1.17.282-1.707V4.961H.957A8.996 8.996 0 0 0 0 9c0 1.452.348 2.827.957 4.039l3.007-2.332z"
        fill="#FBBC05"
      />
      <path
        d="M9 3.58c1.321 0 2.508.454 3.44 1.345l2.582-2.58C13.463.891 11.426 0 9 0A8.997 8.997 0 0 0 .957 4.961L3.964 7.293C4.672 5.163 6.656 3.58 9 3.58z"
        fill="#EA4335"
      />
    </svg>
  )
}

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
  const { signInWithEmail, signInWithGoogle, loading, clearError } = useAuthStore()

  const [email,         setEmail]         = useState('')
  const [password,      setPassword]      = useState('')
  const [showPass,      setShowPass]      = useState(false)
  const [localError,    setLocalError]    = useState('')
  const [submitting,    setSubmitting]    = useState(false)
  const [googleLoading, setGoogleLoading] = useState(false)

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
      navigate('/', { replace: true })
    } catch (err) {
      setLocalError(err.message)
    } finally {
      setSubmitting(false)
    }
  }

  // ── Google sign-in ─────────────────────────────────────────────────────────
  async function handleGoogle() {
    clearError()
    setLocalError('')
    setGoogleLoading(true)
    try {
      await signInWithGoogle()
      navigate('/', { replace: true })
    } catch (err) {
      setLocalError(err.message)
    } finally {
      setGoogleLoading(false)
    }
  }

  const isWorking = submitting || googleLoading

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

        {/* ── Divider ──────────────────────────────────────────────────────── */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
            marginBottom: '16px',
          }}
        >
          <div style={{ flex: 1, height: '1px', backgroundColor: 'var(--color-highlight)' }} />
          <span style={{ color: 'var(--color-subtext)', fontSize: '13px' }}>or</span>
          <div style={{ flex: 1, height: '1px', backgroundColor: 'var(--color-highlight)' }} />
        </div>

        {/* ── Google Sign In ────────────────────────────────────────────────── */}
        <button
          type="button"
          onClick={handleGoogle}
          disabled={isWorking}
          style={{
            width: '100%',
            padding: '13px',
            backgroundColor: 'transparent',
            border: '1px solid var(--color-highlight-elevated)',
            borderRadius: '50px',
            color: 'var(--color-text)',
            fontSize: '15px',
            fontWeight: '600',
            cursor: isWorking ? 'not-allowed' : 'pointer',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '10px',
            transition: 'border-color 0.2s, background-color 0.2s',
            marginBottom: '32px',
          }}
          onMouseEnter={(e) => { if (!isWorking) e.currentTarget.style.backgroundColor = 'var(--color-highlight)' }}
          onMouseLeave={(e) => { if (!isWorking) e.currentTarget.style.backgroundColor = 'transparent' }}
        >
          <GoogleIcon />
          {googleLoading ? 'Connecting…' : 'Continue with Google'}
        </button>

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
