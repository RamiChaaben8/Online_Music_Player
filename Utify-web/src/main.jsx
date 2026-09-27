import { StrictMode, useEffect, useState } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import './index.css'

import { useAuthStore } from './stores/authStore'
import { useLibraryStore } from './stores/libraryStore'

// Layout
import AppShell from './components/layout/AppShell'

// Auth
import AuthGate from './pages/auth/AuthGate'
import LoginPage from './pages/auth/LoginPage'
import SignupPage from './pages/auth/SignupPage'
import ForgotPasswordPage from './pages/auth/ForgotPasswordPage'

// Views
import HomeView from './pages/HomeView'
import SearchView from './pages/SearchView'
import PlaylistView from './pages/PlaylistView'
import LikedSongsView from './pages/LikedSongsView'
import FriendsView from './pages/FriendsView'
import FriendProfileView from './pages/FriendProfileView'
import SettingsPage from './pages/SettingsPage'
import AdminDashboard from './pages/AdminDashboard'

function AccountOnly({ children }) {
  const isGuest = useAuthStore((s) => s.isGuest)
  return isGuest ? <Navigate to="/" replace /> : children
}

function AdminGate({ children }) {
  const user = useAuthStore((s) => s.user)
  const isGuest = useAuthStore((s) => s.isGuest)
  const loading = useAuthStore((s) => s.loading)
  const [checking, setChecking] = useState(true)
  const [isAdmin, setIsAdmin] = useState(false)

  useEffect(() => {
    let active = true
    if (loading) return () => { active = false }
    if (!user || isGuest) {
      setChecking(false)
      setIsAdmin(false)
      return () => { active = false }
    }
    setChecking(true)
    user.getIdTokenResult().then((token) => {
      if (active) setIsAdmin(token.claims.admin === true || token.claims.role === 'admin')
    }).catch(() => {
      if (active) setIsAdmin(false)
    }).finally(() => {
      if (active) setChecking(false)
    })
    return () => { active = false }
  }, [user, loading, isGuest])

  if (loading || (user && checking)) return <div style={{ minHeight: '100vh', background: 'var(--color-main)' }} />
  if (!user || isGuest) return <Navigate to={isGuest ? '/' : '/login'} replace />
  if (!isAdmin) return <Navigate to="/" replace />
  return children
}

// Root app component — subscribes to auth and initialises library
function App() {
  const { init: initAuth, user, isGuest } = useAuthStore()
  const { init: initLibrary, destroy: destroyLibrary } = useLibraryStore()

  // Subscribe to Firebase auth state once on mount
  useEffect(() => {
    const unsubscribe = initAuth()
    return () => unsubscribe?.()
  }, [initAuth])

  // When user changes, subscribe/unsubscribe library Firestore listeners
  useEffect(() => {
    if (isGuest) {
      initLibrary(null)
    } else if (user?.uid) {
      initLibrary(user.uid)
    } else {
      destroyLibrary()
    }
  }, [user?.uid, isGuest, initLibrary, destroyLibrary])

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/admin" element={<AdminGate><AdminDashboard /></AdminGate>} />
        {/* Public routes — no auth required */}
        <Route path="/login"           element={<LoginPage />} />
        <Route path="/signup"          element={<SignupPage />} />
        <Route path="/forgot-password" element={<ForgotPasswordPage />} />

        {/* Protected routes — wrapped in AuthGate + AppShell */}
        <Route
          path="/"
          element={
            <AuthGate>
              <AppShell />
            </AuthGate>
          }
        >
          <Route index element={<HomeView />} />
          <Route path="search"          element={<SearchView />} />
          <Route path="playlist/:id"    element={<PlaylistView />} />
          <Route path="liked-songs"     element={<LikedSongsView />} />
          <Route path="friends"         element={<AccountOnly><FriendsView /></AccountOnly>} />
          <Route path="friends/:uid"    element={<AccountOnly><FriendProfileView /></AccountOnly>} />
          <Route path="settings"        element={<AccountOnly><SettingsPage /></AccountOnly>} />
        </Route>

        {/* Catch-all */}
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  )
}

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
