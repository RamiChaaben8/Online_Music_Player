import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { Eye, EyeOff, Music2 } from 'lucide-react'
import { useAuthStore } from '../../stores/authStore'

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

// ── Password strength indicator ──────────────────────────────────────────────
function PasswordStrength({ password }) {
  if (!password) return null

  let strength = 0
  if (password.length >= 8)            strength++
  if (/[A-Z]/.test(password))          strength++
  if (/[0-9]/.test(password))          strength++
  if (/[^A-Za-z0-9]/.test(password))  strength++

  const labels = ['Weak', 'Fair', 'Good', 'Strong']
  const colors = ['#E8173A', '#FFA000', '#1DB954', '#1DB954']

  return (
    <div style={{ marginTop: '8px' }}>
      <div style={{ display: 'flex', gap: '4px', marginBottom: '4px' }}>
        {[0, 1, 2, 3].map((i) => (
          <div
            key={i}
            style={{
              flex: 1,
              height: '3px',
              borderRadius: '2px',
              backgroundColor: i < strength ? colors[strength - 1] : 'var(--color-highlight-elevated)',
              transition: 'background-color 0.3s',
            }}
          />
        ))}
      </div>
      {strength > 0 && (
        <span style={{ fontSize: '12px', color: colors[strength - 1] }}>
          {labels[strength - 1]}
        </span>
      )}
    </div>
  )
}

