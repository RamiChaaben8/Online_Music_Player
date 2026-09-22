/**
 * SearchView.jsx
 * Mirrors desktop_search_view.dart
 *
 * Features:
 *   • Search input pre-filled from ?q= URL param
 *   • Debounced 500 ms search via searchYouTube()
 *   • Results as SongRow list: #, thumbnail, title, channel, duration
 *   • Play-button on hover
 *   • Right-click context menu: Play, Add to Queue, Add to Playlist, Like
 *   • "Load more" button with nextPageToken pagination
 *   • Recent searches in localStorage (max 10), shown when input is focused + empty
 *   • Empty state, loading skeleton rows, error state
 */

import {
  useCallback,
  useEffect,
  useRef,
  useState,
} from 'react'
import { useSearchParams } from 'react-router-dom'
import { useAuthStore }    from '../stores/authStore'
import { usePlayerStore }  from '../stores/playerStore'
import { useLibraryStore } from '../stores/libraryStore'
import { searchYouTube }   from '../services/youtubeService'

// ── Recent-searches helpers (localStorage) ────────────────────────────────────

const LS_KEY = 'utify_recent_searches'
const MAX_RECENT = 10

function loadRecent() {
  try { return JSON.parse(localStorage.getItem(LS_KEY)) ?? [] }
  catch { return [] }
}

function saveRecent(term) {
  const trimmed = term.trim()
  if (!trimmed) return
  const prev = loadRecent().filter((t) => t !== trimmed)
  const next = [trimmed, ...prev].slice(0, MAX_RECENT)
  localStorage.setItem(LS_KEY, JSON.stringify(next))
}

