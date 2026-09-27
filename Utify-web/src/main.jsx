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

function AdminGate({ children }) {
  const user = useAuthStore((s) => s.user)
  const loading = useAuthStore((s) => s.loading)
  const [checking, setChecking] = useState(true)
  const [isAdmin, setIsAdmin] = useState(false)

  useEffect(() => {
    let active = true
    if (loading) return () => { active = false }
    if (!user) {
      setChecking(false)
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
  }, [user, loading])

  if (loading || (user && checking)) return <div style={{ minHeight: '100vh', background: 'var(--color-main)' }} />
  if (!user) return <Navigate to="/login" replace />
  if (!isAdmin) return <Navigate to="/" replace />
  return children
}

// Root app component — subscribes to auth and initialises library
function App() {
  const { init: initAuth, user } = useAuthStore()
  const { init: initLibrary, destroy: destroyLibrary } = useLibraryStore()

  // Subscribe to Firebase auth state once on mount
  useEffect(() => {
    const unsubscribe = initAuth()
    return () => unsubscribe?.()
  }, [initAuth])

  // When user changes, subscribe/unsubscribe library Firestore listeners
  useEffect(() => {
    if (user?.uid) {
      initLibrary(user.uid)
    } else {
      destroyLibrary()
    }
  }, [user?.uid, initLibrary, destroyLibrary])

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
          <Route path="friends"         element={<FriendsView />} />
          <Route path="friends/:uid"    element={<FriendProfileView />} />
          <Route path="settings"        element={<SettingsPage />} />
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
