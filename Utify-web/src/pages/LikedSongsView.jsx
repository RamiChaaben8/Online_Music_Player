/**
 * LikedSongsView.jsx
 * Displays all liked songs from libraryStore.likedSongs.
 * - 'Play All' and 'Shuffle' buttons
 * - SongRow style consistent with SearchView
 * - Unlike button per row
 */

import { useState, useCallback } from 'react'
import { useLibraryStore } from '../stores/libraryStore'
import { usePlayerStore } from '../stores/playerStore'
import { useAuthStore } from '../stores/authStore'

// ── Helpers ───────────────────────────────────────────────────────────────────
function formatDuration(seconds) {
  if (!seconds || isNaN(seconds)) return ''
  const m = Math.floor(seconds / 60)
  const s = Math.floor(seconds % 60)
  return `${m}:${s.toString().padStart(2, '0')}`
}

function shuffleArray(arr) {
  const a = [...arr]
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]]
  }
  return a
}

// ── Heart icon ────────────────────────────────────────────────────────────────
function HeartFilled({ size = 16 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="var(--color-button)" aria-hidden="true">
      <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>
    </svg>
  )
}

// ── SongRow ───────────────────────────────────────────────────────────────────
function SongRow({ song, index, isPlaying, isCurrent, onPlay, onUnlike }) {
  const [hover, setHover] = useState(false)

  const rowBg = isCurrent
    ? 'var(--color-selected-row)'
    : hover
    ? 'var(--color-highlight)'
    : 'transparent'

  return (
    <li
      style={{
        display: 'grid',
        gridTemplateColumns: '32px 1fr auto auto',
        alignItems: 'center',
        gap: 12,
        padding: '6px 16px',
        borderRadius: 6,
        background: rowBg,
        transition: 'background 0.12s',
        cursor: 'pointer',
        userSelect: 'none',
        listStyle: 'none',
      }}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      onDoubleClick={() => onPlay(index)}
      onClick={() => onPlay(index)}
      role="row"
      aria-label={`${song.title} by ${song.channelName}`}
    >
      {/* Track number / playing indicator */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          color: isCurrent ? 'var(--color-button)' : 'var(--color-subtext)',
          fontSize: 13,
          minWidth: 0,
        }}
      >
        {isCurrent && isPlaying ? (
          <svg width="14" height="14" viewBox="0 0 24 24" fill="var(--color-button)" aria-label="Now playing">
            <rect x="2" y="10" width="3" height="10" rx="1"/>
            <rect x="8" y="5" width="3" height="15" rx="1"/>
            <rect x="14" y="7" width="3" height="13" rx="1"/>
            <rect x="20" y="2" width="3" height="18" rx="1"/>
          </svg>
        ) : (
          <span>{index + 1}</span>
        )}
      </div>

      {/* Thumbnail + title + artist */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, minWidth: 0 }}>
        {song.thumbnailUrl ? (
          <img
            src={song.thumbnailUrl}
            alt=""
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
            aria-hidden="true"
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--color-subtext)" strokeWidth="2">
              <path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>
            </svg>
          </div>
        )}
        <div style={{ minWidth: 0 }}>
          <div
            style={{
              fontSize: 14,
              fontWeight: isCurrent ? 700 : 500,
              color: isCurrent ? 'var(--color-button)' : 'var(--color-text)',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
              lineHeight: 1.3,
            }}
          >
            {song.title}
          </div>
          <div
            style={{
              fontSize: 12,
              color: 'var(--color-subtext)',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
            }}
          >
            {song.channelName}
          </div>
        </div>
      </div>

      {/* Duration */}
      <span
        style={{
          fontSize: 13,
          color: 'var(--color-subtext)',
          whiteSpace: 'nowrap',
          minWidth: 36,
          textAlign: 'right',
        }}
      >
        {formatDuration(song.durationSeconds)}
      </span>

      {/* Unlike button */}
      <button
        onClick={(e) => { e.stopPropagation(); onUnlike(song.id) }}
        aria-label={`Remove ${song.title} from liked songs`}
        title="Remove from Liked Songs"
        style={{
          background: 'none',
          border: 'none',
          cursor: 'pointer',
          padding: '4px',
          display: 'flex',
          alignItems: 'center',
          borderRadius: 4,
          color: 'var(--color-button)',
          opacity: hover ? 1 : 0.7,
          transition: 'opacity 0.15s',
        }}
      >
        <HeartFilled size={16} />
      </button>
    </li>
  )
}

// ── Empty state ───────────────────────────────────────────────────────────────
function EmptyState() {
  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '80px 24px',
        gap: 16,
        color: 'var(--color-subtext)',
      }}
    >
      <svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.2" aria-hidden="true">
        <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>
      </svg>
      <p style={{ margin: 0, fontSize: 18, fontWeight: 700, color: 'var(--color-text)' }}>
        Songs you like will appear here
      </p>
      <p style={{ margin: 0, fontSize: 14 }}>
        Like songs while browsing to add them.
      </p>
    </div>
  )
}

