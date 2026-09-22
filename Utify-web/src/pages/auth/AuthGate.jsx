import { useEffect } from 'react'
import { Navigate } from 'react-router-dom'
import { useAuthStore } from '../../stores/authStore'

// Shown while Firebase resolves auth state on first load
function LoadingSpinner() {
  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        height: '100vh',
        backgroundColor: 'var(--color-main)',
        gap: '20px',
      }}
    >
      {/* Animated ring spinner */}
      <div
        style={{
          width: '48px',
          height: '48px',
          borderRadius: '50%',
          border: '4px solid var(--color-highlight)',
          borderTopColor: 'var(--color-button)',
          animation: 'utify-spin 0.8s linear infinite',
        }}
      />
      <span style={{ color: 'var(--color-subtext)', fontSize: '14px', letterSpacing: '0.05em' }}>
        Loading…
      </span>

      {/* Keyframe injected inline — only once since AuthGate mounts once */}
      <style>{`
        @keyframes utify-spin {
          to { transform: rotate(360deg); }
        }
      `}</style>
    </div>
  )
}

/**
 * AuthGate — wraps protected routes.
 *
 * • While Firebase is resolving the auth state (`loading === true`), shows a
 *   full-screen spinner so children never flash before auth is known.
 * • If unauthenticated, redirects to /login (replacing history so the back
 *   button doesn't loop).
 * • If authenticated, renders children normally.
 */
export default function AuthGate({ children }) {
  const user    = useAuthStore((s) => s.user)
  const loading = useAuthStore((s) => s.loading)
  const init    = useAuthStore((s) => s.init)

  // Subscribe to onAuthStateChanged exactly once.
  // The unsubscribe function returned by init() is cleaned up on unmount.
  useEffect(() => {
    const unsubscribe = init()
    return () => {
      if (typeof unsubscribe === 'function') unsubscribe()
    }
  }, [init])

  if (loading) return <LoadingSpinner />
  if (!user)   return <Navigate to="/login" replace />

  return children
}