function clearRecent() {
  localStorage.removeItem(LS_KEY)
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function fmtDuration(secs) {
  if (!secs) return ''
  const m = Math.floor(secs / 60)
  const s = String(secs % 60).padStart(2, '0')
  return `${m}:${s}`
}

// ── ContextMenu ───────────────────────────────────────────────────────────────

function ContextMenu({ x, y, song, onClose, playlists, uid }) {
  const playSong      = usePlayerStore((s) => s.playSong)
  const addToQueue    = usePlayerStore((s) => s.addToQueue)
  const toggleLike    = useLibraryStore((s) => s.toggleLike)
  const isLiked       = useLibraryStore((s) => s.isLiked)
  const addToPlaylist = useLibraryStore((s) => s.addSongToPlaylist)

  const [submenuOpen, setSubmenuOpen] = useState(false)
  const menuRef = useRef(null)

  // Close on outside click
  useEffect(() => {
    const handler = (e) => {
      if (menuRef.current && !menuRef.current.contains(e.target)) onClose()
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [onClose])

  const liked = isLiked(song.id)

  const action = (fn) => (e) => {
    e.stopPropagation()
    fn()
    onClose()
  }

  return (
    <div
      ref={menuRef}
      role="menu"
      style={{ ...styles.ctxMenu, top: y, left: x }}
    >
      <button
        role="menuitem"
        style={styles.ctxItem}
        onClick={action(() => playSong(song))}
      >
        <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M8 5v14l11-7z" /></svg>
        Play
      </button>

      <button
        role="menuitem"
        style={styles.ctxItem}
        onClick={action(() => addToQueue(song))}
      >
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
          <line x1="8" y1="6" x2="21" y2="6" /><line x1="8" y1="12" x2="21" y2="12" /><line x1="8" y1="18" x2="21" y2="18" />
          <line x1="3" y1="6" x2="3.01" y2="6" /><line x1="3" y1="12" x2="3.01" y2="12" /><line x1="3" y1="18" x2="3.01" y2="18" />
        </svg>
        Add to Queue
      </button>

      {/* Add to Playlist sub-menu trigger */}
      <div
        role="menuitem"
        style={{ ...styles.ctxItem, justifyContent: 'space-between', position: 'relative' }}
        onMouseEnter={() => setSubmenuOpen(true)}
        onMouseLeave={() => setSubmenuOpen(false)}
      >
        <span style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
            <path d="M12 5v14M5 12h14" />
          </svg>
          Add to Playlist
        </span>
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
          <polyline points="9 18 15 12 9 6" />
        </svg>

        {/* Sub-menu */}
        {submenuOpen && (
          <div style={styles.subMenu}>
            {playlists.length === 0 && (
              <span style={{ ...styles.ctxItem, color: 'var(--color-subtext)', cursor: 'default' }}>
                No playlists
              </span>
            )}
            {playlists.map((pl) => (
              <button
                key={pl.id}
                role="menuitem"
                style={styles.ctxItem}
                onClick={action(() => uid && addToPlaylist(uid, pl.id, song))}
              >
                {pl.name}
              </button>
            ))}
          </div>
        )}
      </div>

      <div style={styles.ctxDivider} />

      <button
        role="menuitem"
        style={styles.ctxItem}
        onClick={action(() => uid && toggleLike(uid, song))}
      >
        <svg width="14" height="14" viewBox="0 0 24 24" fill={liked ? 'var(--color-button)' : 'none'} stroke={liked ? 'var(--color-button)' : 'currentColor'} strokeWidth="2" aria-hidden="true">
          <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z" />
        </svg>
        {liked ? 'Unlike' : 'Like'}
      </button>
    </div>
  )
}

// ── SongRow ───────────────────────────────────────────────────────────────────

function SongRow({ song, index, onPlay, onContextMenu }) {
  const [hovered, setHovered] = useState(false)

  return (
    <div
      role="row"
      style={{
        ...styles.row,
        background: hovered ? 'var(--color-highlight)' : 'transparent',
      }}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onDoubleClick={() => onPlay(song)}
      onContextMenu={(e) => { e.preventDefault(); onContextMenu(e, song) }}
    >
      {/* # / Play button */}
      <div style={styles.rowIndex} aria-label={`Track ${index}`}>
        {hovered ? (
          <button
            aria-label={`Play ${song.title}`}
            style={styles.rowPlayBtn}
            onClick={() => onPlay(song)}
          >
            <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
              <path d="M8 5v14l11-7z" />
            </svg>
          </button>
        ) : (
          <span style={{ color: 'var(--color-subtext)', fontSize: 13 }}>{index}</span>
        )}
      </div>

      {/* Thumbnail */}
      <img
        src={song.thumbnailUrl}
        alt=""
        width={40}
        height={40}
        loading="lazy"
        style={styles.rowThumb}
        onError={(e) => { e.currentTarget.src = 'https://i.ytimg.com/vi/default/mqdefault.jpg' }}
      />

      {/* Title + channel */}
      <div style={styles.rowMeta}>
        <span style={styles.rowTitle} title={song.title}>{song.title}</span>
        <span style={styles.rowChannel} title={song.channelName}>{song.channelName}</span>
      </div>

      {/* Duration */}
      <span style={styles.rowDuration}>{fmtDuration(song.durationSeconds)}</span>
    </div>
  )
}

// ── SkeletonRow ───────────────────────────────────────────────────────────────

function SkeletonRow() {
  return (
    <div style={{ ...styles.row, pointerEvents: 'none' }}>
      <div style={{ width: 16, height: 16, ...styles.skeletonBox }} />
      <div style={{ width: 40, height: 40, borderRadius: 4, ...styles.skeletonBox }} />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 6 }}>
        <div style={{ ...styles.skeletonBox, height: 12, width: '55%' }} />
        <div style={{ ...styles.skeletonBox, height: 10, width: '35%' }} />
      </div>
      <div style={{ ...styles.skeletonBox, height: 10, width: 36 }} />
      <style>{`
        @keyframes sv-shimmer {
          0%   { background-position: -400px 0; }
          100% { background-position:  400px 0; }
        }
      `}</style>
    </div>
  )
}

// ── SearchView ────────────────────────────────────────────────────────────────

export default function SearchView() {
  const [searchParams, setSearchParams] = useSearchParams()
  const initialQuery = searchParams.get('q') ?? ''

  const user      = useAuthStore((s) => s.user)
  const playSong  = usePlayerStore((s) => s.playSong)
  const playlists = useLibraryStore((s) => s.playlists)

  const [query,          setQuery]          = useState(initialQuery)
  const [results,        setResults]        = useState([])
  const [nextPageToken,  setNextPageToken]  = useState(null)
  const [loading,        setLoading]        = useState(false)
  const [loadingMore,    setLoadingMore]    = useState(false)
  const [error,          setError]          = useState(null)
  const [inputFocused,   setInputFocused]   = useState(false)
  const [recentSearches, setRecentSearches] = useState(loadRecent)
  const [ctxMenu,        setCtxMenu]        = useState(null) // { x, y, song }

  const debounceRef  = useRef(null)
  const inputRef     = useRef(null)

  // ── Perform a fresh search ────────────────────────────────────────────────

  const doSearch = useCallback(async (term, replace = true) => {
    if (!term?.trim()) {
      setResults([])
      setNextPageToken(null)
      return
    }

    setLoading(true)
    setError(null)
    if (replace) setResults([])

    try {
      const { results: songs, nextPageToken: token } = await searchYouTube(term.trim())
      setResults(songs || [])
      setNextPageToken(token ?? null)
      saveRecent(term)
      setRecentSearches(loadRecent())
    } catch (err) {
      setError(err.message || 'Search failed. Please try again.')
    } finally {
      setLoading(false)
    }
  }, [])

  // ── Load more ─────────────────────────────────────────────────────────────

  const loadMore = async () => {
    if (!nextPageToken || loadingMore) return
    setLoadingMore(true)
    try {
      const { results: songs, nextPageToken: token } = await searchYouTube(query.trim(), nextPageToken)
      setResults((prev) => [...prev, ...(songs || [])])
      setNextPageToken(token ?? null)
    } catch (err) {
      setError(err.message || 'Failed to load more results.')
    } finally {
      setLoadingMore(false)
    }
  }

  // ── Debounced query change ────────────────────────────────────────────────

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current)

    // Sync URL param
    if (query.trim()) {
      setSearchParams({ q: query.trim() }, { replace: true })
    } else {
      setSearchParams({}, { replace: true })
    }

    if (!query.trim()) {
      setResults([])
      setNextPageToken(null)
      setError(null)
      return
    }

    debounceRef.current = setTimeout(() => {
      doSearch(query)
    }, 500)

    return () => clearTimeout(debounceRef.current)
  }, [query, doSearch, setSearchParams])

  // Initial search if ?q= param present
  useEffect(() => {
    if (initialQuery) doSearch(initialQuery)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // ── Context menu ──────────────────────────────────────────────────────────

  const openContextMenu = (e, song) => {
    // Clamp to viewport
    const x = Math.min(e.clientX, window.innerWidth  - 200)
    const y = Math.min(e.clientY, window.innerHeight - 220)
    setCtxMenu({ x, y, song })
  }

  const closeContextMenu = useCallback(() => setCtxMenu(null), [])

  // Close context menu on Escape
  useEffect(() => {
    const handler = (e) => { if (e.key === 'Escape') closeContextMenu() }
    document.addEventListener('keydown', handler)
    return () => document.removeEventListener('keydown', handler)
  }, [closeContextMenu])

  // ── Play a song ───────────────────────────────────────────────────────────

  const handlePlay = (song) => {
    const idx = results.indexOf(song)
    playSong(song, results.length > 0 ? results : [song], Math.max(0, idx))
  }

  // ── Recent-search click ───────────────────────────────────────────────────

  const pickRecent = (term) => {
    setQuery(term)
    inputRef.current?.blur()
  }

  const showRecent = inputFocused && !query.trim() && recentSearches.length > 0

  // ── Render ────────────────────────────────────────────────────────────────

  const showEmpty  = !loading && !error && query.trim() && results.length === 0
  const showResult = !loading && results.length > 0

  return (
    <div style={styles.page}>
      {/* ── Search input ── */}
      <div style={styles.inputWrap}>
        <div style={{ position: 'relative', width: '100%', maxWidth: 600 }}>
          {/* Search icon */}
          <svg
            style={styles.inputIcon}
            width="18"
            height="18"
            viewBox="0 0 24 24"
            fill="none"
            stroke="var(--color-subtext)"
            strokeWidth="2"
            aria-hidden="true"
          >
            <circle cx="11" cy="11" r="8" />
            <line x1="21" y1="21" x2="16.65" y2="16.65" />
          </svg>

          <input
            ref={inputRef}
            type="search"
            value={query}
            placeholder="What do you want to listen to?"
            aria-label="Search music"
            autoComplete="off"
            style={styles.input}
            onChange={(e) => setQuery(e.target.value)}
            onFocus={() => setInputFocused(true)}
            onBlur={() => setTimeout(() => setInputFocused(false), 150)}
          />

          {query && (
            <button
              aria-label="Clear search"
              style={styles.clearBtn}
              onClick={() => { setQuery(''); inputRef.current?.focus() }}
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" aria-hidden="true">
                <line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" />
              </svg>
            </button>
          )}

          {/* Recent searches dropdown */}
          {showRecent && (
            <div style={styles.recentDropdown} role="listbox" aria-label="Recent searches">
              <div style={styles.recentHeader}>
                <span style={{ color: 'var(--color-subtext)', fontSize: 12, fontWeight: 600, letterSpacing: '0.05em' }}>
                  RECENT SEARCHES
                </span>
                <button
                  style={styles.recentClearBtn}
                  onClick={() => { clearRecent(); setRecentSearches([]) }}
                >
                  Clear all
                </button>
              </div>
              {recentSearches.map((term) => (
                <button
                  key={term}
                  role="option"
                  aria-selected="false"
                  style={styles.recentItem}
                  onMouseDown={() => pickRecent(term)}
                >
                  <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="var(--color-subtext)" strokeWidth="2" aria-hidden="true">
                    <polyline points="1 4 1 10 7 10" /><path d="M3.51 15a9 9 0 1 0 .49-3.85" />
                  </svg>
                  {term}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* ── Error ── */}
      {error && (
        <div style={styles.errorBox} role="alert">
          <span style={{ color: 'var(--color-error)' }}>{error}</span>
          <button style={styles.retryBtn} onClick={() => doSearch(query)}>Retry</button>
        </div>
      )}

      {/* ── Empty initial state (no query) ── */}
      {!query.trim() && !loading && (
        <div style={styles.emptyState}>
          <svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="var(--color-subtext)" strokeWidth="1.2" aria-hidden="true">
            <circle cx="11" cy="11" r="8" />
            <line x1="21" y1="21" x2="16.65" y2="16.65" />
          </svg>
          <p style={{ color: 'var(--color-subtext)', marginTop: 16, fontSize: 15 }}>
            Search for songs, artists, or albums
          </p>
        </div>
      )}

      {/* ── Empty results ── */}
      {showEmpty && (
        <div style={styles.emptyState}>
          <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="var(--color-subtext)" strokeWidth="1.2" aria-hidden="true">
            <circle cx="11" cy="11" r="8" />
            <line x1="21" y1="21" x2="16.65" y2="16.65" />
          </svg>
          <p style={{ color: 'var(--color-subtext)', marginTop: 12, fontSize: 15 }}>
            No results for &ldquo;{query}&rdquo;
          </p>
        </div>
      )}

      {/* ── Loading skeletons ── */}
      {loading && (
        <div role="list" aria-label="Loading results">
          {Array.from({ length: 8 }).map((_, i) => (
            <SkeletonRow key={i} />
          ))}
        </div>
      )}

      {/* ── Results list ── */}
      {showResult && (
        <div role="list" aria-label="Search results">
          {results.map((song, i) => (
            <SongRow
              key={`${song.id}-${i}`}
              song={song}
              index={i + 1}
              onPlay={handlePlay}
              onContextMenu={openContextMenu}
            />
          ))}
        </div>
      )}

      {/* ── Load more ── */}
      {showResult && nextPageToken && (
        <div style={{ display: 'flex', justifyContent: 'center', padding: '24px 0' }}>
          <button
            style={styles.loadMoreBtn}
            onClick={loadMore}
            disabled={loadingMore}
            aria-label="Load more results"
          >
            {loadingMore ? 'Loading…' : 'Load more'}
          </button>
        </div>
      )}

      {/* ── Context menu ── */}
      {ctxMenu && (
        <ContextMenu
          x={ctxMenu.x}
          y={ctxMenu.y}
          song={ctxMenu.song}
          onClose={closeContextMenu}
          playlists={playlists}
          uid={user?.uid}
        />
      )}
    </div>
  )
}

// ── Styles ────────────────────────────────────────────────────────────────────

const SHIMMER = `
  linear-gradient(
    90deg,
    var(--color-highlight) 25%,
    var(--color-highlight-elevated) 50%,
    var(--color-highlight) 75%
  )
`

const styles = {
  page: {
    padding: '32px 24px 120px',
    maxWidth: 900,
    margin: '0 auto',
    position: 'relative',
  },

  inputWrap: {
    marginBottom: 32,
    display: 'flex',
    alignItems: 'center',
  },

  inputIcon: {
    position: 'absolute',
    left: 14,
    top: '50%',
    transform: 'translateY(-50%)',
    pointerEvents: 'none',
  },

  input: {
    width: '100%',
    padding: '12px 40px 12px 44px',
    borderRadius: 24,
    border: '1px solid var(--color-highlight-elevated)',
    background: 'var(--color-card)',
    color: 'var(--color-text)',
    fontSize: 15,
    outline: 'none',
    boxSizing: 'border-box',
    transition: 'border-color 0.15s',
  },

  clearBtn: {
    position: 'absolute',
    right: 14,
    top: '50%',
    transform: 'translateY(-50%)',
    background: 'none',
    border: 'none',
    color: 'var(--color-subtext)',
    cursor: 'pointer',
    display: 'flex',
    alignItems: 'center',
    padding: 4,
    borderRadius: '50%',
  },

  recentDropdown: {
    position: 'absolute',
    top: 'calc(100% + 6px)',
    left: 0,
    right: 0,
    background: 'var(--color-card)',
    border: '1px solid var(--color-highlight-elevated)',
    borderRadius: 8,
    boxShadow: '0 8px 24px rgba(0,0,0,0.35)',
    zIndex: 50,
    overflow: 'hidden',
  },

  recentHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '10px 16px 6px',
  },

  recentClearBtn: {
    background: 'none',
    border: 'none',
    color: 'var(--color-subtext)',
    fontSize: 12,
    cursor: 'pointer',
    textDecoration: 'underline',
    padding: 0,
  },

  recentItem: {
    display: 'flex',
    alignItems: 'center',
    gap: 10,
    width: '100%',
    padding: '10px 16px',
    background: 'none',
    border: 'none',
    color: 'var(--color-text)',
    fontSize: 14,
    cursor: 'pointer',
    textAlign: 'left',
    transition: 'background 0.1s',
  },

  // Song row
  row: {
    display: 'flex',
    alignItems: 'center',
    gap: 12,
    padding: '6px 8px',
    borderRadius: 6,
    cursor: 'default',
    transition: 'background 0.1s',
    userSelect: 'none',
  },

  rowIndex: {
    width: 28,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
  },

  rowPlayBtn: {
    background: 'none',
    border: 'none',
    color: 'var(--color-text)',
    cursor: 'pointer',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 4,
    borderRadius: '50%',
  },

  rowThumb: {
    width: 40,
    height: 40,
    borderRadius: 4,
    objectFit: 'cover',
    flexShrink: 0,
    background: 'var(--color-highlight)',
  },

  rowMeta: {
    flex: 1,
    display: 'flex',
    flexDirection: 'column',
    gap: 2,
    minWidth: 0,
  },

  rowTitle: {
    fontSize: 14,
    fontWeight: 500,
    color: 'var(--color-text)',
    whiteSpace: 'nowrap',
    overflow: 'hidden',
    textOverflow: 'ellipsis',
  },

  rowChannel: {
    fontSize: 12,
    color: 'var(--color-subtext)',
    whiteSpace: 'nowrap',
    overflow: 'hidden',
    textOverflow: 'ellipsis',
  },

  rowDuration: {
    fontSize: 12,
    color: 'var(--color-subtext)',
    flexShrink: 0,
    minWidth: 36,
    textAlign: 'right',
  },

  // Context menu
  ctxMenu: {
    position: 'fixed',
    background: 'var(--color-card)',
    border: '1px solid var(--color-highlight-elevated)',
    borderRadius: 8,
    boxShadow: '0 8px 24px rgba(0,0,0,0.5)',
    minWidth: 200,
    zIndex: 200,
    padding: '4px 0',
    overflow: 'hidden',
  },

  ctxItem: {
    display: 'flex',
    alignItems: 'center',
    gap: 10,
    width: '100%',
    padding: '10px 16px',
    background: 'none',
    border: 'none',
    color: 'var(--color-text)',
    fontSize: 14,
    cursor: 'pointer',
    textAlign: 'left',
    transition: 'background 0.1s',
  },

  ctxDivider: {
    height: 1,
    background: 'var(--color-highlight)',
    margin: '4px 0',
  },

  subMenu: {
    position: 'absolute',
    top: 0,
    left: '100%',
    background: 'var(--color-card)',
    border: '1px solid var(--color-highlight-elevated)',
    borderRadius: 8,
    boxShadow: '0 8px 24px rgba(0,0,0,0.5)',
    minWidth: 180,
    maxHeight: 280,
    overflowY: 'auto',
    zIndex: 210,
    padding: '4px 0',
  },

  // Skeleton
  skeletonBox: {
    background: SHIMMER,
    backgroundSize: '400px 100%',
    animation: 'sv-shimmer 1.4s infinite linear',
    borderRadius: 4,
  },

  emptyState: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    padding: '80px 0',
  },

  errorBox: {
    display: 'flex',
    alignItems: 'center',
    gap: 16,
    padding: '12px 0 24px',
    fontSize: 14,
  },

  retryBtn: {
    padding: '8px 18px',
    borderRadius: 20,
    border: '1px solid var(--color-button)',
    background: 'transparent',
    color: 'var(--color-button)',
    fontSize: 13,
    fontWeight: 600,
    cursor: 'pointer',
  },

  loadMoreBtn: {
    padding: '10px 32px',
    borderRadius: 24,
    border: '1px solid var(--color-highlight-elevated)',
    background: 'var(--color-card)',
    color: 'var(--color-text)',
    fontSize: 14,
    fontWeight: 600,
    cursor: 'pointer',
    transition: 'background 0.15s',
  },
}
