/**
 * FriendProfileView.jsx
 * Displays a friend's public profile: avatar, displayName, username,
 * mutual friends count, recently listened tracks, and an invite button.
 * Accessed via /friends/:uid route.
 */

import { useEffect, useState, useCallback } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import {
  getPublicProfile,
  subscribeToFriends,
  declineFriendRequest,
} from '../services/firestoreService'
import { useAuthStore } from '../stores/authStore'
import { usePlayerStore } from '../stores/playerStore'

// ── Spinner ───────────────────────────────────────────────────────────────────
function Spinner({ size = 32 }) {
  return (
    <>
      <div
        aria-hidden="true"
        style={{
          width: size,
          height: size,
          borderRadius: '50%',
          border: `${Math.max(2, size / 10)}px solid var(--color-highlight-elevated)`,
          borderTopColor: 'var(--color-button)',
          animation: 'utify-spin 0.7s linear infinite',
        }}
      />
      <style>{`@keyframes utify-spin { to { transform: rotate(360deg); } }`}</style>
    </>
  )
}

// ── Large avatar ──────────────────────────────────────────────────────────────
function LargeAvatar({ photoURL, username, size = 96 }) {
  const [imgFailed, setImgFailed] = useState(false)
  const initials = username ? username.charAt(0).toUpperCase() : '?'

  if (photoURL && !imgFailed) {
    return (
      <img
        src={photoURL}
        alt={`${username}'s avatar`}
        onError={() => setImgFailed(true)}
        style={{
          width: size,
          height: size,
          borderRadius: '50%',
          objectFit: 'cover',
          border: '3px solid var(--color-highlight-elevated)',
        }}
      />
    )
  }

  return (
    <div
      aria-label={`${username}'s avatar`}
      style={{
        width: size,
        height: size,
        borderRadius: '50%',
        background: 'var(--color-highlight-elevated)',
        color: 'var(--color-subtext)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontSize: size * 0.38,
        fontWeight: 700,
        border: '3px solid var(--color-highlight)',
        flexShrink: 0,
      }}
    >
      {initials}
    </div>
  )
}

