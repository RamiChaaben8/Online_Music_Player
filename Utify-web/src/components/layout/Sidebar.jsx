/**
 * Sidebar.jsx
 * Collapsible left-hand library navigation panel.
 *
 * Mirrors desktop_sidebar.dart from the Flutter app.
 *
 * Layout (expanded, 240 px):
 *   ┌──────────────────────────────────────┐
 *   │ [Your Library]            [+] [<]    │  ← header
 *   ├──────────────────────────────────────┤
 *   │ ♥ Liked Songs  (n songs)             │  ← liked songs tile
 *   ├──────────────────────────────────────┤
 *   │ [thumb] Pinned playlist  (n)  [···]  │  ← pinned first
 *   │ [thumb] Playlist B       (n)  [···]  │
 *   │  …                                   │
 *   └──────────────────────────────────────┘
 *
 * Layout (collapsed, 64 px):
 *   Icon-only column with tooltips.
 *
 * Features
 * ─────────
 * • Collapse toggle (ChevronLeft / ChevronRight)
 * • Inline "create playlist" input on '+' press
 * • Liked Songs tile → /liked-songs
 * • Playlist tiles with thumbnail, name, count, selection highlight
 * • Right-click OR '…' hover button → context menu
 *     – Add to Queue  (all songs → playerStore.addToQueue)
 *     – Rename        (inline edit)
 *     – Delete        (confirm → libraryStore.deletePlaylist)
 *     – Invite Collaborator (uid input dialog)
 * • Pinned playlists sorted to top
 * • Collapsed icons-only with tooltip
 */

import {
  useCallback,
  useEffect,
  useRef,
  useState,
} from 'react'
import { useNavigate, useLocation } from 'react-router-dom'
import {
  ChevronLeft,
  ChevronRight,
  Heart,
  Music2,
  MoreHorizontal,
  Pin,
  Plus,
  ListPlus,
  Pencil,
  Trash2,
  UserPlus,
} from 'lucide-react'

import { useLibraryStore } from '../../stores/libraryStore'
import { useAuthStore }    from '../../stores/authStore'
import { usePlayerStore }  from '../../stores/playerStore'

// ── Constants ─────────────────────────────────────────────────────────────────

const EXPANDED_WIDTH  = 240
const COLLAPSED_WIDTH = 64

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Gradient placeholder for playlists with no thumbnail. */
const PLACEHOLDER_GRADIENTS = [
  'linear-gradient(135deg, #1DB954 0%, #191414 100%)',
  'linear-gradient(135deg, #7B4FE9 0%, #191414 100%)',
  'linear-gradient(135deg, #E8173A 0%, #191414 100%)',
  'linear-gradient(135deg, #FF6D00 0%, #191414 100%)',
  'linear-gradient(135deg, #00BCD4 0%, #191414 100%)',
]

function placeholderGradient(playlistId = '') {
  let n = 0
  for (let i = 0; i < playlistId.length; i++) n += playlistId.charCodeAt(i)
  return PLACEHOLDER_GRADIENTS[n % PLACEHOLDER_GRADIENTS.length]
}

function firstThumbnail(playlist) {
  return playlist?.songs?.[0]?.thumbnailUrl || null
}

// ── Tooltip wrapper ───────────────────────────────────────────────────────────
// Shown in collapsed mode when hovering an icon.

function Tooltip({ label, children }) {
  const [visible, setVisible] = useState(false)

  return (
    <div
      style={{ position: 'relative', display: 'flex' }}
      onMouseEnter={() => setVisible(true)}
      onMouseLeave={() => setVisible(false)}
    >
      {children}
      {visible && (
        <div
          role="tooltip"
          style={{
            position:     'absolute',
            left:         'calc(100% + 10px)',
            top:          '50%',
            transform:    'translateY(-50%)',
            background:   'var(--color-card)',
            color:        'var(--color-text)',
            fontSize:     12,
            fontWeight:   600,
            padding:      '5px 10px',
            borderRadius: 6,
            whiteSpace:   'nowrap',
            pointerEvents:'none',
            boxShadow:    '0 4px 12px rgba(0,0,0,0.5)',
            zIndex:       500,
            border:       '1px solid var(--color-highlight)',
          }}
        >
          {label}
        </div>
      )}
    </div>
  )
}

// ── Context Menu ──────────────────────────────────────────────────────────────

