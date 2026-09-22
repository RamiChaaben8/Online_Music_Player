/**
 * SettingsPage.jsx
 * Mirrors privacy_settings_screen.dart + theme picker + account management.
 * Sections:
 *   1. Profile — edit displayName
 *   2. Privacy — presence visibility toggles
 *   3. Theme — 10-theme grid with live previews
 *   4. Account — change password link, delete account (with confirmation)
 * All styling via CSS variables from index.css.
 */

import { useCallback, useEffect, useRef, useState } from 'react'
import {
  updateProfile,
  updatePassword,
  sendPasswordResetEmail,
  EmailAuthProvider,
  reauthenticateWithCredential,
} from 'firebase/auth'
import { doc, updateDoc, getDoc } from 'firebase/firestore'
import { auth } from '../firebase'
import { db } from '../firebase'
import { useAuthStore } from '../stores/authStore'
import { useThemeStore, THEMES } from '../stores/themeStore'

// ── Helpers ───────────────────────────────────────────────────────────────────
function SectionTitle({ children }) {
  return (
    <h2
      style={{
        fontSize: 11,
        fontWeight: 700,
        letterSpacing: '0.12em',
        textTransform: 'uppercase',
        color: 'var(--color-subtext)',
        margin: '0 0 14px',
      }}
    >
      {children}
    </h2>
  )
}

function Card({ children, style }) {
  return (
    <div
      style={{
        background: 'var(--color-card)',
        borderRadius: 10,
        padding: '20px 20px',
        marginBottom: 24,
        ...style,
      }}
    >
      {children}
    </div>
  )
}

function Toast({ message, type = 'info', onClose }) {
  useEffect(() => {
    if (!message) return
    const t = setTimeout(onClose, 4000)
    return () => clearTimeout(t)
  }, [message, onClose])
  if (!message) return null
  const bg = type === 'error' ? 'var(--color-error)' : 'var(--color-card)'
  return (
    <div
      role="status"
      aria-live="polite"
      style={{
        position: 'fixed',
        bottom: 96,
        left: '50%',
        transform: 'translateX(-50%)',
        background: bg,
        color: '#fff',
        padding: '10px 20px',
        borderRadius: 8,
        fontSize: 14,
        boxShadow: '0 4px 16px rgba(0,0,0,0.4)',
        zIndex: 400,
        whiteSpace: 'nowrap',
        maxWidth: 'calc(100vw - 48px)',
      }}
    >
      {message}
    </div>
  )
}

function Spinner({ size = 18 }) {
  return (
    <>
      <div
        aria-hidden="true"
        style={{
          width: size,
          height: size,
          borderRadius: '50%',
          border: `2px solid rgba(255,255,255,0.3)`,
          borderTopColor: '#fff',
          animation: 'utify-spin 0.7s linear infinite',
          flexShrink: 0,
        }}
      />
      <style>{`@keyframes utify-spin { to { transform: rotate(360deg); } }`}</style>
    </>
  )
}

// ── Confirm dialog ────────────────────────────────────────────────────────────
function ConfirmDialog({ title, message, onConfirm, onCancel, confirmLabel = 'Confirm', danger = false, loading = false, children }) {
  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="confirm-dialog-title"
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(0,0,0,0.7)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 500,
        padding: 24,
      }}
      onClick={(e) => { if (e.target === e.currentTarget) onCancel() }}
    >
      <div
        style={{
          background: 'var(--color-card)',
          borderRadius: 14,
          padding: '28px 28px 24px',
          width: '100%',
          maxWidth: 440,
          boxShadow: '0 12px 48px rgba(0,0,0,0.6)',
        }}
      >
        {title && (
          <h3 id="confirm-dialog-title" style={{ margin: '0 0 12px', fontSize: 18, fontWeight: 800 }}>
            {title}
          </h3>
        )}
        {message && <p style={{ margin: '0 0 20px', fontSize: 15, color: 'var(--color-subtext)', lineHeight: 1.55 }}>{message}</p>}
        {children}
        <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end', marginTop: 20 }}>
          <button
            onClick={onCancel}
            disabled={loading}
            style={{
              padding: '9px 20px',
              borderRadius: 20,
              border: '1px solid var(--color-highlight-elevated)',
              background: 'none',
              color: 'var(--color-text)',
              fontWeight: 600,
              fontSize: 14,
              cursor: loading ? 'default' : 'pointer',
              opacity: loading ? 0.6 : 1,
            }}
          >
            Cancel
          </button>
          <button
            onClick={onConfirm}
            disabled={loading}
            autoFocus
            style={{
              padding: '9px 20px',
              borderRadius: 20,
              border: 'none',
              background: danger ? 'var(--color-error)' : 'var(--color-button)',
              color: '#fff',
              fontWeight: 700,
              fontSize: 14,
              cursor: loading ? 'default' : 'pointer',
              opacity: loading ? 0.7 : 1,
              display: 'flex',
              alignItems: 'center',
              gap: 8,
            }}
          >
            {loading && <Spinner size={14} />}
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  )
}