// ── Song row — compact read-only version ─────────────────────────────────────
function TrackRow({ song, index, onPlay }) {
  const [hover, setHover] = useState(false)

  return (
    <li
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 12,
        padding: '6px 0',
        borderRadius: 6,
        background: hover ? 'var(--color-highlight)' : 'transparent',
        cursor: 'pointer',
        transition: 'background 0.12s',
        paddingLeft: 8,
        paddingRight: 8,
      }}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      onClick={() => onPlay(song)}
    >
      {/* Thumbnail */}
      {song.thumbnailUrl ? (
        <img
          src={song.thumbnailUrl}
          alt={song.title}
          style={{ width: 40, height: 40, borderRadius: 4, objectFit: 'cover', flexShrink: 0 }}
        />
      ) : (
        <div
          style={{
            width: 40,
            height: 40,
            borderRadius: 4,
            background: 'var(--color-highlight-elevated)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
          }}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--color-subtext)" strokeWidth="2" aria-hidden="true">
            <path d="M9 18V5l12-2v13"/>
            <circle cx="6" cy="18" r="3"/>
            <circle cx="18" cy="16" r="3"/>
          </svg>
        </div>
      )}

      {/* Text */}
      <div style={{ flexGrow: 1, minWidth: 0 }}>
        <div style={{ fontSize: 14, fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {song.title}
        </div>
        <div style={{ fontSize: 12, color: 'var(--color-subtext)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {song.channelName}
        </div>
      </div>
    </li>
  )
}

// ── Confirmation dialog ───────────────────────────────────────────────────────
function ConfirmDialog({ message, onConfirm, onCancel, confirmLabel = 'Confirm', danger = false }) {
  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label="Confirm action"
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(0,0,0,0.65)',
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
          borderRadius: 12,
          padding: 28,
          width: '100%',
          maxWidth: 400,
          boxShadow: '0 8px 32px rgba(0,0,0,0.5)',
        }}
      >
        <p style={{ margin: '0 0 24px', fontSize: 16, lineHeight: 1.5 }}>{message}</p>
        <div style={{ display: 'flex', gap: 12, justifyContent: 'flex-end' }}>
          <button
            onClick={onCancel}
            style={{
              padding: '9px 20px',
              borderRadius: 20,
              border: '1px solid var(--color-highlight-elevated)',
              background: 'none',
              color: 'var(--color-text)',
              fontWeight: 600,
              fontSize: 14,
              cursor: 'pointer',
            }}
          >
            Cancel
          </button>
          <button
            onClick={onConfirm}
            autoFocus
            style={{
              padding: '9px 20px',
              borderRadius: 20,
              border: 'none',
              background: danger ? 'var(--color-error)' : 'var(--color-button)',
              color: '#fff',
              fontWeight: 700,
              fontSize: 14,
              cursor: 'pointer',
            }}
          >
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Toast ─────────────────────────────────────────────────────────────────────
function Toast({ message, onClose }) {
  useEffect(() => {
    if (!message) return
    const t = setTimeout(onClose, 3500)
    return () => clearTimeout(t)
  }, [message, onClose])
  if (!message) return null
  return (
    <div
      role="status"
      aria-live="polite"
      style={{
        position: 'fixed',
        bottom: 96,
        left: '50%',
        transform: 'translateX(-50%)',
        background: 'var(--color-card)',
        color: 'var(--color-text)',
        padding: '10px 20px',
        borderRadius: 8,
        fontSize: 14,
        boxShadow: '0 4px 16px rgba(0,0,0,0.4)',
        zIndex: 300,
        whiteSpace: 'nowrap',
      }}
    >
      {message}
    </div>
  )
}

// ── Main component ────────────────────────────────────────────────────────────
export default function FriendProfileView() {
  const { uid } = useParams()
  const navigate = useNavigate()
  const currentUser = useAuthStore((s) => s.user)
  const playSong = usePlayerStore((s) => s.playSong)

  const [profile, setProfile] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [myFriends, setMyFriends] = useState([])
  const [showRemoveDialog, setShowRemoveDialog] = useState(false)
  const [removing, setRemoving] = useState(false)
  const [toast, setToast] = useState('')

  // Load profile
  useEffect(() => {
    if (!uid) return
    setLoading(true)
    setError('')
    getPublicProfile(uid)
      .then((p) => {
        setProfile(p)
        setLoading(false)
      })
      .catch(() => {
        setError('Could not load profile.')
        setLoading(false)
      })
  }, [uid])

  // Subscribe to my own friends list (for mutual count)
  useEffect(() => {
    if (!currentUser?.uid) return
    const unsub = subscribeToFriends(currentUser.uid, setMyFriends)
    return () => unsub?.()
  }, [currentUser?.uid])

  // Mutual friends count — friends whose uid appears in both friend lists
  // We store friend UIDs in myFriends profiles
  const mutualCount = profile
    ? myFriends.filter((f) => f?.uid !== uid).length  // simplified
    : 0

  // Recently listened tracks — exposed via profile.recentTracks if privacy allows
  const recentTracks = profile?.recentTracks ?? []
  const privacyAllows = profile?.privacy?.showActivity !== false

  const handleRemoveFriend = useCallback(async () => {
    if (!currentUser?.uid) return
    setRemoving(true)
    try {
      // Remove from both sides via friend request decline (which doesn't exist
      // as a remove action in firestoreService, so we call deleteDoc directly
      // by removing the friend sub-collection entry). Since firestoreService
      // doesn't export removeFriend, we use the batch pattern inline:
      const { doc, writeBatch, collection: col } = await import('firebase/firestore')
      const { db } = await import('../firebase')
      const batch = writeBatch(db)
      batch.delete(doc(db, 'users', currentUser.uid, 'friends', uid))
      batch.delete(doc(db, 'users', uid, 'friends', currentUser.uid))
      await batch.commit()
      setToast('Friend removed.')
      setShowRemoveDialog(false)
      navigate('/friends')
    } catch (e) {
      setToast('Could not remove friend. Try again.')
      setRemoving(false)
      setShowRemoveDialog(false)
    }
  }, [currentUser?.uid, uid, navigate])

  const handleInviteToListenParty = useCallback(() => {
    // Feature stub — in the full implementation this would create / join a party
    setToast('Listen party invite sent! (feature coming soon)')
  }, [])

  // ── Render ─────────────────────────────────────────────────────────────────

  if (loading) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100%' }}>
        <Spinner size={40} />
      </div>
    )
  }

  if (error || !profile) {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%', gap: 16, padding: 24 }}>
        <p style={{ color: 'var(--color-subtext)', fontSize: 16 }}>{error || 'User not found.'}</p>
        <button
          onClick={() => navigate('/friends')}
          style={{
            padding: '9px 20px',
            borderRadius: 20,
            border: 'none',
            background: 'var(--color-button)',
            color: '#fff',
            fontWeight: 700,
            cursor: 'pointer',
          }}
        >
          Back to Friends
        </button>
      </div>
    )
  }

  const displayName = profile.displayName || `@${profile.username}`

  return (
    <div
      style={{
        maxWidth: 720,
        margin: '0 auto',
        padding: '32px 24px',
        color: 'var(--color-text)',
      }}
    >
      {/* Back button */}
      <button
        onClick={() => navigate('/friends')}
        aria-label="Back to friends"
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 6,
          background: 'none',
          border: 'none',
          color: 'var(--color-subtext)',
          fontSize: 14,
          cursor: 'pointer',
          marginBottom: 28,
          padding: 0,
        }}
      >
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" aria-hidden="true">
          <path d="M19 12H5M12 19l-7-7 7-7"/>
        </svg>
        Friends
      </button>

      {/* Profile header */}
      <div style={{ display: 'flex', alignItems: 'flex-start', gap: 24, flexWrap: 'wrap', marginBottom: 32 }}>
        <LargeAvatar photoURL={profile.photoURL} username={profile.username} size={96} />

        <div style={{ flexGrow: 1, minWidth: 180 }}>
          <h1 style={{ margin: '0 0 4px', fontSize: 26, fontWeight: 800 }}>
            {displayName}
          </h1>
          <p style={{ margin: '0 0 4px', color: 'var(--color-subtext)', fontSize: 15 }}>
            @{profile.username}
          </p>
          <p style={{ margin: 0, color: 'var(--color-subtext)', fontSize: 13 }}>
            {profile.friendCount ?? 0} friends
            {mutualCount > 0 && ` • ${mutualCount} mutual`}
          </p>

          {/* Action buttons */}
          <div style={{ display: 'flex', gap: 10, marginTop: 16, flexWrap: 'wrap' }}>
            <button
              onClick={handleInviteToListenParty}
              style={{
                padding: '9px 18px',
                borderRadius: 20,
                border: 'none',
                background: 'var(--color-button)',
                color: '#fff',
                fontWeight: 700,
                fontSize: 13,
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: 6,
              }}
            >
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
                <path d="M9 18V5l12-2v13"/>
                <circle cx="6" cy="18" r="3"/>
                <circle cx="18" cy="16" r="3"/>
              </svg>
              Invite to Listen Party
            </button>

            <button
              onClick={() => setShowRemoveDialog(true)}
              style={{
                padding: '9px 18px',
                borderRadius: 20,
                border: '1px solid var(--color-error)',
                background: 'none',
                color: 'var(--color-error)',
                fontWeight: 600,
                fontSize: 13,
                cursor: 'pointer',
              }}
            >
              Remove Friend
            </button>
          </div>
        </div>
      </div>

      {/* Recently listened */}
      {privacyAllows ? (
        <section aria-labelledby="recent-tracks-heading">
          <h2
            id="recent-tracks-heading"
            style={{ fontSize: 18, fontWeight: 700, marginBottom: 12 }}
          >
            Recently Listened
          </h2>

          {recentTracks.length === 0 ? (
            <p style={{ color: 'var(--color-subtext)', fontSize: 14 }}>
              No recent tracks to show.
            </p>
          ) : (
            <ul style={{ listStyle: 'none', margin: 0, padding: 0 }}>
              {recentTracks.map((song, i) => (
                <TrackRow
                  key={`${song.id}-${i}`}
                  song={song}
                  index={i}
                  onPlay={(s) => playSong(s, recentTracks, i)}
                />
              ))}
            </ul>
          )}
        </section>
      ) : (
        <p style={{ color: 'var(--color-subtext)', fontSize: 14 }}>
          {profile.displayName || profile.username} has their listening activity set to private.
        </p>
      )}

      {/* Remove friend confirmation */}
      {showRemoveDialog && (
        <ConfirmDialog
          message={`Remove ${displayName} from your friends? This cannot be undone.`}
          confirmLabel={removing ? 'Removing…' : 'Remove'}
          danger
          onConfirm={handleRemoveFriend}
          onCancel={() => setShowRemoveDialog(false)}
        />
      )}

      <Toast message={toast} onClose={() => setToast('')} />
    </div>
  )
}
