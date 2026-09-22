/**
 * RemotePlaybackBanner.jsx
 *
 * Slide-in banner shown when another device is actively playing the user's
 * session.  Mirrors the "Playing on [device] — Continue here?" banner from
 * the Flutter app.
 *
 * Uses useRemotePlayback() from useSyncSession to detect the remote device
 * and expose claimHere().
 *
 * Positioning: fixed at the top of the viewport, centred horizontally,
 * so it appears above the main content area regardless of layout.
 */

import { useEffect, useRef, useState } from 'react'
import { useRemotePlayback } from '../../hooks/useSyncSession'
import { useAuthStore } from '../../stores/authStore'

export default function RemotePlaybackBanner() {
  const user = useAuthStore((s) => s.user)

  // Only render anything when the user is signed in
  if (!user) return null

  return <BannerInner />
}

// Inner component so we don't call useSyncSession hooks when not signed in

function BannerInner() {
  const { remoteDevice, claimHere } = useRemotePlayback()

  // ── Visibility with a short debounce so it doesn't flash on init ──────────
  const [visible, setVisible]   = useState(false)
  const [claiming, setClaiming] = useState(false)
  const debounceRef             = useRef(null)

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current)

    if (remoteDevice) {
      // Short delay prevents a flash when devices list first loads
      debounceRef.current = setTimeout(() => setVisible(true), 600)
    } else {
      debounceRef.current = setTimeout(() => setVisible(false), 300)
    }

    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current)
    }
  }, [remoteDevice])

  const handleClaim = async () => {
    setClaiming(true)
    try {
      await claimHere()
    } finally {
      setClaiming(false)
    }
  }

  // Render the element at all times but control opacity + transform for the
  // animation so the browser can transition it smoothly.
  const deviceName = remoteDevice?.name ?? 'another device'

  return (
    <>
      <style>{`
        @keyframes rpSlideDown {
          from { opacity: 0; transform: translate(-50%, -12px); }
          to   { opacity: 1; transform: translate(-50%, 0); }
        }
      `}</style>

      <div
        role="status"
        aria-live="polite"
        aria-atomic="true"
        style={{
          position:      'fixed',
          top:            72,          // 48px TopBar + 24px gap
          left:          '50%',
          transform:     'translateX(-50%)',
          zIndex:         400,
          display:        'flex',
          alignItems:     'center',
          gap:             10,
          background:     'var(--color-card)',
          border:         '1px solid var(--color-highlight-elevated)',
          borderRadius:   32,
          padding:        '8px 8px 8px 16px',
          boxShadow:      '0 4px 20px rgba(0,0,0,0.45)',
          pointerEvents:  visible ? 'auto' : 'none',
          // Animate in/out
          opacity:        visible ? 1 : 0,
          transition:     'opacity 0.3s ease',
          animation:      visible ? 'rpSlideDown 0.35s ease forwards' : 'none',
          whiteSpace:     'nowrap',
          maxWidth:       'calc(100vw - 32px)',
        }}
      >
        {/* Pulsing dot */}
        <span
          aria-hidden="true"
          style={{
            display:      'inline-block',
            width:         8,
            height:        8,
            borderRadius: '50%',
            background:   'var(--color-button)',
            flexShrink:   0,
            animation:    'pulse 2s ease-in-out infinite',
          }}
        />

        {/* Message */}
        <span
          style={{
            fontSize:   13,
            color:      'var(--color-text)',
            fontWeight: 500,
          }}
        >
          Playing on{' '}
          <strong style={{ fontWeight: 700 }}>{deviceName}</strong>
          {' '}— Continue here?
        </span>

        {/* CTA button */}
        <button
          type="button"
          onClick={handleClaim}
          disabled={claiming}
          aria-label={`Listen here instead of ${deviceName}`}
          style={{
            background:   claiming ? 'var(--color-highlight)' : 'var(--color-button)',
            color:         claiming ? 'var(--color-subtext)' : '#000',
            border:        'none',
            borderRadius:  24,
            padding:       '6px 14px',
            fontSize:       13,
            fontWeight:     700,
            cursor:         claiming ? 'default' : 'pointer',
            transition:     'background 0.2s, opacity 0.2s',
            flexShrink:     0,
            whiteSpace:     'nowrap',
          }}
          onMouseEnter={(e) => {
            if (!claiming) e.currentTarget.style.background = 'var(--color-button-active)'
          }}
          onMouseLeave={(e) => {
            if (!claiming) e.currentTarget.style.background = 'var(--color-button)'
          }}
        >
          {claiming ? 'Switching…' : 'Listen here'}
        </button>
      </div>

      {/* Pulse keyframe */}
      <style>{`
        @keyframes pulse {
          0%, 100% { opacity: 1; transform: scale(1); }
          50%       { opacity: 0.5; transform: scale(1.3); }
        }
      `}</style>
    </>
  )
}
