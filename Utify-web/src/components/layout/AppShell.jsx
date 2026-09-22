/**
 * AppShell.jsx
 * Root layout component. Renders the 3-column Spotify-style shell:
 *
 *   ┌──────────────────────────────────────────────────────┐
 *   │  TopBar (48px)                                        │
 *   ├──────────┬───────────────────────────┬───────────────┤
 *   │ Sidebar  │  <Outlet /> (main scroll) │ NowPlaying /  │
 *   │  ~240px  │       (flex-grow)         │ QueuePanel    │
 *   │          │                           │  (>=1100px)   │
 *   ├──────────┴───────────────────────────┴───────────────┤
 *   │  PlayerBar (80px, bottom of flex column)              │
 *   └──────────────────────────────────────────────────────┘
 *
 * Navigation history (back / forward) is managed here and surfaced via
 * NavigationContext so TopBar can read canGoBack/canGoForward and call
 * goBack() / goForward() without prop-drilling.
 *
 * Placeholder sub-components (Sidebar, PlayerBar, NowPlayingPanel,
 * RemotePlaybackBanner) are defined here so AppShell compiles while the real
 * feature components are being built.  Replace the placeholders with real
 * imports once each component exists.
 */

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
} from 'react'
import { Outlet, useLocation, useNavigate } from 'react-router-dom'
import { usePlayerStore, PanelMode } from '../../stores/playerStore'
import { useYouTubePlayer } from '../../hooks/useYouTubePlayer'
import { useSyncSession } from '../../hooks/useSyncSession'
import TopBar from './TopBar'
import Sidebar from './Sidebar'
import PlayerBar from '../player/PlayerBar'
import NowPlayingPanel from '../player/NowPlayingPanel'
import QueuePanel from '../player/QueuePanel'
import LyricsPanel from '../player/LyricsPanel'
import RemotePlaybackBanner from '../sync/RemotePlaybackBanner'

// ── OfflineIndicator ──────────────────────────────────────────────────────────
// Orange pill that appears just above the PlayerBar when the browser goes offline.

function OfflineIndicator() {
  const [offline, setOffline] = useState(!navigator.onLine)

  useEffect(() => {
    const onOnline  = () => setOffline(false)
    const onOffline = () => setOffline(true)
    window.addEventListener('online',  onOnline)
    window.addEventListener('offline', onOffline)
    return () => {
      window.removeEventListener('online',  onOnline)
      window.removeEventListener('offline', onOffline)
    }
  }, [])

  if (!offline) return null

  return (
    <div
      role="status"
      aria-live="polite"
      style={{
        position:      'fixed',
        bottom:        88,       // 80px PlayerBar + 8px gap
        left:          '50%',
        transform:     'translateX(-50%)',
        background:    '#E65100',
        color:         '#fff',
        padding:       '6px 16px',
        borderRadius:  20,
        fontSize:      13,
        fontWeight:    600,
        zIndex:        200,
        pointerEvents: 'none',
        boxShadow:     '0 2px 8px rgba(0,0,0,0.4)',
        whiteSpace:    'nowrap',
      }}
    >
      Offline — changes will sync when reconnected
    </div>
  )
}

// ── NavigationContext ─────────────────────────────────────────────────────────
// Shared context that TopBar consumes for back/forward state & actions.

export const NavigationContext = createContext({
  canGoBack:    false,
  canGoForward: false,
  goBack:       () => {},
  goForward:    () => {},
  /** 'home' | 'search' | <playlistId> */
  currentView:  'home',
})

/** Hook for child components that need navigation context. */
export function useNavigationContext() {
  return useContext(NavigationContext)
}

// ── Responsive viewport width hook ───────────────────────────────────────────

function useViewportWidth() {
  const [width, setWidth] = useState(window.innerWidth)
  useEffect(() => {
    const handler = () => setWidth(window.innerWidth)
    window.addEventListener('resize', handler)
    return () => window.removeEventListener('resize', handler)
  }, [])
  return width
}

// ── AppShell ──────────────────────────────────────────────────────────────────

