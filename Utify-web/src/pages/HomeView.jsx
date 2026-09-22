/**
 * HomeView.jsx
 *
 * Center scrollable home panel — exact match of desktop_home_view.dart
 *
 * Layout:
 *   • Sections loaded from getTrendingMusic Cloud Function
 *   • Each section has a subtitle + bold title header
 *   • Horizontal scroll row of 172×172 music cards
 *   • Card: album art + gradient overlay + optional badge + hover play button
 *   • Right-click context menu on each card
 *   • Skeleton cards while loading
 */

import { useEffect, useState, useRef } from 'react'
import { Play, MoreHorizontal, Music2 } from 'lucide-react'
import { usePlayerStore } from '../stores/playerStore'
import { useAuthStore } from '../stores/authStore'
import { useLibraryStore } from '../stores/libraryStore'
import { getTrendingMusic, searchYouTube } from '../services/youtubeService'

// ── Constants ─────────────────────────────────────────────────────────────────
const CARD_SIZE = 172

function greeting() {
  const h = new Date().getHours()
  if (h < 12) return 'Good morning'
  if (h < 18) return 'Good afternoon'
  return 'Good evening'
}

// ── Main ──────────────────────────────────────────────────────────────────────

export default function HomeView() {
  const { user } = useAuthStore()
  const [sections, setSections] = useState([])
  const [initialLoading, setInitialLoading] = useState(true)

  const name = user?.displayName?.split(' ')[0] || 'there'

  useEffect(() => {
    let cancelled = false

    async function load() {
      setInitialLoading(true)
      try {
        // First section: trending music
        const trending = await getTrendingMusic()
        if (cancelled) return

        const initialSections = [
          {
            title: 'Trending Music',
            subtitle: 'What\'s hot right now',
            songs: trending.results || [],
            isLoading: false,
          },
          {
            title: 'Discover',
            subtitle: 'Fresh picks for you',
            songs: [],
            isLoading: true,
          },
          {
            title: 'Pop Hits',
            subtitle: 'Top chart songs',
            songs: [],
            isLoading: true,
          },
        ]
        setSections(initialSections)
        setInitialLoading(false)

        // Load remaining sections in parallel
        const [discover, pop] = await Promise.all([
          searchYouTube('new music 2026'),
          searchYouTube('pop hits 2026'),
        ])
        if (cancelled) return

        setSections([
          initialSections[0],
          { ...initialSections[1], songs: discover.results || [], isLoading: false },
          { ...initialSections[2], songs: pop.results || [], isLoading: false },
        ])
      } catch (err) {
        console.error('Home load failed:', err)
        setInitialLoading(false)
      }
    }

    load()
    return () => { cancelled = true }
  }, [])

  return (
    <div style={styles.container}>
      {/* Greeting */}
      <div style={styles.greeting}>
        <h1 style={styles.greetingText}>
          {greeting()}{user ? `, ${name}` : ''}
        </h1>
      </div>

      {initialLoading ? (
        <div style={styles.loadingCenter}>
          <div className="utify-spinner" />
        </div>
      ) : (
        sections.map((section, i) => (
          <Section key={i} section={section} showBadge={i === 0} badgeText="Daily Mix" />
        ))
      )}

      <div style={{ height: 40 }} />

      <style>{`
        @keyframes utify-spin { to { transform: rotate(360deg); } }
        .utify-spinner {
          width: 36px; height: 36px; border-radius: 50%;
          border: 3px solid var(--color-highlight);
          border-top-color: var(--color-button);
          animation: utify-spin 0.7s linear infinite;
        }
        @keyframes utify-shimmer {
          0% { background-position: -400px 0; }
          100% { background-position: 400px 0; }
        }
        .skeleton {
          background: linear-gradient(90deg, var(--color-card) 25%, var(--color-highlight) 50%, var(--color-card) 75%);
          background-size: 800px 100%;
          animation: utify-shimmer 1.4s ease infinite;
          border-radius: 8px;
        }
      `}</style>
    </div>
  )
}

// ── Section ───────────────────────────────────────────────────────────────────

function Section({ section, showBadge, badgeText }) {
  return (
    <div style={styles.section}>
      {/* Header */}
      <div style={styles.sectionHeader}>
        <div>
          <p style={styles.sectionSubtitle}>{section.subtitle}</p>
          <h2 style={styles.sectionTitle}>{section.title}</h2>
        </div>
      </div>

      {/* Horizontal scroll row */}
      <div style={styles.scrollRow}>
        {section.isLoading
          ? Array.from({ length: 5 }).map((_, i) => <SkeletonCard key={i} />)
          : section.songs.map((song, i) => (
            <MusicCard
              key={song.id || i}
              song={song}
              showBadge={showBadge}
              badgeText={badgeText}
            />
          ))
        }
      </div>
    </div>
  )
}

