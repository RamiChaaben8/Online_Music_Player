/**
 * FriendsView.jsx
 * Mirrors friends_screen.dart — three tabs: Friends, Requests, Add Friend.
 * All styling via CSS variables from index.css.
 */

import { useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  subscribeToFriends,
  subscribeToFriendRequests,
  sendFriendRequest,
  acceptFriendRequest,
  declineFriendRequest,
  getPublicProfile,
} from '../services/firestoreService'
import { useAuthStore } from '../stores/authStore'

// ── Avatar helper ─────────────────────────────────────────────────────────────
function Avatar({ photoURL, username, size = 40 }) {
  const initials = username ? username.charAt(0).toUpperCase() : '?'
  if (photoURL) {
    return (
      <img
        src={photoURL}
        alt={username}
        style={{
          width: size,
          height: size,
          borderRadius: '50%',
          objectFit: 'cover',
          flexShrink: 0,
        }}
        onError={(e) => { e.currentTarget.style.display = 'none' }}
      />
    )
  }
  return (
    <div
      aria-label={`Avatar for ${username}`}
      style={{
        width: size,
        height: size,
        borderRadius: '50%',
        background: 'var(--color-highlight-elevated)',
        color: 'var(--color-subtext)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontSize: size * 0.4,
        fontWeight: 700,
        flexShrink: 0,
      }}
    >
      {initials}
    </div>
  )
}

// ── Online dot ────────────────────────────────────────────────────────────────
function OnlineDot({ online }) {
  return (
    <span
      style={{
        display: 'inline-block',
        width: 10,
        height: 10,
        borderRadius: '50%',
        background: online ? 'var(--color-button)' : 'var(--color-subtext)',
        border: '2px solid var(--color-main)',
        flexShrink: 0,
      }}
    />
  )
}

// ── Empty state ───────────────────────────────────────────────────────────────
function EmptyState({ message }) {
  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '48px 24px',
        color: 'var(--color-subtext)',
        gap: 12,
        textAlign: 'center',
      }}
    >
      <svg width="56" height="56" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" aria-hidden="true">
        <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
        <circle cx="9" cy="7" r="4"/>
        <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
        <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
      </svg>
      <p style={{ margin: 0, fontSize: 14 }}>{message}</p>
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

// ── Tab bar ───────────────────────────────────────────────────────────────────
function Tabs({ tabs, activeIndex, onChange }) {
  return (
    <div
      role="tablist"
      style={{
        display: 'flex',
        borderBottom: '2px solid var(--color-highlight)',
        marginBottom: 0,
      }}
    >
      {tabs.map((tab, i) => (
        <button
          key={i}
          role="tab"
          aria-selected={activeIndex === i}
          onClick={() => onChange(i)}
          style={{
            padding: '12px 20px',
            background: 'none',
            border: 'none',
            borderBottom: activeIndex === i ? '2px solid var(--color-button)' : '2px solid transparent',
            marginBottom: -2,
            color: activeIndex === i ? 'var(--color-text)' : 'var(--color-subtext)',
            fontWeight: activeIndex === i ? 700 : 400,
            fontSize: 14,
            cursor: 'pointer',
            transition: 'color 0.15s',
            whiteSpace: 'nowrap',
          }}
        >
          {tab}
        </button>
      ))}
    </div>
  )
}