export default function AppShell() {
  const { isThisDeviceActive } = useSyncSession() // mount sync hook
  
  const navigate  = useNavigate()
  const location  = useLocation()
  const viewportW = useViewportWidth()
  const panelMode = usePlayerStore((s) => s.panelMode)

  // ── Navigation history stack ────────────────────────────────────────────
  // React Router's window.history.length is relative to the full browser
  // session, not just our app.  We keep our own stack so back/forward buttons
  // are disabled accurately.

  const historyRef    = useRef([location.pathname + location.search])
  const historyIdxRef = useRef(0)
  const [navState, setNavState] = useState({ canGoBack: false, canGoForward: false })

  // skipPushRef prevents double-pushes when goBack/goForward triggers a
  // location change that the useEffect below would otherwise also push.
  const skipPushRef = useRef(false)

  useEffect(() => {
    if (skipPushRef.current) {
      skipPushRef.current = false
      return
    }

    const path     = location.pathname + location.search
    const stack    = historyRef.current
    const idx      = historyIdxRef.current
    const newStack = [...stack.slice(0, idx + 1), path]

    historyRef.current    = newStack
    historyIdxRef.current = newStack.length - 1

    setNavState({
      canGoBack:    historyIdxRef.current > 0,
      canGoForward: historyIdxRef.current < historyRef.current.length - 1,
    })
  }, [location])

  const goBack = useCallback(() => {
    if (historyIdxRef.current <= 0) return
    skipPushRef.current    = true
    historyIdxRef.current -= 1
    const path = historyRef.current[historyIdxRef.current]
    setNavState({
      canGoBack:    historyIdxRef.current > 0,
      canGoForward: historyIdxRef.current < historyRef.current.length - 1,
    })
    navigate(path)
  }, [navigate])

  const goForward = useCallback(() => {
    if (historyIdxRef.current >= historyRef.current.length - 1) return
    skipPushRef.current    = true
    historyIdxRef.current += 1
    const path = historyRef.current[historyIdxRef.current]
    setNavState({
      canGoBack:    historyIdxRef.current > 0,
      canGoForward: historyIdxRef.current < historyRef.current.length - 1,
    })
    navigate(path)
  }, [navigate])

  // Derive a semantic view label from the current route
  const currentView = (() => {
    const p = location.pathname
    if (p === '/' || p === '/home')     return 'home'
    if (p.startsWith('/search'))        return 'search'
    if (p.startsWith('/playlist/'))     return p.replace('/playlist/', '')
    return 'home'
  })()

  // ── YouTube IFrame API ──────────────────────────────────────────────────
  // The hook drives the hidden #yt-player div defined below.
  useYouTubePlayer()

  // ── Right panel ─────────────────────────────────────────────────────────
  // Only show on wide viewports (>=1100px) when a panel mode is active.
  const showRightPanel = viewportW >= 1100 && panelMode !== PanelMode.NONE

  // ── Layout styles ────────────────────────────────────────────────────────

  const shellStyle = {
    display:       'flex',
    flexDirection: 'column',
    height:        '100dvh',
    overflow:      'hidden',
    background:    'var(--color-main)',
    color:         'var(--color-text)',
  }

  const bodyRowStyle = {
    display:   'flex',
    flexGrow:  1,
    gap:       8,
    marginBottom: 8,
    overflow:  'hidden',   // each column scrolls independently
    minHeight: 0,           // allow shrink below content size (flex gotcha)
  }

  const mainContentStyle = {
    flexGrow:  1,
    overflowY: 'auto',
    overflowX: 'hidden',
    background:'var(--color-main)',
    borderRadius: 12,
    minWidth:  0,           // prevent flex blowout on long content
  }

  // ── Render ───────────────────────────────────────────────────────────────

  return (
    <NavigationContext.Provider
      value={{
        canGoBack:    navState.canGoBack,
        canGoForward: navState.canGoForward,
        goBack,
        goForward,
        currentView,
      }}
    >
      {/*
        Hidden YouTube IFrame anchor.
        The YT IFrame API replaces this div with an <iframe>.
        It must exist in the DOM before useYouTubePlayer initialises.
        Positioned off-screen so it is invisible and layout-inert.
      */}
      <div
        id="yt-player"
        aria-hidden="true"
        style={{
          position:      'absolute',
          top:           -9999,
          left:          -9999,
          width:         1,
          height:        1,
          overflow:      'hidden',
          pointerEvents: 'none',
        }}
      />

      <div style={shellStyle}>
        {/* ── 1. Top bar — 48px ── */}
        <TopBar />

        {/* ── 2. Body row: Sidebar | Main content | Right panel ── */}
        <div style={bodyRowStyle}>
          {/* Left: navigation sidebar */}
          <Sidebar />

          {/* Center: route content via React Router Outlet */}
          <main
            id="main-content"
            tabIndex={-1}          /* skip-to-content anchor target */
            style={mainContentStyle}
          >
            <Outlet />
          </main>

          {/* Right: NowPlaying / Queue (wide viewports + active panel) */}
          {showRightPanel && panelMode === PanelMode.QUEUE        && <QueuePanel />}
          {showRightPanel && panelMode === PanelMode.NOW_PLAYING  && <NowPlayingPanel />}
          {showRightPanel && panelMode === PanelMode.LYRICS       && <LyricsPanel />}
        </div>

        {/* ── 3. Player bar — 80px ── */}
        <PlayerBar />
      </div>

      {/* ── Global floating overlays ── */}
      <RemotePlaybackBanner />
      <OfflineIndicator />
    </NavigationContext.Provider>
  )
}