export default function SignupPage() {
  const navigate = useNavigate()
  const { signUpWithEmail, clearError } = useAuthStore()

  const [displayName,   setDisplayName]   = useState('')
  const [username,      setUsername]      = useState('')
  const [serialCode,    setSerialCode]    = useState('')
  const [email,         setEmail]         = useState('')
  const [password,      setPassword]      = useState('')
  const [confirmPass,   setConfirmPass]   = useState('')
  const [showPass,      setShowPass]      = useState(false)
  const [showConfirm,   setShowConfirm]   = useState(false)
  const [localError,    setLocalError]    = useState('')
  const [submitting,    setSubmitting]    = useState(false)

  const clearErr = () => setLocalError('')

  // ── Validation ─────────────────────────────────────────────────────────────
  function validate() {
    if (!/^[a-zA-Z0-9_-]{8,80}$/.test(serialCode.trim())) return 'Enter a valid serial code.'
    if (!displayName.trim())          return 'Please enter your display name.'
    if (displayName.trim().length < 2)return 'Display name must be at least 2 characters.'
    if (!/^[a-zA-Z0-9_]{3,20}$/.test(username.trim())) return 'Username must be 3-20 letters, numbers, or underscores.'
    if (!email.trim())                return 'Please enter your email address.'
    if (!/\S+@\S+\.\S+/.test(email))  return 'Please enter a valid email address.'
    if (!password)                    return 'Please enter a password.'
    if (password.length < 6)          return 'Password must be at least 6 characters.'
    if (password !== confirmPass)     return 'Passwords do not match.'
    return null
  }

  // ── Email sign-up ──────────────────────────────────────────────────────────
  async function handleSubmit(e) {
    e.preventDefault()
    clearError()
    const err = validate()
    if (err) return setLocalError(err)

    setSubmitting(true)
    try {
      await signUpWithEmail(email, password, displayName, serialCode, username)
      navigate('/', { replace: true })
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
          maxWidth: '440px',
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
          <p style={{ margin: '8px 0 0', color: 'var(--color-subtext)', fontSize: '15px' }}>
            Create your account
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
          {/* Serial code */}
          <div style={{ marginBottom: '20px' }}>
            <label htmlFor="signup-serial-code" style={labelStyle}>Serial Code</label>
            <input
              id="signup-serial-code"
              type="text"
              autoComplete="off"
              autoCapitalize="characters"
              spellCheck="false"
              placeholder="Enter your one-time code"
              value={serialCode}
              onChange={(e) => { setSerialCode(e.target.value); clearErr() }}
              disabled={isWorking}
              style={inputStyle}
              onFocus={(e) => (e.target.style.borderColor = 'var(--color-button)')}
              onBlur={(e)  => (e.target.style.borderColor = 'transparent')}
            />
          </div>

          {/* Display Name */}
          <div style={{ marginBottom: '20px' }}>
            <label htmlFor="signup-name" style={labelStyle}>Display Name</label>
            <input
              id="signup-name"
              type="text"
              autoComplete="name"
              placeholder="Your name"
              value={displayName}
              onChange={(e) => { setDisplayName(e.target.value); clearErr() }}
              disabled={isWorking}
              style={inputStyle}
              onFocus={(e) => (e.target.style.borderColor = 'var(--color-button)')}
              onBlur={(e)  => (e.target.style.borderColor = 'transparent')}
            />
          </div>

          {/* Username is stored separately from the user's display name. */}
          <div style={{ marginBottom: '20px' }}>
            <label htmlFor="signup-username" style={labelStyle}>Username</label>
            <input
              id="signup-username"
              type="text"
              autoComplete="username"
              autoCapitalize="none"
              autoCorrect="off"
              spellCheck="false"
              maxLength={20}
              placeholder="lowercase_username"
              value={username}
              onChange={(e) => { setUsername(e.target.value); clearErr() }}
              disabled={isWorking}
              style={inputStyle}
              onFocus={(e) => (e.target.style.borderColor = 'var(--color-button)')}
              onBlur={(e)  => (e.target.style.borderColor = 'transparent')}
            />
          </div>

          {/* Email */}
          <div style={{ marginBottom: '20px' }}>
            <label htmlFor="signup-email" style={labelStyle}>Email</label>
            <input
              id="signup-email"
              type="email"
              autoComplete="email"
              placeholder="you@example.com"
              value={email}
              onChange={(e) => { setEmail(e.target.value); clearErr() }}
              disabled={isWorking}
              style={inputStyle}
              onFocus={(e) => (e.target.style.borderColor = 'var(--color-button)')}
              onBlur={(e)  => (e.target.style.borderColor = 'transparent')}
            />
          </div>

          {/* Password */}
          <div style={{ marginBottom: '20px' }}>
            <label htmlFor="signup-password" style={labelStyle}>Password</label>
            <div style={{ position: 'relative' }}>
              <input
                id="signup-password"
                type={showPass ? 'text' : 'password'}
                autoComplete="new-password"
                placeholder="Min. 6 characters"
                value={password}
                onChange={(e) => { setPassword(e.target.value); clearErr() }}
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
            <PasswordStrength password={password} />
          </div>

          {/* Confirm Password */}
          <div style={{ marginBottom: '28px' }}>
            <label htmlFor="signup-confirm" style={labelStyle}>Confirm Password</label>
            <div style={{ position: 'relative' }}>
              <input
                id="signup-confirm"
                type={showConfirm ? 'text' : 'password'}
                autoComplete="new-password"
                placeholder="Repeat your password"
                value={confirmPass}
                onChange={(e) => { setConfirmPass(e.target.value); clearErr() }}
                disabled={isWorking}
                style={{
                  ...inputStyle,
                  paddingRight: '44px',
                  borderColor:
                    confirmPass && confirmPass !== password
                      ? 'var(--color-error)'
                      : 'transparent',
                }}
                onFocus={(e) => {
                  if (!confirmPass || confirmPass === password)
                    e.target.style.borderColor = 'var(--color-button)'
                }}
                onBlur={(e) => {
                  if (!confirmPass || confirmPass === password)
                    e.target.style.borderColor = 'transparent'
                }}
              />
              <button
                type="button"
                onClick={() => setShowConfirm((v) => !v)}
                aria-label={showConfirm ? 'Hide password' : 'Show password'}
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
                {showConfirm ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>
            {confirmPass && confirmPass !== password && (
              <span style={{ fontSize: '12px', color: 'var(--color-error)', marginTop: '4px', display: 'block' }}>
                Passwords do not match
              </span>
            )}
          </div>

          {/* Sign Up button */}
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
            {submitting ? 'Creating account…' : 'Create Account'}
          </button>
        </form>

        <p style={{ textAlign: 'center', margin: 0, fontSize: '14px', color: 'var(--color-subtext)' }}>
          Already have an account?{' '}
          <Link to="/login" style={{ color: 'var(--color-button)', fontWeight: '600', textDecoration: 'none' }}>
            Sign in
          </Link>
        </p>
      </div>
    </div>
  )
}