function ContextMenu({ x, y, playlist, onClose, onRename, onInvite }) {
  const { user }                  = useAuthStore()
  const { deletePlaylist }        = useLibraryStore()
  const { addToQueue }            = usePlayerStore()
  const menuRef                   = useRef(null)

  // Close on outside click or Escape
  useEffect(() => {
    function handleClick(e) {
      if (menuRef.current && !menuRef.current.contains(e.target)) onClose()
    }
    function handleKey(e) {
      if (e.key === 'Escape') onClose()
    }
    document.addEventListener('mousedown', handleClick)
    document.addEventListener('keydown',   handleKey)
    return () => {
      document.removeEventListener('mousedown', handleClick)
      document.removeEventListener('keydown',   handleKey)
    }
  }, [onClose])

  // Clamp to viewport edges
  const [pos, setPos] = useState({ top: y, left: x })
  useEffect(() => {
    if (!menuRef.current) return
    const { offsetWidth: w, offsetHeight: h } = menuRef.current
    const vw = window.innerWidth
    const vh = window.innerHeight
    setPos({
      top:  Math.min(y, vh - h - 8),
      left: Math.min(x, vw - w - 8),
    })
  }, [x, y])

  const handleAddToQueue = () => {
    playlist.songs?.forEach((song) => addToQueue(song))
    onClose()
  }

  const handleDelete = async () => {
    if (!window.confirm(`Delete playlist "${playlist.name}"? This cannot be undone.`)) return
    onClose()
    if (user) await deletePlaylist(user.uid, playlist.id)
  }

  const itemStyle = (destructive = false) => ({
    display:    'flex',
    alignItems: 'center',
    gap:        9,
    width:      '100%',
    padding:    '9px 14px',
    background: 'none',
    border:     'none',
    color:      destructive ? 'var(--color-error)' : 'var(--color-text)',
    fontSize:   13,
    cursor:     'pointer',
    textAlign:  'left',
    transition: 'background 0.1s',
    borderRadius: 4,
  })

  const hoverHandlers = (destructive = false) => ({
    onMouseEnter: (e) => {
      e.currentTarget.style.background = destructive
        ? 'rgba(232,23,58,0.12)'
        : 'var(--color-highlight)'
    },
    onMouseLeave: (e) => {
      e.currentTarget.style.background = 'transparent'
    },
  })

  return (
    <div
      ref={menuRef}
      role="menu"
      aria-label={`Options for ${playlist.name}`}
      style={{
        position:     'fixed',
        top:          pos.top,
        left:         pos.left,
        minWidth:     190,
        background:   'var(--color-card)',
        border:       '1px solid var(--color-highlight)',
        borderRadius: 8,
        boxShadow:    '0 8px 24px rgba(0,0,0,0.55)',
        zIndex:       600,
        padding:      '4px 4px',
        userSelect:   'none',
      }}
      // Prevent the right-click that opened us from closing via document handler
      onContextMenu={(e) => e.preventDefault()}
    >
      <button
        type="button"
        role="menuitem"
        style={itemStyle()}
        onClick={handleAddToQueue}
        {...hoverHandlers()}
      >
        <ListPlus size={15} style={{ color: 'var(--color-subtext)', flexShrink: 0 }} />
        Add to Queue
      </button>

      <button
        type="button"
        role="menuitem"
        style={itemStyle()}
        onClick={() => { onRename(); onClose() }}
        {...hoverHandlers()}
      >
        <Pencil size={15} style={{ color: 'var(--color-subtext)', flexShrink: 0 }} />
        Rename
      </button>

      <button
        type="button"
        role="menuitem"
        style={itemStyle()}
        onClick={() => { onInvite(); onClose() }}
        {...hoverHandlers()}
      >
        <UserPlus size={15} style={{ color: 'var(--color-subtext)', flexShrink: 0 }} />
        Invite Collaborator
      </button>

      {/* Divider */}
      <div style={{ height: 1, background: 'var(--color-highlight)', margin: '3px 4px' }} />

      <button
        type="button"
        role="menuitem"
        style={itemStyle(true)}
        onClick={handleDelete}
        {...hoverHandlers(true)}
      >
        <Trash2 size={15} style={{ flexShrink: 0 }} />
        Delete
      </button>
    </div>
  )
}

// ── Invite Collaborator Dialog ────────────────────────────────────────────────