// ── 1. Profile section ────────────────────────────────────────────────────────
function ProfileSection({ user, onToast }) {
  const [displayName, setDisplayName] = useState(user?.displayName || '')
  const [saving, setSaving] = useState(false)
  const dirty = displayName.trim() !== (user?.displayName || '')

  const handleSave = async () => {
    if (!dirty || !user) return
    setSaving(true)
    try {
      await updateProfile(auth.currentUser, { displayName: displayName.trim() })
      // Also update publicProfile doc
      await updateDoc(doc(db, 'publicProfiles', user.uid), {
        displayName: displayName.trim(),
      })
      onToast('Display name updated.')
    } catch (e) {
      onToast(`Could not update: ${e.message}`, 'error')
    } finally {
      setSaving(false)
    }
  }

  return (
    <Card>
      <SectionTitle>Profile</SectionTitle>

      <label
        htmlFor="setting-displayname"
        style={{ display: 'block', fontSize: 13, color: 'var(--color-subtext)', marginBottom: 6, fontWeight: 600 }}
      >
        Display Name
      </label>
      <div style={{ display: 'flex', gap: 10 }}>
        <input
          id="setting-displayname"
          type="text"
          value={displayName}
          maxLength={50}
          onChange={(e) => setDisplayName(e.target.value)}
          style={{
            flexGrow: 1,
            padding: '10px 14px',
            borderRadius: 6,
            border: '1px solid var(--color-highlight-elevated)',
            background: 'var(--color-highlight)',
            color: 'var(--color-text)',
            fontSize: 15,
            outline: 'none',
          }}
        />
        <button
          onClick={handleSave}
          disabled={!dirty || saving}
          style={{
            padding: '10px 18px',
            borderRadius: 6,
            border: 'none',
            background: 'var(--color-button)',
            color: '#fff',
            fontWeight: 700,
            fontSize: 14,
            cursor: !dirty || saving ? 'default' : 'pointer',
            opacity: !dirty || saving ? 0.5 : 1,
            display: 'flex',
            alignItems: 'center',
            gap: 6,
            flexShrink: 0,
          }}
        >
          {saving && <Spinner size={14} />}
          Save
        </button>
      </div>

      <p style={{ margin: '8px 0 0', fontSize: 12, color: 'var(--color-subtext)' }}>
        Email: {user?.email || '—'}
      </p>
    </Card>
  )
}