// ── Main LikedSongsView ───────────────────────────────────────────────────────
export default function LikedSongsView() {
  const user = useAuthStore((s) => s.user)
  const likedSongs = useLibraryStore((s) => s.likedSongs)
  const toggleLike = useLibraryStore((s) => s.toggleLike)
  const playQueue = usePlayerStore((s) => s.playQueue)
  const currentSong = usePlayerStore((s) => s.currentSong)
  const playing = usePlayerStore((s) => s.playing)

  const handlePlay = useCallback((startIndex) => {
    playQueue(likedSongs, startIndex)
  }, [likedSongs, playQueue])

  const handlePlayAll = useCallback(() => {
    if (!likedSongs.length) return
    playQueue(likedSongs, 0)
  }, [likedSongs, playQueue])

  const handleShuffle = useCallback(() => {
    if (!likedSongs.length) return
    const shuffled = shuffleArray(likedSongs)
    playQueue(shuffled, 0)
  }, [likedSongs, playQueue])

  const handleUnlike = useCallback((songId) => {
    if (!user?.uid) return
    const song = likedSongs.find((s) => s.id === songId)
    if (song) toggleLike(user.uid, song)
  }, [user?.uid, likedSongs, toggleLike])

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
      {/* Header banner */}
      <div
        style={{
          padding: '40px 24px 24px',
          background: 'linear-gradient(180deg, var(--color-button)22 0%, transparent 100%)',
          display: 'flex',
          alignItems: 'flex-end',
          gap: 24,
          flexWrap: 'wrap',
        }}
      >
        {/* Cover art placeholder */}
        <div
          style={{
            width: 140,
            height: 140,
            borderRadius: 8,
            background: 'linear-gradient(135deg, var(--color-button) 0%, var(--color-misc) 100%)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
            boxShadow: '0 8px 32px rgba(0,0,0,0.4)',
          }}
          aria-hidden="true"
        >
          <svg width="60" height="60" viewBox="0 0 24 24" fill="rgba(255,255,255,0.9)">
            <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>
          </svg>
        </div>

        <div style={{ flexGrow: 1 }}>
          <p style={{ margin: '0 0 4px', fontSize: 12, fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.08em', color: 'var(--color-subtext)' }}>
            Playlist
          </p>
          <h1 style={{ margin: '0 0 8px', fontSize: 36, fontWeight: 900, lineHeight: 1 }}>
            Liked Songs
          </h1>
          <p style={{ margin: 0, fontSize: 14, color: 'var(--color-subtext)' }}>
            {likedSongs.length} {likedSongs.length === 1 ? 'song' : 'songs'}
          </p>
        </div>
      </div>

      {/* Action bar */}
      {likedSongs.length > 0 && (
        <div style={{ display: 'flex', gap: 12, padding: '16px 24px' }}>
          <button
            onClick={handlePlayAll}
            aria-label="Play all liked songs"
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 8,
              padding: '12px 28px',
              borderRadius: 50,
              border: 'none',
              background: 'var(--color-button)',
              color: '#fff',
              fontWeight: 700,
              fontSize: 15,
              cursor: 'pointer',
              transition: 'transform 0.1s, background 0.15s',
            }}
            onMouseEnter={(e) => e.currentTarget.style.transform = 'scale(1.04)'}
            onMouseLeave={(e) => e.currentTarget.style.transform = 'scale(1)'}
          >
            {/* Play icon */}
            <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
              <polygon points="5,3 19,12 5,21"/>
            </svg>
            Play
          </button>

          <button
            onClick={handleShuffle}
            aria-label="Shuffle liked songs"
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 8,
              padding: '12px 22px',
              borderRadius: 50,
              border: '1px solid var(--color-highlight-elevated)',
              background: 'none',
              color: 'var(--color-text)',
              fontWeight: 600,
              fontSize: 15,
              cursor: 'pointer',
              transition: 'background 0.15s',
            }}
            onMouseEnter={(e) => e.currentTarget.style.background = 'var(--color-highlight)'}
            onMouseLeave={(e) => e.currentTarget.style.background = 'none'}
          >
            {/* Shuffle icon */}
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
              <polyline points="16 3 21 3 21 8"/>
              <line x1="4" y1="20" x2="21" y2="3"/>
              <polyline points="21 16 21 21 16 21"/>
              <line x1="15" y1="15" x2="21" y2="21"/>
            </svg>
            Shuffle
          </button>
        </div>
      )}

      {/* Column headers */}
      {likedSongs.length > 0 && (
        <div
          aria-hidden="true"
          style={{
            display: 'grid',
            gridTemplateColumns: '32px 1fr auto auto',
            gap: 12,
            padding: '4px 16px 8px',
            borderBottom: '1px solid var(--color-highlight)',
            margin: '0 16px',
            fontSize: 11,
            fontWeight: 700,
            letterSpacing: '0.1em',
            textTransform: 'uppercase',
            color: 'var(--color-subtext)',
          }}
        >
          <span style={{ textAlign: 'center' }}>#</span>
          <span>Title</span>
          <span style={{ textAlign: 'right' }}>Duration</span>
          <span />
        </div>
      )}

      {/* Song list */}
      <div style={{ flexGrow: 1, overflowY: 'auto', padding: '8px 8px 24px' }}>
        {likedSongs.length === 0 ? (
          <EmptyState />
        ) : (
          <ul
            role="list"
            aria-label="Liked songs"
            style={{ listStyle: 'none', margin: 0, padding: 0 }}
          >
            {likedSongs.map((song, i) => (
              <SongRow
                key={song.id}
                song={song}
                index={i}
                isCurrent={currentSong?.id === song.id}
                isPlaying={playing && currentSong?.id === song.id}
                onPlay={handlePlay}
                onUnlike={handleUnlike}
              />
            ))}
          </ul>
        )}
      </div>
    </div>
  )
}