function InviteDialog({ playlist, onClose }) {
  const [uid, setUid]       = useState('')
  const [status, setStatus] = useState(null) // null | 'sending' | 'sent' | 'error'
  const inputRef            = useRef(null)

  useEffect(() => {
    inputRef.current?.focus()
    function handleKey(e) {
      if (e.key === 'Escape') onClose()
    }
    document.addEventListener('keydown', handleKey)
    return () => document.removeEventListener('keydown', handleKey)
  }, [onClose])

  const handleSend = async () => {
    const trimmed = uid.trim()
    if (!trimmed) return
    setStatus('sending')
    // Placeholder — real implementation would call a Firestore invite function.
    // For now we optimistically report success after a brief delay.
    await new Promise((r) => setTimeout(r, 600))
    setStatus('sent')
  }

  return (
    /* Backdrop */
    <div
      role="dialog"
      aria-modal="true"
      aria-label="Invite collaborator"
      style={{
        position:       'fixed',
        inset:          0,
        background:     'rgba(0,0,0,0.65)',
        display:        'flex',
        alignItems:     'center',
        justifyContent: 'center',
        zIndex:         700,
      }}
      onMouseDown={(e) => { if (e.target === e.currentTarget) onClose() }}
    >
      <div
        style={{
          background:   'var(--color-card)',
          border:       '1px solid var(--color-highlight)',
          borderRadius: 12,
          padding:      '24px 28px',
          width:        340,
          boxShadow:    '0 12px 40px rgba(0,0,0,0.6)',
          display:      'flex',
          flexDirection:'column',
          gap:          14,
        }}
        onMouseDown={(e) => e.stopPropagation()}
      >
        <h2 style={{ margin: 0, fontSize: 16, fontWeight: 700, color: 'var(--color-text)' }}>
          Invite Collaborator
        </h2>
        <p style={{ margin: 0, fontSize: 13, color: 'var(--color-subtext)' }}>
          Enter the user's UID to give them access to <strong style={{ color: 'var(--color-text)' }}>{playlist.name}</strong>.
        </p>

        {status === 'sent' ? (
          <p style={{ color: 'var(--color-button)', fontSize: 14, fontWeight: 600, margin: 0 }}>
            ✓ Invite sent!
          </p>
        ) : (
          <>
            <input
              ref={inputRef}
              type="text"
              placeholder="User UID"
              value={uid}
              onChange={(e) => setUid(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && handleSend()}
              style={{
                background:   'var(--color-highlight)',
                border:       '1px solid var(--color-highlight-elevated)',
                borderRadius: 6,
                padding:      '8px 12px',
                color:        'var(--color-text)',
                fontSize:     14,
                outline:      'none',
                width:        '100%',
                boxSizing:    'border-box',
              }}
            />
            <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
              <button
                type="button"
                onClick={onClose}
                style={{
                  padding:      '7px 16px',
                  background:   'var(--color-highlight)',
                  border:       'none',
                  borderRadius: 6,
                  color:        'var(--color-text)',
                  fontSize:     13,
                  cursor:       'pointer',
                }}
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleSend}
                disabled={status === 'sending' || !uid.trim()}
                style={{
                  padding:    '7px 16px',
                  background: 'var(--color-button)',
                  border:     'none',
                  borderRadius: 6,
                  color:      '#fff',
                  fontSize:   13,
                  fontWeight: 600,
                  cursor:     status === 'sending' || !uid.trim() ? 'not-allowed' : 'pointer',
                  opacity:    status === 'sending' || !uid.trim() ? 0.6 : 1,
                }}
              >
                {status === 'sending' ? 'Sending…' : 'Send Invite'}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  )
}

// ── PlaylistRow ───────────────────────────────────────────────────────────────

function PlaylistRow({ playlist, collapsed, selected, onContextMenu }) {
  const navigate            = useNavigate()
  const { user }            = useAuthStore()
  const { updatePlaylist }  = useLibraryStore()

  const [hovered,     setHovered]     = useState(false)
  const [renaming,    setRenaming]    = useState(false)
  const [renameValue, setRenameValue] = useState(playlist.name)
  const [showInvite,  setShowInvite]  = useState(false)
  const renameInputRef                = useRef(null)

  // Focus the rename input as soon as it mounts
  useEffect(() => {
    if (renaming) renameInputRef.current?.select()
  }, [renaming])

  const handleClick = () => {
    if (!renaming) navigate(`/playlist/${playlist.id}`)
  }

  const handleRightClick = (e) => {
    e.preventDefault()
    onContextMenu(e.clientX, e.clientY, playlist, startRename, () => setShowInvite(true))
  }

  const handleDotClick = (e) => {
    e.stopPropagation()
    onContextMenu(e.clientX, e.clientY, playlist, startRename, () => setShowInvite(true))
  }

  const startRename = () => {
    setRenameValue(playlist.name)
    setRenaming(true)
  }

  const commitRename = async () => {
    const trimmed = renameValue.trim()
    setRenaming(false)
    if (trimmed && trimmed !== playlist.name && user) {
      await updatePlaylist(user.uid, playlist.id, { name: trimmed })
    }
  }

  const thumb = firstThumbnail(playlist)
  const rowBg = selected
    ? 'var(--color-selected-row)'
    : hovered
      ? 'var(--color-highlight)'
      : 'transparent'

  if (collapsed) {
    return (
      <>
        <Tooltip label={playlist.name}>
          <button
            type="button"
            aria-label={playlist.name}
            onClick={handleClick}
            onContextMenu={handleRightClick}
            style={{
              width:          '100%',
              display:        'flex',
              alignItems:     'center',
              justifyContent: 'center',
              padding:        '10px 0',
              background:     selected ? 'var(--color-selected-row)' : 'transparent',
              border:         'none',
              cursor:         'pointer',
              color:          selected ? 'var(--color-button)' : 'var(--color-subtext)',
              borderRadius:   8,
              transition:     'background 0.15s, color 0.15s',
            }}
            onMouseEnter={(e) => {
              if (!selected) {
                e.currentTarget.style.background = 'var(--color-highlight)'
                e.currentTarget.style.color      = 'var(--color-text)'
              }
            }}
            onMouseLeave={(e) => {
              if (!selected) {
                e.currentTarget.style.background = 'transparent'
                e.currentTarget.style.color      = 'var(--color-subtext)'
              }
            }}
          >
            <Music2 size={20} />
          </button>
        </Tooltip>

        {showInvite && (
          <InviteDialog playlist={playlist} onClose={() => setShowInvite(false)} />
        )}
      </>
    )
  }

  return (
    <>
      <div
        role="button"
        tabIndex={0}
        aria-label={`${playlist.name}, ${playlist.songs?.length ?? 0} songs`}
        aria-current={selected ? 'page' : undefined}
        onClick={handleClick}
        onContextMenu={handleRightClick}
        onKeyDown={(e) => e.key === 'Enter' && handleClick()}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        style={{
          display:      'flex',
          alignItems:   'center',
          gap:          10,
          padding:      '6px 12px',
          borderRadius: 6,
          background:   rowBg,
          cursor:       renaming ? 'default' : 'pointer',
          transition:   'background 0.12s',
          userSelect:   'none',
          position:     'relative',
          margin:       '1px 4px',
        }}
      >
        {/* Thumbnail */}
        <div
          aria-hidden="true"
          style={{
            width:        42,
            height:       42,
            borderRadius: 4,
            flexShrink:   0,
            overflow:     'hidden',
            background:   thumb ? undefined : placeholderGradient(playlist.id),
          }}
        >
          {thumb && (
            <img
              src={thumb}
              alt=""
              style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
            />
          )}
        </div>

        {/* Name + count */}
        <div style={{ flexGrow: 1, minWidth: 0 }}>
          {renaming ? (
            <input
              ref={renameInputRef}
              type="text"
              value={renameValue}
              onClick={(e) => e.stopPropagation()}
              onChange={(e) => setRenameValue(e.target.value)}
              onBlur={commitRename}
              onKeyDown={(e) => {
                if (e.key === 'Enter')  { e.preventDefault(); commitRename() }
                if (e.key === 'Escape') { setRenaming(false) }
                e.stopPropagation()
              }}
              style={{
                width:        '100%',
                background:   'var(--color-highlight)',
                border:       '1px solid var(--color-button)',
                borderRadius: 4,
                padding:      '3px 6px',
                color:        'var(--color-text)',
                fontSize:     13,
                fontWeight:   600,
                outline:      'none',
              }}
            />
          ) : (
            <p
              style={{
                margin:       0,
                fontSize:     13,
                fontWeight:   600,
                color:        selected ? 'var(--color-button)' : 'var(--color-text)',
                overflow:     'hidden',
                textOverflow: 'ellipsis',
                whiteSpace:   'nowrap',
              }}
            >
              {playlist.pinned && (
                <Pin
                  size={10}
                  aria-label="Pinned"
                  style={{ marginRight: 4, verticalAlign: 'middle', color: 'var(--color-button)' }}
                />
              )}
              {playlist.name}
            </p>
          )}
          <p
            style={{
              margin:   0,
              fontSize: 11,
              color:    'var(--color-subtext)',
              marginTop: 1,
            }}
          >
            {playlist.songs?.length ?? 0} songs
          </p>
        </div>

        {/* '…' more button — only visible on hover */}
        {hovered && !renaming && (
          <button
            type="button"
            aria-label={`More options for ${playlist.name}`}
            onClick={handleDotClick}
            style={{
              flexShrink:   0,
              display:      'flex',
              alignItems:   'center',
              justifyContent:'center',
              width:        26,
              height:       26,
              borderRadius: '50%',
              border:       'none',
              background:   'var(--color-highlight-elevated)',
              color:        'var(--color-text)',
              cursor:       'pointer',
              transition:   'background 0.12s',
            }}
            onMouseEnter={(e) => { e.currentTarget.style.background = 'var(--color-shadow)' }}
            onMouseLeave={(e) => { e.currentTarget.style.background = 'var(--color-highlight-elevated)' }}
          >
            <MoreHorizontal size={14} />
          </button>
        )}
      </div>

      {showInvite && (
        <InviteDialog playlist={playlist} onClose={() => setShowInvite(false)} />
      )}
    </>
  )
}

// ── Sidebar ───────────────────────────────────────────────────────────────────

export default function Sidebar() {
  const navigate   = useNavigate()
  const location   = useLocation()
  const { user }   = useAuthStore()

  const { playlists, likedSongs, createPlaylist } = useLibraryStore()
  const { addToQueue }                            = usePlayerStore()

  // ── Collapse state ───────────────────────────────────────────────────────
  const [collapsed, setCollapsed] = useState(false)

  // ── New playlist inline input ────────────────────────────────────────────
  const [creatingPlaylist,    setCreatingPlaylist]    = useState(false)
  const [newPlaylistName,     setNewPlaylistName]     = useState('')
  const newPlaylistInputRef = useRef(null)

  useEffect(() => {
    if (creatingPlaylist) newPlaylistInputRef.current?.focus()
  }, [creatingPlaylist])

  const handleCreatePlaylist = async () => {
    const name = newPlaylistName.trim()
    setCreatingPlaylist(false)
    setNewPlaylistName('')
    if (name && user) {
      const id = await createPlaylist(user.uid, name)
      if (id) navigate(`/playlist/${id}`)
    }
  }

  // ── Context menu state ───────────────────────────────────────────────────
  const [contextMenu, setContextMenu] = useState(null)
  // { x, y, playlist, onRename, onInvite }

  const openContextMenu = useCallback((x, y, playlist, onRename, onInvite) => {
    setContextMenu({ x, y, playlist, onRename, onInvite })
  }, [])

  const closeContextMenu = useCallback(() => setContextMenu(null), [])

  // ── Active route helpers ─────────────────────────────────────────────────
  const isLikedActive = location.pathname === '/liked-songs'

  const activePlaylistId = location.pathname.startsWith('/playlist/')
    ? location.pathname.replace('/playlist/', '')
    : null

  // ── Sort: pinned first, then by name ────────────────────────────────────
  const sortedPlaylists = [...playlists].sort((a, b) => {
    if (a.pinned && !b.pinned) return -1
    if (!a.pinned && b.pinned) return  1
    return a.name.localeCompare(b.name)
  })

  // ── Styles ───────────────────────────────────────────────────────────────
  const width = collapsed ? COLLAPSED_WIDTH : EXPANDED_WIDTH

  const sidebarStyle = {
    width,
    minWidth:   width,
    maxWidth:   width,
    flexShrink: 0,
    display:    'flex',
    flexDirection: 'column',
    background: 'var(--color-sidebar)',
    overflowX:  'hidden',
    overflowY:  'auto',
    transition: 'width 0.22s cubic-bezier(0.4, 0, 0.2, 1), min-width 0.22s cubic-bezier(0.4, 0, 0.2, 1)',
    borderTopRightRadius: 12,
    borderBottomRightRadius: 12,
  }

  const iconBtnBase = {
    display:        'flex',
    alignItems:     'center',
    justifyContent: 'center',
    width:          28,
    height:         28,
    borderRadius:   '50%',
    border:         'none',
    background:     'transparent',
    color:          'var(--color-subtext)',
    cursor:         'pointer',
    flexShrink:     0,
    transition:     'background 0.12s, color 0.12s',
  }

  // ── Render ────────────────────────────────────────────────────────────────

  return (
    <nav
      aria-label="Library navigation"
      style={sidebarStyle}
    >
      {/* ── Header ─────────────────────────────────────────────────────── */}
      <div
        style={{
          display:        'flex',
          alignItems:     'center',
          justifyContent: collapsed ? 'center' : 'space-between',
          padding:        collapsed ? '12px 0' : '12px 12px 6px 16px',
          flexShrink:     0,
          minHeight:      44,
          gap:            6,
        }}
      >
        {!collapsed && (
          <span
            style={{
              fontSize:    13,
              fontWeight:  700,
              color:       'var(--color-subtext)',
              letterSpacing: 0.4,
              flexGrow:    1,
              userSelect:  'none',
            }}
          >
            Your Library
          </span>
        )}

        {/* '+' create playlist button (expanded only) */}
        {!collapsed && (
          <button
            type="button"
            aria-label="Create new playlist"
            title="Create new playlist"
            onClick={() => {
              setCreatingPlaylist(true)
              setNewPlaylistName('')
            }}
            style={iconBtnBase}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = 'var(--color-highlight)'
              e.currentTarget.style.color      = 'var(--color-text)'
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'transparent'
              e.currentTarget.style.color      = 'var(--color-subtext)'
            }}
          >
            <Plus size={16} />
          </button>
        )}

        {/* Collapse toggle */}
        <button
          type="button"
          aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
          title={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
          onClick={() => setCollapsed((v) => !v)}
          style={iconBtnBase}
          onMouseEnter={(e) => {
            e.currentTarget.style.background = 'var(--color-highlight)'
            e.currentTarget.style.color      = 'var(--color-text)'
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.background = 'transparent'
            e.currentTarget.style.color      = 'var(--color-subtext)'
          }}
        >
          {collapsed ? <ChevronRight size={16} /> : <ChevronLeft size={16} />}
        </button>
      </div>

      {/* ── New playlist inline input ────────────────────────────────────── */}
      {!collapsed && creatingPlaylist && (
        <div style={{ padding: '4px 12px 8px' }}>
          <input
            ref={newPlaylistInputRef}
            type="text"
            placeholder="Playlist name…"
            value={newPlaylistName}
            onChange={(e) => setNewPlaylistName(e.target.value)}
            onBlur={handleCreatePlaylist}
            onKeyDown={(e) => {
              if (e.key === 'Enter')  { e.preventDefault(); handleCreatePlaylist() }
              if (e.key === 'Escape') { setCreatingPlaylist(false); setNewPlaylistName('') }
            }}
            style={{
              width:        '100%',
              boxSizing:    'border-box',
              background:   'var(--color-highlight)',
              border:       '1px solid var(--color-button)',
              borderRadius: 6,
              padding:      '7px 10px',
              color:        'var(--color-text)',
              fontSize:     13,
              outline:      'none',
            }}
          />
        </div>
      )}

      {/* ── Liked Songs tile ─────────────────────────────────────────────── */}
      {collapsed ? (
        <Tooltip label={`Liked Songs · ${likedSongs.length}`}>
          <button
            type="button"
            aria-label={`Liked Songs, ${likedSongs.length} songs`}
            onClick={() => navigate('/liked-songs')}
            style={{
              width:          '100%',
              display:        'flex',
              alignItems:     'center',
              justifyContent: 'center',
              padding:        '10px 0',
              background:     isLikedActive ? 'var(--color-selected-row)' : 'transparent',
              border:         'none',
              cursor:         'pointer',
              color:          isLikedActive ? 'var(--color-button)' : 'var(--color-subtext)',
              borderRadius:   8,
              transition:     'background 0.15s, color 0.15s',
            }}
            onMouseEnter={(e) => {
              if (!isLikedActive) {
                e.currentTarget.style.background = 'var(--color-highlight)'
                e.currentTarget.style.color      = 'var(--color-text)'
              }
            }}
            onMouseLeave={(e) => {
              if (!isLikedActive) {
                e.currentTarget.style.background = 'transparent'
                e.currentTarget.style.color      = 'var(--color-subtext)'
              }
            }}
          >
            <Heart
              size={20}
              fill={isLikedActive ? 'var(--color-button)' : 'none'}
            />
          </button>
        </Tooltip>
      ) : (
        <button
          type="button"
          aria-label={`Liked Songs, ${likedSongs.length} songs`}
          aria-current={isLikedActive ? 'page' : undefined}
          onClick={() => navigate('/liked-songs')}
          style={{
            display:      'flex',
            alignItems:   'center',
            gap:          10,
            padding:      '6px 12px',
            margin:       '1px 4px',
            borderRadius: 6,
            background:   isLikedActive ? 'var(--color-selected-row)' : 'transparent',
            border:       'none',
            cursor:       'pointer',
            color:        'var(--color-text)',
            transition:   'background 0.12s',
            width:        'calc(100% - 8px)',
            boxSizing:    'border-box',
          }}
          onMouseEnter={(e) => {
            if (!isLikedActive) e.currentTarget.style.background = 'var(--color-highlight)'
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.background = isLikedActive
              ? 'var(--color-selected-row)'
              : 'transparent'
          }}
        >
          {/* Gradient icon tile */}
          <div
            aria-hidden="true"
            style={{
              width:        42,
              height:       42,
              borderRadius: 4,
              flexShrink:   0,
              background:   'linear-gradient(135deg, #450af5, #c4efd9)',
              display:      'flex',
              alignItems:   'center',
              justifyContent:'center',
            }}
          >
            <Heart size={18} fill="#fff" color="#fff" />
          </div>

          <div style={{ flexGrow: 1, minWidth: 0, textAlign: 'left' }}>
            <p
              style={{
                margin:       0,
                fontSize:     13,
                fontWeight:   600,
                color:        isLikedActive ? 'var(--color-button)' : 'var(--color-text)',
                overflow:     'hidden',
                textOverflow: 'ellipsis',
                whiteSpace:   'nowrap',
              }}
            >
              Liked Songs
            </p>
            <p style={{ margin: 0, fontSize: 11, color: 'var(--color-subtext)', marginTop: 1 }}>
              {likedSongs.length} songs
            </p>
          </div>
        </button>
      )}

      {/* ── Thin divider ─────────────────────────────────────────────────── */}
      {!collapsed && (
        <div
          style={{
            height:     1,
            background: 'var(--color-highlight)',
            margin:     '6px 12px 4px',
            flexShrink: 0,
          }}
        />
      )}

      {/* ── Playlist list ─────────────────────────────────────────────────── */}
      <div
        style={{
          flexGrow:  1,
          overflowY: 'auto',
          overflowX: 'hidden',
          padding:   collapsed ? '4px 0' : '4px 0 16px',
        }}
      >
        {sortedPlaylists.length === 0 && !collapsed && (
          <p
            style={{
              margin:    '16px',
              fontSize:  12,
              color:     'var(--color-subtext)',
              textAlign: 'center',
            }}
          >
            No playlists yet.{' '}
            <button
              type="button"
              onClick={() => { setCreatingPlaylist(true); setNewPlaylistName('') }}
              style={{
                background:    'none',
                border:        'none',
                color:         'var(--color-button)',
                cursor:        'pointer',
                padding:       0,
                fontSize:      12,
                textDecoration:'underline',
              }}
            >
              Create one
            </button>
          </p>
        )}

        {sortedPlaylists.map((playlist) => (
          <PlaylistRow
            key={playlist.id}
            playlist={playlist}
            collapsed={collapsed}
            selected={activePlaylistId === playlist.id}
            onContextMenu={openContextMenu}
          />
        ))}
      </div>

      {/* ── Context menu (portal-style, fixed position) ───────────────────── */}
      {contextMenu && (
        <ContextMenu
          x={contextMenu.x}
          y={contextMenu.y}
          playlist={contextMenu.playlist}
          onClose={closeContextMenu}
          onRename={contextMenu.onRename}
          onInvite={contextMenu.onInvite}
        />
      )}
    </nav>
  )
}