// ── 2. Privacy section ────────────────────────────────────────────────────────
function PrivacySection({ user, onToast }) {
  const [privacy, setPrivacy] = useState({
    showOnlineStatus: true,
    showActivity: true,
    allowFriendRequests: true,
  })
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!user?.uid) return
    getDoc(doc(db, 'publicProfiles', user.uid))
      .then((snap) => {
        if (snap.exists()) {
          const p = snap.data().privacy
          if (p && typeof p === 'object') setPrivacy((prev) => ({ ...prev, ...p }))
        }
        setLoading(false)
      })
      .catch(() => setLoading(false))
  }, [user?.uid])

  const handleToggle = async (key, value) => {
    const prev = privacy
    const next = { ...prev, [key]: value }
    setPrivacy(next)
    try {
      await updateDoc(doc(db, 'publicProfiles', user.uid), { privacy: next })
    } catch (e) {
      setPrivacy(prev)
      onToast('Could not update privacy settings.', 'error')
    }
  }

  const toggles = [
    { key: 'showOnlineStatus', label: 'Show my online status', sub: "Friends can see when you're online." },
    { key: 'showActivity',     label: "Show what I'm listening to", sub: 'Friends can see your current track.' },
    { key: 'allowFriendRequests', label: 'Allow friend requests', sub: 'Let other users send you friend requests.' },
  ]

  return (
    <Card>
      <SectionTitle>Privacy</SectionTitle>
      {loading ? (
        <div style={{ display: 'flex', justifyContent: 'center', padding: 16 }}>
          <Spinner size={24} />
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 0 }}>
          {toggles.map(({ key, label, sub }, i) => (
            <label
              key={key}
              htmlFor={`privacy-${key}`}
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                gap: 16,
                padding: '14px 0',
                borderBottom: i < toggles.length - 1 ? '1px solid var(--color-highlight)' : 'none',
                cursor: 'pointer',
              }}
            >
              <div>
                <div style={{ fontWeight: 600, fontSize: 14, marginBottom: 2 }}>{label}</div>
                <div style={{ fontSize: 12, color: 'var(--color-subtext)' }}>{sub}</div>
              </div>
              {/* Toggle switch */}
              <div
                id={`privacy-${key}`}
                role="switch"
                aria-checked={privacy[key]}
                tabIndex={0}
                onClick={() => handleToggle(key, !privacy[key])}
                onKeyDown={(e) => { if (e.key === ' ' || e.key === 'Enter') { e.preventDefault(); handleToggle(key, !privacy[key]) } }}
                style={{
                  width: 44,
                  height: 24,
                  borderRadius: 12,
                  background: privacy[key] ? 'var(--color-button)' : 'var(--color-highlight-elevated)',
                  position: 'relative',
                  transition: 'background 0.2s',
                  flexShrink: 0,
                  cursor: 'pointer',
                }}
              >
                <span
                  style={{
                    position: 'absolute',
                    top: 2,
                    left: privacy[key] ? 22 : 2,
                    width: 20,
                    height: 20,
                    borderRadius: '50%',
                    background: '#fff',
                    transition: 'left 0.2s',
                    boxShadow: '0 1px 4px rgba(0,0,0,0.3)',
                  }}
                />
              </div>
            </label>
          ))}
        </div>
      )}
    </Card>
  )
}

// ── 3. Theme section ──────────────────────────────────────────────────────────
// Colour swatches extracted from index.css theme variable sets
const THEME_PREVIEWS = {
  'green':                  { bg: '#0F0F0F', accent: '#1DB954', text: '#FFFFFF' },
  'red':                    { bg: '#0D0808', accent: '#E8173A', text: '#FFFFFF' },
  'dribbblish-white':       { bg: '#F5F7FA', accent: '#2E7DDE', text: '#17202A' },
  'catppuccin-latte':       { bg: '#EFF1F5', accent: '#1E66F5', text: '#4C4F69' },
  'nord':                   { bg: '#2E3440', accent: '#88C0D0', text: '#ECEFF4' },
  'dracula':                { bg: '#282A36', accent: '#BD93F9', text: '#F8F8F2' },
  'dreary-bib':             { bg: '#202020', accent: '#537B25', text: '#8BC34A' },
  'dreary-deeper':          { bg: '#040614', accent: '#0D3A2E', text: '#4F9A87' },
  'gruvbox-material-dark':  { bg: '#1D2021', accent: '#98971A', text: '#FFDAB9' },
  'onepunch-dark':          { bg: '#1D2021', accent: '#8EC07C', text: '#D5C4A1' },
}