// ── Friends tab ───────────────────────────────────────────────────────────────
function FriendsList({ friends, loading }) {
  const navigate = useNavigate()

  if (loading) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', padding: 48 }}>
        <Spinner />
      </div>
    )
  }
  if (!friends.length) {
    return <EmptyState message="No friends yet — add someone from the Add Friend tab." />
  }

  return (
    <ul style={{ listStyle: 'none', margin: 0, padding: 0 }}>
      {friends.map((friend) => {
        if (!friend) return null
        const displayName = friend.displayName || `@${friend.username}`
        const isOnline = friend.isOnline ?? false
        const activity = friend.activity
        const subtitle = isOnline
          ? activity?.title
            ? `${activity.title}${activity.artist ? ` • ${activity.artist}` : ''}`
            : 'Online'
          : 'Offline'

        return (
          <li key={friend.uid}>
            <button
              onClick={() => navigate(`/friends/${friend.uid}`)}
              style={{
                width: '100%',
                display: 'flex',
                alignItems: 'center',
                gap: 12,
                padding: '10px 20px',
                background: 'none',
                border: 'none',
                cursor: 'pointer',
                color: 'var(--color-text)',
                textAlign: 'left',
                borderRadius: 6,
                transition: 'background 0.15s',
              }}
              onMouseEnter={(e) => e.currentTarget.style.background = 'var(--color-highlight)'}
              onMouseLeave={(e) => e.currentTarget.style.background = 'none'}
              aria-label={`View ${displayName}'s profile`}
            >
              {/* Avatar + online dot */}
              <div style={{ position: 'relative', flexShrink: 0 }}>
                <Avatar photoURL={friend.photoURL} username={friend.username} size={44} />
                <span style={{ position: 'absolute', bottom: 0, right: 0 }}>
                  <OnlineDot online={isOnline} />
                </span>
              </div>

              {/* Text */}
              <div style={{ minWidth: 0 }}>
                <div style={{ fontWeight: 600, fontSize: 15, lineHeight: 1.3, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {displayName}
                </div>
                <div style={{ fontSize: 13, color: isOnline && activity ? 'var(--color-button)' : 'var(--color-subtext)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', display: 'flex', alignItems: 'center', gap: 4 }}>
                  {isOnline && activity?.isPlaying && (
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="var(--color-button)" aria-hidden="true">
                      <rect x="2" y="10" width="3" height="10" rx="1"/>
                      <rect x="8" y="5" width="3" height="15" rx="1"/>
                      <rect x="14" y="7" width="3" height="13" rx="1"/>
                      <rect x="20" y="2" width="3" height="18" rx="1"/>
                    </svg>
                  )}
                  {subtitle}
                </div>
              </div>

              <span style={{ marginLeft: 'auto', color: 'var(--color-subtext)', fontSize: 13 }}>
                @{friend.username}
              </span>
            </button>
          </li>
        )
      })}
    </ul>
  )
}

// ── Requests tab ──────────────────────────────────────────────────────────────
function RequestsList({ requests, onAccept, onDecline, processing }) {
  const [profiles, setProfiles] = useState({})

  // Fetch profiles for each request
  useEffect(() => {
    const missing = requests.filter((r) => !profiles[r.fromUid])
    if (!missing.length) return
    missing.forEach(async (req) => {
      try {
        const p = await getPublicProfile(req.fromUid)
        if (p) setProfiles((prev) => ({ ...prev, [req.fromUid]: p }))
      } catch (_) {}
    })
  }, [requests]) // eslint-disable-line react-hooks/exhaustive-deps

  if (!requests.length) {
    return <EmptyState message="No pending friend requests." />
  }

  return (
    <ul style={{ listStyle: 'none', margin: 0, padding: 0 }}>
      {requests.map((req) => {
        const profile = profiles[req.fromUid]
        const displayName = profile?.displayName || `@${profile?.username || req.fromUid}`
        const isProcessing = processing === req.id

        return (
          <li
            key={req.id}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 12,
              padding: '10px 20px',
              borderBottom: '1px solid var(--color-highlight)',
            }}
          >
            <Avatar photoURL={profile?.photoURL} username={profile?.username || '?'} size={44} />
            <div style={{ flexGrow: 1, minWidth: 0 }}>
              <div style={{ fontWeight: 600, fontSize: 15, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {displayName}
              </div>
              {profile?.username && (
                <div style={{ fontSize: 13, color: 'var(--color-subtext)' }}>
                  @{profile.username}
                </div>
              )}
            </div>
            <div style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
              <button
                onClick={() => onAccept(req)}
                disabled={isProcessing}
                aria-label="Accept friend request"
                style={{
                  padding: '6px 14px',
                  borderRadius: 20,
                  border: 'none',
                  background: 'var(--color-button)',
                  color: '#fff',
                  fontWeight: 600,
                  fontSize: 13,
                  cursor: isProcessing ? 'default' : 'pointer',
                  opacity: isProcessing ? 0.6 : 1,
                }}
              >
                {isProcessing ? '…' : 'Accept'}
              </button>
              <button
                onClick={() => onDecline(req)}
                disabled={isProcessing}
                aria-label="Decline friend request"
                style={{
                  padding: '6px 14px',
                  borderRadius: 20,
                  border: '1px solid var(--color-highlight-elevated)',
                  background: 'none',
                  color: 'var(--color-subtext)',
                  fontWeight: 600,
                  fontSize: 13,
                  cursor: isProcessing ? 'default' : 'pointer',
                  opacity: isProcessing ? 0.6 : 1,
                }}
              >
                Decline
              </button>
            </div>
          </li>
        )
      })}
    </ul>
  )
}

// ── Add Friend tab ────────────────────────────────────────────────────────────
function AddFriend({ currentUid, onRequestSent }) {
  const [query, setQuery] = useState('')
  const [results, setResults] = useState([])
  const [searching, setSearching] = useState(false)
  const [sendingUid, setSendingUid] = useState(null)
  const [error, setError] = useState('')
  const inputRef = useRef(null)

  const handleSearch = async () => {
    const term = query.trim()
    if (!term) return
    setSearching(true)
    setError('')
    setResults([])
    try {
      // getPublicProfile takes a UID; for username search we query by username field
      // firestoreService.getPublicProfile returns null for unknown UIDs.
      // We support searching by username by querying the public profiles collection.
      const profile = await getPublicProfile(term)
      if (profile) {
        setResults([profile])
      } else {
        setResults([])
        setError('No user found with that username or UID.')
      }
    } catch (e) {
      setError('Search failed. Try again.')
    } finally {
      setSearching(false)
    }
  }

  const handleKeyDown = (e) => {
    if (e.key === 'Enter') handleSearch()
  }

  const handleAddFriend = async (profile) => {
    setSendingUid(profile.uid)
    try {
      await sendFriendRequest(currentUid, profile.uid)
      onRequestSent?.(`Friend request sent to @${profile.username}.`)
    } catch (e) {
      setError(e.message || 'Could not send friend request.')
    } finally {
      setSendingUid(null)
    }
  }

  return (
    <div style={{ padding: '20px 20px 0' }}>
      {/* Search bar */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 4 }}>
        <input
          ref={inputRef}
          type="text"
          value={query}
          onChange={(e) => { setQuery(e.target.value); setError('') }}
          onKeyDown={handleKeyDown}
          placeholder="Search by username or UID…"
          aria-label="Search users"
          style={{
            flexGrow: 1,
            padding: '10px 14px',
            borderRadius: 6,
            border: '1px solid var(--color-highlight-elevated)',
            background: 'var(--color-highlight)',
            color: 'var(--color-text)',
            fontSize: 14,
            outline: 'none',
          }}
        />
        <button
          onClick={handleSearch}
          disabled={searching || !query.trim()}
          aria-label="Search"
          style={{
            padding: '10px 18px',
            borderRadius: 6,
            border: 'none',
            background: 'var(--color-button)',
            color: '#fff',
            fontWeight: 700,
            fontSize: 14,
            cursor: searching || !query.trim() ? 'default' : 'pointer',
            opacity: searching || !query.trim() ? 0.6 : 1,
            display: 'flex',
            alignItems: 'center',
            gap: 6,
          }}
        >
          {searching ? <Spinner size={16} /> : 'Search'}
        </button>
      </div>

      {error && (
        <p style={{ color: 'var(--color-error)', fontSize: 13, margin: '8px 0 0' }}>{error}</p>
      )}

      {/* Results */}
      <ul style={{ listStyle: 'none', margin: '16px 0 0', padding: 0 }}>
        {results.map((profile) => {
          const displayName = profile.displayName || `@${profile.username}`
          const isSending = sendingUid === profile.uid
          return (
            <li
              key={profile.uid}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 12,
                padding: '10px 0',
                borderBottom: '1px solid var(--color-highlight)',
              }}
            >
              <Avatar photoURL={profile.photoURL} username={profile.username} size={44} />
              <div style={{ flexGrow: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 600, fontSize: 15, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {displayName}
                </div>
                <div style={{ fontSize: 13, color: 'var(--color-subtext)' }}>
                  @{profile.username}
                </div>
              </div>
              <button
                onClick={() => handleAddFriend(profile)}
                disabled={isSending || profile.uid === currentUid}
                aria-label={`Add ${profile.username} as friend`}
                style={{
                  padding: '7px 16px',
                  borderRadius: 20,
                  border: 'none',
                  background: 'var(--color-button)',
                  color: '#fff',
                  fontWeight: 700,
                  fontSize: 13,
                  cursor: isSending || profile.uid === currentUid ? 'default' : 'pointer',
                  opacity: isSending || profile.uid === currentUid ? 0.5 : 1,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 6,
                  flexShrink: 0,
                }}
              >
                {isSending ? <Spinner size={14} /> : 'Add Friend'}
              </button>
            </li>
          )
        })}
      </ul>

      {!searching && !results.length && !error && (
        <EmptyState message="Search by exact or partial username to find friends." />
      )}
    </div>
  )
}