// ── MusicCard — exact match of DesktopMusicCard in Flutter ───────────────────

function MusicCard({ song, showBadge, badgeText, playlist }) {
  const [hovered, setHovered] = useState(false)
  const [menuOpen, setMenuOpen] = useState(false)
  const [menuPos, setMenuPos] = useState({ x: 0, y: 0 })
  const { playSong, addToQueue } = usePlayerStore()
  const { toggleLike, isLiked, likedSongs, createPlaylist } = useLibraryStore()
  const { user } = useAuthStore()
  const menuRef = useRef(null)

  const liked = likedSongs?.some((s) => s.id === song.id)

  function handlePlay(e) {
    e.stopPropagation()
    playSong(song)
  }

  function handleContextMenu(e) {
    e.preventDefault()
    setMenuPos({ x: e.clientX, y: e.clientY })
    setMenuOpen(true)
  }

  // Close menu on outside click
  useEffect(() => {
    if (!menuOpen) return
    function handler(e) {
      if (menuRef.current && !menuRef.current.contains(e.target)) {
        setMenuOpen(false)
      }
    }
    window.addEventListener('mousedown', handler)
    return () => window.removeEventListener('mousedown', handler)
  }, [menuOpen])

  return (
    <div
      style={{ ...styles.card, flexShrink: 0 }}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onContextMenu={handleContextMenu}
      onClick={() => playSong(song)}
      role="button"
      tabIndex={0}
      aria-label={`Play ${song.title}`}
      onKeyDown={(e) => { if (e.key === 'Enter') playSong(song) }}
    >
      {/* Cover image stack */}
      <div style={styles.coverWrap}>
        {/* Album art */}
        {song.thumbnailUrl ? (
          <img
            src={song.thumbnailUrl}
            alt={song.title}
            style={styles.coverImg}
          />
        ) : (
          <div style={{ ...styles.coverImg, background: 'var(--color-card)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Music2 size={40} color='var(--color-subtext)' style={{ opacity: 0.54 }} />
          </div>
        )}

        {/* Gradient overlay */}
        <div style={styles.coverGradient} />

        {/* Badge */}
        {showBadge && badgeText && (
          <div style={styles.badge}>{badgeText}</div>
        )}

        {/* Hover overlays */}
        {hovered && (
          <>
            {/* Play button (bottom-right) */}
            <button
              onClick={handlePlay}
              style={styles.playBtn}
              aria-label={`Play ${song.title}`}
            >
              <Play size={26} color='var(--color-text)' fill='var(--color-text)' />
            </button>

            {/* More button (top-left) */}
            <button
              onClick={(e) => { e.stopPropagation(); handleContextMenu(e) }}
              style={styles.moreBtn}
              aria-label="More options"
            >
              <MoreHorizontal size={18} color='var(--color-text)' />
            </button>
          </>
        )}
      </div>

      {/* Title + channel */}
      <div style={styles.cardInfo}>
        <p style={styles.cardTitle}>{song.title}</p>
        <p style={styles.cardChannel}>{song.channelName}</p>
      </div>

      {/* Context menu */}
      {menuOpen && (
        <ContextMenu
          ref={menuRef}
          x={menuPos.x}
          y={menuPos.y}
          onClose={() => setMenuOpen(false)}
          items={[
            {
              label: 'Play',
              onClick: () => playSong(song),
            },
            {
              label: 'Add to queue',
              onClick: () => addToQueue(song),
            },
            {
              label: liked ? 'Remove from liked' : 'Like',
              onClick: () => user && toggleLike(user.uid, song),
            },
          ]}
        />
      )}
    </div>
  )
}

// ── SkeletonCard ──────────────────────────────────────────────────────────────

function SkeletonCard() {
  return (
    <div style={{ width: CARD_SIZE, flexShrink: 0 }}>
      <div className="skeleton" style={{ width: CARD_SIZE, height: CARD_SIZE, marginBottom: 8 }} />
      <div className="skeleton" style={{ width: 130, height: 12, marginBottom: 4 }} />
      <div className="skeleton" style={{ width: 90, height: 10 }} />
    </div>
  )
}

// ── ContextMenu ───────────────────────────────────────────────────────────────

import { forwardRef } from 'react'

const ContextMenu = forwardRef(function ContextMenu({ x, y, items, onClose }, ref) {
  return (
    <div
      ref={ref}
      style={{
        position: 'fixed',
        top: y,
        left: x,
        zIndex: 9999,
        background: 'var(--color-card)',
        border: '1px solid var(--color-shadow)',
        borderRadius: 8,
        minWidth: 180,
        boxShadow: '0 8px 24px rgba(0,0,0,0.4)',
        overflow: 'hidden',
      }}
    >
      {items.map((item, i) => (
        <button
          key={i}
          onClick={(e) => { e.stopPropagation(); item.onClick(); onClose() }}
          style={{
            display: 'block', width: '100%', textAlign: 'left',
            padding: '10px 14px', border: 'none', borderRadius: 0,
            background: 'transparent', color: 'var(--color-text)',
            fontSize: 13, cursor: 'pointer',
          }}
          onMouseEnter={(e) => { e.currentTarget.style.background = 'var(--color-highlight)' }}
          onMouseLeave={(e) => { e.currentTarget.style.background = 'transparent' }}
        >
          {item.label}
        </button>
      ))}
    </div>
  )
})

// ── Styles ────────────────────────────────────────────────────────────────────

const styles = {
  container: {
    background: 'var(--color-main)',
    borderRadius: 12,
    minHeight: '100%',
  },
  greeting: {
    padding: '28px 24px 0',
  },
  greetingText: {
    color: 'var(--color-text)',
    fontSize: 28,
    fontWeight: 800,
    margin: 0,
  },
  loadingCenter: {
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    padding: 60,
  },
  section: {
    padding: '24px 0 0',
  },
  sectionHeader: {
    padding: '0 24px',
    marginBottom: 12,
  },
  sectionSubtitle: {
    color: 'var(--color-subtext)',
    fontSize: 12,
    margin: 0,
  },
  sectionTitle: {
    color: 'var(--color-button)',
    fontSize: 24,
    fontWeight: 700,
    margin: 0,
  },
  scrollRow: {
    display: 'flex',
    gap: 16,
    overflowX: 'auto',
    overflowY: 'hidden',
    padding: '0 24px',
    scrollbarWidth: 'thin',
    scrollbarColor: 'var(--color-highlight-elevated) transparent',
    height: 260,
    alignItems: 'flex-start',
  },
  card: {
    width: CARD_SIZE,
    cursor: 'pointer',
  },
  coverWrap: {
    position: 'relative',
    width: CARD_SIZE,
    height: CARD_SIZE,
    borderRadius: 8,
    overflow: 'hidden',
    flexShrink: 0,
  },
  coverImg: {
    width: '100%',
    height: '100%',
    objectFit: 'cover',
    display: 'block',
  },
  coverGradient: {
    position: 'absolute',
    inset: 0,
    background: 'linear-gradient(to bottom, transparent 50%, rgba(0,0,0,0.67) 100%)',
    pointerEvents: 'none',
  },
  badge: {
    position: 'absolute',
    left: 8,
    bottom: 8,
    background: 'var(--color-button)',
    color: 'var(--color-text)',
    fontSize: 11,
    fontWeight: 700,
    padding: '4px 8px',
    borderRadius: 999,
    pointerEvents: 'none',
  },
  playBtn: {
    position: 'absolute',
    right: 8,
    bottom: 8,
    width: 46,
    height: 46,
    borderRadius: '50%',
    background: 'var(--color-button)',
    border: 'none',
    cursor: 'pointer',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    boxShadow: '0 2px 8px rgba(0,0,0,0.45)',
    transition: 'transform 120ms, background 120ms',
  },
  moreBtn: {
    position: 'absolute',
    left: 6,
    top: 6,
    background: 'rgba(0,0,0,0.54)',
    border: 'none',
    borderRadius: 999,
    width: 30,
    height: 30,
    cursor: 'pointer',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
  },
  cardInfo: {
    marginTop: 8,
  },
  cardTitle: {
    color: 'var(--color-text)',
    fontSize: 14,
    fontWeight: 500,
    margin: 0,
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap',
    maxWidth: CARD_SIZE,
  },
  cardChannel: {
    color: 'var(--color-subtext)',
    fontSize: 12,
    margin: '2px 0 0',
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap',
    maxWidth: CARD_SIZE,
  },
}