function ThemeSection() {
  const { themeId, setTheme } = useThemeStore()

  return (
    <Card>
      <SectionTitle>Theme</SectionTitle>
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fill, minmax(120px, 1fr))',
          gap: 12,
        }}
      >
        {THEMES.map((theme) => {
          const preview = THEME_PREVIEWS[theme.id] || { bg: '#121212', accent: '#1DB954', text: '#fff' }
          const active = themeId === theme.id
          return (
            <button
              key={theme.id}
              onClick={() => setTheme(theme.id)}
              aria-pressed={active}
              aria-label={`Select ${theme.name} theme`}
              style={{
                padding: 0,
                border: active ? `2px solid ${preview.accent}` : '2px solid transparent',
                borderRadius: 10,
                cursor: 'pointer',
                background: 'none',
                outline: active ? `3px solid ${preview.accent}44` : 'none',
                outlineOffset: 2,
                transition: 'border-color 0.15s, outline 0.15s',
              }}
            >
              {/* Mini preview card */}
              <div
                style={{
                  background: preview.bg,
                  borderRadius: 8,
                  overflow: 'hidden',
                  height: 76,
                  display: 'flex',
                  flexDirection: 'column',
                  justifyContent: 'flex-end',
                }}
              >
                {/* Fake player bar */}
                <div
                  style={{
                    background: `${preview.accent}22`,
                    height: 20,
                    display: 'flex',
                    alignItems: 'center',
                    paddingLeft: 6,
                    gap: 4,
                  }}
                >
                  <div style={{ width: 10, height: 10, borderRadius: '50%', background: preview.accent }} />
                  <div style={{ flexGrow: 1, height: 3, borderRadius: 2, background: preview.accent, opacity: 0.5 }} />
                </div>
                {/* Accent stripe */}
                <div style={{ height: 4, background: preview.accent }} />
              </div>
              {/* Label */}
              <div
                style={{
                  padding: '6px 4px',
                  fontSize: 11,
                  fontWeight: active ? 700 : 500,
                  color: active ? 'var(--color-text)' : 'var(--color-subtext)',
                  textAlign: 'center',
                  letterSpacing: '0.01em',
                  lineHeight: 1.3,
                  background: 'var(--color-card)',
                  borderBottomLeftRadius: 8,
                  borderBottomRightRadius: 8,
                }}
              >
                {theme.name}
              </div>
            </button>
          )
        })}
      </div>
    </Card>
  )
}