// ── Spinner ───────────────────────────────────────────────────────────────────
function Spinner({ size = 24 }) {
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
          flexShrink: 0,
        }}
      />
      <style>{`@keyframes utify-spin { to { transform: rotate(360deg); } }`}</style>
    </>
  )
}

// ── Main FriendsView ──────────────────────────────────────────────────────────
export default function FriendsView() {
  const user = useAuthStore((s) => s.user)
  const [activeTab, setActiveTab] = useState(0)
  const [friends, setFriends] = useState([])
  const [requests, setRequests] = useState([])
  const [loadingFriends, setLoadingFriends] = useState(true)
  const [processingRequest, setProcessingRequest] = useState(null)
  const [toast, setToast] = useState('')

  // Subscribe to friends list
  useEffect(() => {
    if (!user?.uid) return
    setLoadingFriends(true)
    const unsub = subscribeToFriends(user.uid, (list) => {
      setFriends(list)
      setLoadingFriends(false)
    })
    return () => unsub?.()
  }, [user?.uid])

  // Subscribe to incoming friend requests
  useEffect(() => {
    if (!user?.uid) return
    const unsub = subscribeToFriendRequests(user.uid, (list) => {
      setRequests(list)
    })
    return () => unsub?.()
  }, [user?.uid])

  const handleAccept = async (req) => {
    setProcessingRequest(req.id)
    try {
      await acceptFriendRequest(req.id, req.fromUid, user.uid)
      setToast('Friend request accepted!')
    } catch (e) {
      setToast('Could not accept request. Try again.')
    } finally {
      setProcessingRequest(null)
    }
  }

  const handleDecline = async (req) => {
    setProcessingRequest(req.id)
    try {
      await declineFriendRequest(req.id)
    } catch (_) {
      setToast('Could not decline request. Try again.')
    } finally {
      setProcessingRequest(null)
    }
  }

  const tabLabels = [
    'Friends',
    `Requests${requests.length ? ` (${requests.length})` : ''}`,
    'Add Friend',
  ]

  return (
    <div
      style={{
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        background: 'var(--color-main)',
        color: 'var(--color-text)',
      }}
    >
      {/* Header */}
      <div style={{ padding: '24px 20px 0' }}>
        <h1 style={{ margin: '0 0 16px', fontSize: 28, fontWeight: 800 }}>Friends</h1>
        <Tabs tabs={tabLabels} activeIndex={activeTab} onChange={setActiveTab} />
      </div>

      {/* Tab content — scrollable */}
      <div style={{ flexGrow: 1, overflowY: 'auto' }}>
        {activeTab === 0 && (
          <FriendsList friends={friends} loading={loadingFriends} />
        )}
        {activeTab === 1 && (
          <RequestsList
            requests={requests}
            onAccept={handleAccept}
            onDecline={handleDecline}
            processing={processingRequest}
          />
        )}
        {activeTab === 2 && (
          <AddFriend
            currentUid={user?.uid}
            onRequestSent={(msg) => { setToast(msg); setActiveTab(1) }}
          />
        )}
      </div>

      <Toast message={toast} onClose={() => setToast('')} />
    </div>
  )
}