// ── 4. Account section ────────────────────────────────────────────────────────
function AccountSection({ user, onToast }) {
  const deleteAccount = useAuthStore((s) => s.deleteAccount)
  const [showDeleteDialog, setShowDeleteDialog] = useState(false)
  const [deleteLoading, setDeleteLoading] = useState(false)
  const [deleteError, setDeleteError] = useState('')
  const [password, setPassword] = useState('')

  const handleDeleteConfirm = async () => {
    setDeleteError('')
    setDeleteLoading(true)
    try {
      // Re-authenticate for email/password providers
      const provider = user?.providerData?.[0]?.providerId
      if (provider === 'password') {
        if (!password) {
          setDeleteError('Please enter your password to confirm.')
          setDeleteLoading(false)
          return
        }
        const credential = EmailAuthProvider.credential(user.email, password)
        await reauthenticateWithCredential(auth.currentUser, credential)
      }
      await deleteAccount()
      // Auth state change will redirect to /login via AuthGate
    } catch (e) {
      if (e.code === 'auth/wrong-password' || e.code === 'auth/invalid-credential') {
        setDeleteError('Incorrect password. Please try again.')
      } else {
        setDeleteError(e.message || 'Could not delete account.')
      }
      setDeleteLoading(false)
    }
  }

  const handleSendReset = async () => {
    try {
      await sendPasswordResetEmail(auth, user.email)
      onToast('Password reset email sent.')
    } catch (e) {
      onToast('Could not send reset email. Try again.', 'error')
    }
  }

  const isEmailProvider = user?.providerData?.some((p) => p.providerId === 'password')

  return (
    <Card>
      <SectionTitle>Account</SectionTitle>

      {isEmailProvider && (
        <div style={{ marginBottom: 20 }}>
          <div style={{ fontWeight: 600, fontSize: 14, marginBottom: 4 }}>Password</div>
          <p style={{ margin: '0 0 10px', fontSize: 13, color: 'var(--color-subtext)' }}>
            Send a password reset link to {user?.email}.
          </p>
          <button
            onClick={handleSendReset}
            style={{
              padding: '8px 16px',
              borderRadius: 6,
              border: '1px solid var(--color-highlight-elevated)',
              background: 'none',
              color: 'var(--color-text)',
              fontWeight: 600,
              fontSize: 13,
              cursor: 'pointer',
            }}
          >
            Send Reset Email
          </button>
        </div>
      )}

      <div style={{ borderTop: '1px solid var(--color-highlight)', paddingTop: 20 }}>
        <div style={{ fontWeight: 600, fontSize: 14, marginBottom: 4 }}>Delete Account</div>
        <p style={{ margin: '0 0 12px', fontSize: 13, color: 'var(--color-subtext)' }}>
          Permanently deletes your account and all data. This is irreversible.
        </p>
        <button
          onClick={() => { setShowDeleteDialog(true); setDeleteError(''); setPassword('') }}
          style={{
            padding: '8px 16px',
            borderRadius: 6,
            border: '1px solid var(--color-error)',
            background: 'none',
            color: 'var(--color-error)',
            fontWeight: 700,
            fontSize: 13,
            cursor: 'pointer',
          }}
        >
          Delete Account
        </button>
      </div>

      {showDeleteDialog && (
        <ConfirmDialog
          title="Delete Account"
          message="This will permanently delete your account, playlists, and all data. This action cannot be undone."
          confirmLabel={deleteLoading ? 'Deleting…' : 'Delete My Account'}
          danger
          loading={deleteLoading}
          onConfirm={handleDeleteConfirm}
          onCancel={() => { setShowDeleteDialog(false); setDeleteError('') }}
        >
          {isEmailProvider && (
            <div style={{ marginTop: 4, marginBottom: 4 }}>
              <label
                htmlFor="delete-confirm-password"
                style={{ display: 'block', fontSize: 13, color: 'var(--color-subtext)', marginBottom: 6 }}
              >
                Enter your password to confirm:
              </label>
              <input
                id="delete-confirm-password"
                type="password"
                value={password}
                onChange={(e) => { setPassword(e.target.value); setDeleteError('') }}
                placeholder="Your password"
                autoFocus
                style={{
                  width: '100%',
                  padding: '10px 12px',
                  borderRadius: 6,
                  border: deleteError ? '1px solid var(--color-error)' : '1px solid var(--color-highlight-elevated)',
                  background: 'var(--color-highlight)',
                  color: 'var(--color-text)',
                  fontSize: 14,
                  outline: 'none',
                  boxSizing: 'border-box',
                }}
              />
              {deleteError && (
                <p style={{ color: 'var(--color-error)', fontSize: 12, margin: '6px 0 0' }}>{deleteError}</p>
              )}
            </div>
          )}
        </ConfirmDialog>
      )}
    </Card>
  )
}

// ── Main SettingsPage ─────────────────────────────────────────────────────────
export default function SettingsPage() {
  const user = useAuthStore((s) => s.user)
  const [toast, setToast] = useState('')
  const [toastType, setToastType] = useState('info')

  const onToast = useCallback((msg, type = 'info') => {
    setToast(msg)
    setToastType(type)
  }, [])

  return (
    <div
      style={{
        maxWidth: 680,
        margin: '0 auto',
        padding: '32px 24px 48px',
        color: 'var(--color-text)',
      }}
    >
      <h1 style={{ margin: '0 0 32px', fontSize: 28, fontWeight: 800 }}>Settings</h1>

      <ProfileSection user={user} onToast={onToast} />
      <PrivacySection user={user} onToast={onToast} />
      <ThemeSection />
      <AccountSection user={user} onToast={onToast} />

      <Toast message={toast} type={toastType} onClose={() => setToast('')} />
    </div>
  )
}
