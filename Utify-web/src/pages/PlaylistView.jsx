/**
 * PlaylistView.jsx
 * Mirrors desktop_playlist_view.dart
 *
 * Features:
 *   • Gradient banner header (first-song thumbnail as bg blur)
 *   • Playlist name, description, owner, song count, total duration
 *   • Play All / Shuffle buttons
 *   • Track list: #, thumbnail, title, channel, duration, Like, Remove (owner)
 *   • Right-click context menu per track (Play, Queue, Add to Playlist, Like)
 *   • Inline edit of name/description (pencil icon, owner only)
 *   • Delete playlist (owner only, confirmation dialog)
 *   • Invite collaborator dialog (enter uid/username)
 *   • Collaborator badge when playlist has sharedId
 *   • Gets playlist from useLibraryStore by id (useParams)
 */

import {
  useCallback,
  useEffect,
  useRef,
  useState,
} from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useAuthStore }   from '../stores/authStore'
import { usePlayerStore } from '../stores/playerStore'
import { useLibraryStore } from '../stores/libraryStore'
import { addSongToPlaylist } from '../services/firestoreService'

// ── Helpers ───────────────────────────────────────────────────────────────────

function fmtDuration(secs) {
  if (!secs) return ''
  const m = Math.floor(secs / 60)
  const s = String(secs % 60).padStart(2, '0')
  return `${m}:${s}`
}

function totalDuration(songs) {
  const total = songs.reduce((acc, s) => acc + (s.durationSeconds || 0), 0)
  if (total === 0) return ''
  const h = Math.floor(total / 3600)
  const m = Math.floor((total % 3600) / 60)
  const s = total % 60
  if (h > 0) return `${h} hr ${m} min`
  if (m > 0) return `${m} min ${s} sec`
  return `${s} sec`
}

// ── ContextMenu (track-level) ─────────────────────────────────────────────────

function TrackContextMenu({ x, y, song, onClose, playlists, uid }) {
  const playSong      = usePlayerStore((s) => s.playSong)
  const addToQueue    = usePlayerStore((s) => s.addToQueue)
  const toggleLike    = useLibraryStore((s) => s.toggleLike)
  const isLiked       = useLibraryStore((s) => s.isLiked)
  const addToPlaylist = useLibraryStore((s) => s.addSongToPlaylist)

  const [submenuOpen, setSubmenuOpen] = useState(false)
  const menuRef = useRef(null)

  useEffect(() => {
    const handler = (e) => {
      if (menuRef.current && !menuRef.current.contains(e.target)) onClose()
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [onClose])

  const liked = isLiked(song.id)

  const act = (fn) => (e) => {
    e.stopPropagation()
    fn()
    onClose()
  }

  return (
    <div ref={menuRef} role="menu" style={{ ...styles.ctxMenu, top: y, left: x }}>
      <button role="menuitem" style={styles.ctxItem} onClick={act(() => playSong(song))}>
        <PlayIcon size={14} />
        Play
      </button>
      <button role="menuitem" style={styles.ctxItem} onClick={act(() => addToQueue(song))}>
        <QueueIcon size={14} />
        Add to Queue
      </button>

      {/* Add to Playlist sub-trigger */}
      <div
        role="menuitem"
        style={{ ...styles.ctxItem, justifyContent: 'space-between', position: 'relative' }}
        onMouseEnter={() => setSubmenuOpen(true)}
        onMouseLeave={() => setSubmenuOpen(false)}
      >
        <span style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <PlusIcon size={14} />
          Add to Playlist
        </span>
        <ChevronRightIcon size={12} />

        {submenuOpen && (
          <div style={styles.subMenu}>
            {playlists.length === 0
              ? <span style={{ ...styles.ctxItem, color: 'var(--color-subtext)', cursor: 'default' }}>No playlists</span>
              : playlists.map((pl) => (
                  <button
                    key={pl.id}
                    role="menuitem"
                    style={styles.ctxItem}
                    onClick={act(() => uid && addToPlaylist(uid, pl.id, song))}
                  >
                    {pl.name}
                  </button>
                ))
            }
          </div>
        )}
      </div>

      <div style={styles.ctxDivider} />

      <button role="menuitem" style={styles.ctxItem} onClick={act(() => uid && toggleLike(uid, song))}>
        <HeartIcon size={14} filled={liked} />
        {liked ? 'Unlike' : 'Like'}
      </button>
    </div>
  )
}

// ── Small SVG icon helpers ────────────────────────────────────────────────────

const PlayIcon = ({ size = 16 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
    <path d="M8 5v14l11-7z" />
  </svg>
)

const ShuffleIcon = ({ size = 16 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
    <polyline points="16 3 21 3 21 8" /><line x1="4" y1="20" x2="21" y2="3" />
    <polyline points="21 16 21 21 16 21" /><line x1="15" y1="15" x2="21" y2="21" />
  </svg>
)

const PencilIcon = ({ size = 16 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
    <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
    <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
  </svg>
)

const TrashIcon = ({ size = 16 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
    <polyline points="3 6 5 6 21 6" />
    <path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6" />
    <path d="M10 11v6M14 11v6" />
    <path d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2" />
  </svg>
)

const UserPlusIcon = ({ size = 16 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
    <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
    <circle cx="8.5" cy="7" r="4" />
    <line x1="20" y1="8" x2="20" y2="14" /><line x1="23" y1="11" x2="17" y2="11" />
  </svg>
)

const HeartIcon = ({ size = 16, filled = false }) => (
  <svg width={size} height={size} viewBox="0 0 24 24"
    fill={filled ? 'var(--color-button)' : 'none'}
    stroke={filled ? 'var(--color-button)' : 'currentColor'}
    strokeWidth="2"
    aria-hidden="true"
  >
    <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z" />
  </svg>
)

const QueueIcon = ({ size = 14 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
    <line x1="8" y1="6" x2="21" y2="6" /><line x1="8" y1="12" x2="21" y2="12" /><line x1="8" y1="18" x2="21" y2="18" />
    <line x1="3" y1="6" x2="3.01" y2="6" /><line x1="3" y1="12" x2="3.01" y2="12" /><line x1="3" y1="18" x2="3.01" y2="18" />
  </svg>
)

const PlusIcon = ({ size = 14 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
    <line x1="12" y1="5" x2="12" y2="19" /><line x1="5" y1="12" x2="19" y2="12" />
  </svg>
)

const ChevronRightIcon = ({ size = 12 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
    <polyline points="9 18 15 12 9 6" />
  </svg>
)

// ── ConfirmDialog ─────────────────────────────────────────────────────────────

function ConfirmDialog({ title, message, confirmLabel, danger, onConfirm, onCancel }) {
  return (
    <div style={styles.backdrop} role="dialog" aria-modal="true" aria-labelledby="dialog-title">
      <div style={styles.dialog}>
        <h3 id="dialog-title" style={styles.dialogTitle}>{title}</h3>
        <p style={styles.dialogMsg}>{message}</p>
        <div style={styles.dialogActions}>
          <button style={styles.btnOutline} onClick={onCancel}>Cancel</button>
          <button
            style={{ ...styles.btnSolid, background: danger ? 'var(--color-error)' : 'var(--color-button)' }}
            onClick={onConfirm}
            autoFocus
          >
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  )
}

// ── InviteDialog ──────────────────────────────────────────────────────────────

function InviteDialog({ playlistId, uid, onClose }) {
  const updatePlaylist = useLibraryStore((s) => s.updatePlaylist)
  const [value,   setValue]   = useState('')
  const [saving,  setSaving]  = useState(false)
  const [errMsg,  setErrMsg]  = useState('')

  const handleInvite = async () => {
    if (!value.trim()) return
    setSaving(true)
    setErrMsg('')
    try {
      // Store the sharedId on the playlist doc so collaborators can find it
      await updatePlaylist(uid, playlistId, { sharedId: value.trim() })
      onClose()
    } catch (err) {
      setErrMsg(err.message || 'Failed to invite collaborator.')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div style={styles.backdrop} role="dialog" aria-modal="true" aria-labelledby="invite-title">
      <div style={styles.dialog}>
        <h3 id="invite-title" style={styles.dialogTitle}>Invite Collaborator</h3>
        <p style={{ color: 'var(--color-subtext)', fontSize: 13, marginBottom: 16 }}>
          Enter the UID or username of the person you want to collaborate with.
        </p>
        <input
          type="text"
          value={value}
          placeholder="uid or @username"
          style={styles.dialogInput}
          onChange={(e) => setValue(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && handleInvite()}
          autoFocus
        />
        {errMsg && <p style={{ color: 'var(--color-error)', fontSize: 13, marginTop: 8 }}>{errMsg}</p>}
        <div style={styles.dialogActions}>
          <button style={styles.btnOutline} onClick={onClose} disabled={saving}>Cancel</button>
          <button
            style={{ ...styles.btnSolid, opacity: saving ? 0.6 : 1 }}
            onClick={handleInvite}
            disabled={saving || !value.trim()}
          >
            {saving ? 'Inviting…' : 'Invite'}
          </button>
        </div>
      </div>
    </div>
  )
}

// ── PlaylistView ──────────────────────────────────────────────────────────────

export default function PlaylistView() {
  const { id }     = useParams()
  const navigate   = useNavigate()
  const user       = useAuthStore((s) => s.user)

  const playlists         = useLibraryStore((s) => s.playlists)
  const updatePlaylist    = useLibraryStore((s) => s.updatePlaylist)
  const deletePlaylist    = useLibraryStore((s) => s.deletePlaylist)
  const removeSong        = useLibraryStore((s) => s.removeSongFromPlaylist)
  const toggleLike        = useLibraryStore((s) => s.toggleLike)
  const isLiked           = useLibraryStore((s) => s.isLiked)

  const playSong  = usePlayerStore((s) => s.playSong)
  const playQueue = usePlayerStore((s) => s.playQueue)

  // Find this playlist
  const playlist = playlists.find((p) => p.id === id) ?? null
  const songs    = playlist?.songs ?? []
  const isOwner  = playlist?.ownerUid === user?.uid

  // ── Editing state ─────────────────────────────────────────────────────────
  const [editName,        setEditName]        = useState('')
  const [editDesc,        setEditDesc]        = useState('')
  const [editingName,     setEditingName]     = useState(false)
  const [editingDesc,     setEditingDesc]     = useState(false)

  // ── Dialog state ──────────────────────────────────────────────────────────
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  const [showInviteDialog,  setShowInviteDialog]  = useState(false)

  // ── Context menu ──────────────────────────────────────────────────────────
  const [ctxMenu, setCtxMenu] = useState(null) // { x, y, song }

  // ── Hover state for rows ──────────────────────────────────────────────────
  const [hoveredRow, setHoveredRow] = useState(null)

  const nameInputRef = useRef(null)
  const descInputRef = useRef(null)

  // Init edit buffers from playlist
  useEffect(() => {
    if (playlist) {
      setEditName(playlist.name ?? '')
      setEditDesc(playlist.description ?? '')
    }
  }, [playlist])

  // Focus input when entering edit mode
  useEffect(() => { if (editingName) nameInputRef.current?.focus() }, [editingName])
  useEffect(() => { if (editingDesc) descInputRef.current?.focus() }, [editingDesc])

  // ── Play / Shuffle ────────────────────────────────────────────────────────

  const handlePlayAll = () => {
    if (!songs.length) return
    playQueue(songs, 0)
  }

  const handleShuffle = () => {
    if (!songs.length) return
    const shuffled = [...songs].sort(() => Math.random() - 0.5)
    playQueue(shuffled, 0)
  }

  // ── Save inline edits ─────────────────────────────────────────────────────

  const saveName = async () => {
    setEditingName(false)
    const trimmed = editName.trim()
    if (!trimmed || trimmed === playlist?.name) return
    await updatePlaylist(user.uid, id, { name: trimmed })
  }

  const saveDesc = async () => {
    setEditingDesc(false)
    const trimmed = editDesc.trim()
    if (trimmed === (playlist?.description ?? '')) return
    await updatePlaylist(user.uid, id, { description: trimmed })
  }

  // ── Delete playlist ───────────────────────────────────────────────────────

  const handleDelete = async () => {
    setShowDeleteConfirm(false)
    await deletePlaylist(user.uid, id)
    navigate(-1)
  }

  // ── Remove track ──────────────────────────────────────────────────────────

  const handleRemoveSong = async (songId) => {
    await removeSong(user.uid, id, songId)
  }

  // ── Context menu ──────────────────────────────────────────────────────────

  const openCtx = (e, song) => {
    e.preventDefault()
    const x = Math.min(e.clientX, window.innerWidth  - 220)
    const y = Math.min(e.clientY, window.innerHeight - 240)
    setCtxMenu({ x, y, song })
  }

  const closeCtx = useCallback(() => setCtxMenu(null), [])

  useEffect(() => {
    const h = (e) => { if (e.key === 'Escape') closeCtx() }
    document.addEventListener('keydown', h)
    return () => document.removeEventListener('keydown', h)
  }, [closeCtx])

  // ── Not found ─────────────────────────────────────────────────────────────

  if (!playlist) {
    return (
      <div style={{ ...styles.page, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', minHeight: 400 }}>
        <p style={{ color: 'var(--color-subtext)', fontSize: 16 }}>Playlist not found.</p>
        <button style={{ ...styles.btnOutline, marginTop: 16 }} onClick={() => navigate(-1)}>Go Back</button>
      </div>
    )
  }

  // ── Header bg: blur + darken of first song thumbnail ─────────────────────
  const heroBg = songs[0]?.thumbnailUrl ?? null

  // ── Computed ──────────────────────────────────────────────────────────────
  const duration = totalDuration(songs)

  return (
    <div style={styles.page}>

      {/* ── Banner header ── */}
      <div style={styles.banner}>
        {/* Blurred background image */}
        {heroBg && (
          <div
            aria-hidden="true"
            style={{
              ...styles.bannerBg,
              backgroundImage: `url(${heroBg})`,
            }}
          />
        )}
        {/* Dark gradient overlay */}
        <div style={styles.bannerOverlay} aria-hidden="true" />

        {/* Banner content */}
        <div style={styles.bannerContent}>
          {/* Thumbnail */}
          {heroBg
            ? (
              <img
                src={heroBg}
                alt=""
                width={160}
                height={160}
                style={styles.bannerThumb}
              />
            )
            : (
              <div style={{ ...styles.bannerThumb, background: 'var(--color-card)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="var(--color-subtext)" strokeWidth="1.5" aria-hidden="true">
                  <path d="M9 18V5l12-2v13" /><circle cx="6" cy="18" r="3" /><circle cx="18" cy="16" r="3" />
                </svg>
              </div>
            )
          }

          {/* Meta */}
          <div style={styles.bannerMeta}>
            {/* Type label */}
            <span style={styles.bannerType}>Playlist</span>

            {/* Name (editable for owner) */}
            {isOwner && editingName ? (
              <input
                ref={nameInputRef}
                type="text"
                value={editName}
                style={styles.nameInput}
                onChange={(e) => setEditName(e.target.value)}
                onBlur={saveName}
                onKeyDown={(e) => { if (e.key === 'Enter') saveName(); if (e.key === 'Escape') setEditingName(false) }}
                aria-label="Edit playlist name"
              />
            ) : (
              <h1
                style={styles.bannerName}
                onClick={() => isOwner && setEditingName(true)}
                title={isOwner ? 'Click to edit name' : undefined}
              >
                {playlist.name}
                {isOwner && (
                  <button
                    style={styles.pencilBtn}
                    onClick={(e) => { e.stopPropagation(); setEditingName(true) }}
                    aria-label="Edit playlist name"
                  >
                    <PencilIcon size={14} />
                  </button>
                )}
              </h1>
            )}

            {/* Description (editable for owner) */}
            {isOwner && editingDesc ? (
              <textarea
                ref={descInputRef}
                value={editDesc}
                rows={2}
                style={styles.descInput}
                onChange={(e) => setEditDesc(e.target.value)}
                onBlur={saveDesc}
                onKeyDown={(e) => { if (e.key === 'Escape') setEditingDesc(false) }}
                aria-label="Edit playlist description"
              />
            ) : (
              <p
                style={styles.bannerDesc}
                onClick={() => isOwner && setEditingDesc(true)}
                title={isOwner ? 'Click to edit description' : undefined}
              >
                {playlist.description || (isOwner ? <em style={{ opacity: 0.5 }}>Add a description…</em> : null)}
                {isOwner && (
                  <button
                    style={{ ...styles.pencilBtn, marginLeft: 6 }}
                    onClick={(e) => { e.stopPropagation(); setEditingDesc(true) }}
                    aria-label="Edit playlist description"
                  >
                    <PencilIcon size={12} />
                  </button>
                )}
              </p>
            )}

            {/* Stats */}
            <p style={styles.bannerStats}>
              {songs.length} {songs.length === 1 ? 'song' : 'songs'}
              {duration && ` · ${duration}`}
              {playlist.sharedId && (
                <span style={styles.collabBadge} title="Collaborative playlist">
                  Collaborative
                </span>
              )}
            </p>
          </div>
        </div>
      </div>

      {/* ── Action bar ── */}
      <div style={styles.actionBar}>
        {/* Play All */}
        <button
          style={styles.btnPlayAll}
          onClick={handlePlayAll}
          disabled={songs.length === 0}
          aria-label="Play all songs"
        >
          <PlayIcon size={18} />
          Play All
        </button>

        {/* Shuffle */}
        <button
          style={styles.btnShuffle}
          onClick={handleShuffle}
          disabled={songs.length === 0}
          aria-label="Shuffle play"
        >
          <ShuffleIcon size={16} />
          Shuffle
        </button>

        {/* Spacer */}
        <div style={{ flex: 1 }} />

        {/* Invite collaborator */}
        {isOwner && (
          <button
            style={styles.btnIconAction}
            onClick={() => setShowInviteDialog(true)}
            aria-label="Invite collaborator"
            title="Invite collaborator"
          >
            <UserPlusIcon size={18} />
          </button>
        )}

        {/* Delete playlist (owner only) */}
        {isOwner && (
          <button
            style={{ ...styles.btnIconAction, color: 'var(--color-error)' }}
            onClick={() => setShowDeleteConfirm(true)}
            aria-label="Delete playlist"
            title="Delete playlist"
          >
            <TrashIcon size={18} />
          </button>
        )}
      </div>

      {/* ── Track list ── */}
      {songs.length === 0 ? (
        <div style={styles.emptyTracks}>
          <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="var(--color-subtext)" strokeWidth="1.2" aria-hidden="true">
            <path d="M9 18V5l12-2v13" /><circle cx="6" cy="18" r="3" /><circle cx="18" cy="16" r="3" />
          </svg>
          <p style={{ color: 'var(--color-subtext)', marginTop: 12, fontSize: 15 }}>
            This playlist is empty. Search for songs to add.
          </p>
        </div>
      ) : (
        <div role="table" aria-label="Playlist tracks" style={styles.trackTable}>
          {/* Header row */}
          <div role="row" style={styles.trackHeaderRow} aria-hidden="true">
            <span style={{ ...styles.trackCell, width: 32, textAlign: 'center', flexShrink: 0 }}>#</span>
            <span style={{ ...styles.trackCell, width: 40, flexShrink: 0 }} />
            <span style={{ ...styles.trackCell, flex: 1 }}>Title</span>
            <span style={{ ...styles.trackCell, width: 160, display: 'var(--hide-on-narrow, flex)' }}>Channel</span>
            <span style={{ ...styles.trackCell, width: 60, textAlign: 'right', flexShrink: 0 }}>Time</span>
            <span style={{ ...styles.trackCell, width: 72, flexShrink: 0 }} />
          </div>

          {/* Song rows */}
          {songs.map((song, i) => {
            const hovered = hoveredRow === i
            const liked   = isLiked(song.id)
            return (
              <div
                key={`${song.id}-${i}`}
                role="row"
                style={{
                  ...styles.trackRow,
                  background: hovered ? 'var(--color-highlight)' : 'transparent',
                }}
                onMouseEnter={() => setHoveredRow(i)}
                onMouseLeave={() => setHoveredRow(null)}
                onDoubleClick={() => playSong(song, songs, i)}
                onContextMenu={(e) => openCtx(e, song)}
              >
                {/* # / play */}
                <div role="cell" style={{ width: 32, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                  {hovered
                    ? (
                      <button
                        style={styles.rowPlayBtn}
                        aria-label={`Play ${song.title}`}
                        onClick={() => playSong(song, songs, i)}
                      >
                        <PlayIcon size={13} />
                      </button>
                    )
                    : <span style={{ color: 'var(--color-subtext)', fontSize: 13 }}>{i + 1}</span>
                  }
                </div>

                {/* Thumbnail */}
                <img
                  role="cell"
                  src={song.thumbnailUrl}
                  alt=""
                  width={40}
                  height={40}
                  loading="lazy"
                  style={styles.rowThumb}
                  onError={(e) => { e.currentTarget.src = 'https://i.ytimg.com/vi/default/mqdefault.jpg' }}
                />

                {/* Title */}
                <div role="cell" style={{ flex: 1, minWidth: 0 }}>
                  <p style={styles.trackTitle} title={song.title}>{song.title}</p>
                </div>

                {/* Channel */}
                <div role="cell" style={{ width: 160, overflow: 'hidden' }}>
                  <p style={styles.trackChannel} title={song.channelName}>{song.channelName}</p>
                </div>

                {/* Duration */}
                <span role="cell" style={{ width: 60, textAlign: 'right', fontSize: 13, color: 'var(--color-subtext)', flexShrink: 0 }}>
                  {fmtDuration(song.durationSeconds)}
                </span>

                {/* Actions: Like + Remove */}
                <div role="cell" style={{ width: 72, display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 6, flexShrink: 0 }}>
                  <button
                    style={{ ...styles.rowIconBtn, opacity: (hovered || liked) ? 1 : 0 }}
                    aria-label={liked ? 'Unlike song' : 'Like song'}
                    onClick={() => user?.uid && toggleLike(user.uid, song)}
                    tabIndex={hovered ? 0 : -1}
                  >
                    <HeartIcon size={15} filled={liked} />
                  </button>
                  {isOwner && (
                    <button
                      style={{ ...styles.rowIconBtn, opacity: hovered ? 1 : 0, color: 'var(--color-subtext)' }}
                      aria-label={`Remove ${song.title} from playlist`}
                      onClick={() => handleRemoveSong(song.id)}
                      tabIndex={hovered ? 0 : -1}
                    >
                      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
                        <line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" />
                      </svg>
                    </button>
                  )}
                </div>
              </div>
            )
          })}
        </div>
      )}

      {/* ── Context menu ── */}
      {ctxMenu && (
        <TrackContextMenu
          x={ctxMenu.x}
          y={ctxMenu.y}
          song={ctxMenu.song}
          onClose={closeCtx}
          playlists={playlists}
          uid={user?.uid}
        />
      )}

      {/* ── Delete confirmation ── */}
      {showDeleteConfirm && (
        <ConfirmDialog
          title="Delete playlist"
          message={`"${playlist.name}" will be permanently deleted. This cannot be undone.`}
          confirmLabel="Delete"
          danger
          onConfirm={handleDelete}
          onCancel={() => setShowDeleteConfirm(false)}
        />
      )}

      {/* ── Invite collaborator dialog ── */}
      {showInviteDialog && (
        <InviteDialog
          playlistId={id}
          uid={user?.uid}
          onClose={() => setShowInviteDialog(false)}
        />
      )}
    </div>
  )
}

// ── Styles ────────────────────────────────────────────────────────────────────

const styles = {
  page: {
    paddingBottom: 120,
    minHeight: '100%',
    position: 'relative',
  },

  // ── Banner ──
  banner: {
    position: 'relative',
    minHeight: 260,
    overflow: 'hidden',
    display: 'flex',
    alignItems: 'flex-end',
  },

  bannerBg: {
    position: 'absolute',
    inset: 0,
    backgroundSize: 'cover',
    backgroundPosition: 'center',
    filter: 'blur(40px) brightness(0.45)',
    transform: 'scale(1.1)',
  },

  bannerOverlay: {
    position: 'absolute',
    inset: 0,
    background: 'linear-gradient(to bottom, transparent 0%, rgba(0,0,0,0.55) 60%, var(--color-main) 100%)',
  },

  bannerContent: {
    position: 'relative',
    display: 'flex',
    alignItems: 'flex-end',
    gap: 24,
    padding: '0 24px 28px',
    zIndex: 1,
  },

  bannerThumb: {
    width: 160,
    height: 160,
    borderRadius: 8,
    objectFit: 'cover',
    flexShrink: 0,
    boxShadow: '0 8px 32px rgba(0,0,0,0.6)',
  },

  bannerMeta: {
    flex: 1,
    minWidth: 0,
  },

  bannerType: {
    fontSize: 12,
    fontWeight: 700,
    color: 'var(--color-text)',
    opacity: 0.8,
    textTransform: 'uppercase',
    letterSpacing: '0.08em',
    display: 'block',
    marginBottom: 6,
  },

  bannerName: {
    fontSize: 40,
    fontWeight: 900,
    color: 'var(--color-text)',
    lineHeight: 1.1,
    marginBottom: 8,
    display: 'flex',
    alignItems: 'center',
    gap: 12,
    cursor: 'pointer',
    wordBreak: 'break-word',
  },

  bannerDesc: {
    fontSize: 14,
    color: 'var(--color-subtext)',
    marginBottom: 10,
    cursor: 'pointer',
    display: 'flex',
    alignItems: 'center',
  },

  bannerStats: {
    fontSize: 13,
    color: 'var(--color-subtext)',
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    flexWrap: 'wrap',
  },

  collabBadge: {
    background: 'var(--color-misc)',
    color: 'var(--color-text)',
    borderRadius: 12,
    padding: '2px 10px',
    fontSize: 11,
    fontWeight: 700,
    letterSpacing: '0.04em',
  },

  // Inline edit inputs in banner
  nameInput: {
    fontSize: 36,
    fontWeight: 900,
    color: 'var(--color-text)',
    background: 'transparent',
    border: 'none',
    borderBottom: '2px solid var(--color-button)',
    outline: 'none',
    width: '100%',
    marginBottom: 8,
    padding: '4px 0',
  },

  descInput: {
    fontSize: 14,
    color: 'var(--color-subtext)',
    background: 'transparent',
    border: '1px solid var(--color-highlight-elevated)',
    borderRadius: 4,
    outline: 'none',
    width: '100%',
    padding: 8,
    resize: 'vertical',
    marginBottom: 10,
  },

  pencilBtn: {
    background: 'none',
    border: 'none',
    color: 'var(--color-subtext)',
    cursor: 'pointer',
    display: 'inline-flex',
    alignItems: 'center',
    padding: 4,
    borderRadius: 4,
    opacity: 0.6,
    transition: 'opacity 0.15s',
    flexShrink: 0,
  },

  // ── Action bar ──
  actionBar: {
    display: 'flex',
    alignItems: 'center',
    gap: 12,
    padding: '20px 24px 16px',
  },

  btnPlayAll: {
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    padding: '12px 28px',
    borderRadius: 28,
    border: 'none',
    background: 'var(--color-button)',
    color: '#fff',
    fontSize: 14,
    fontWeight: 700,
    cursor: 'pointer',
    transition: 'background 0.15s',
  },

  btnShuffle: {
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    padding: '10px 22px',
    borderRadius: 28,
    border: '1px solid var(--color-highlight-elevated)',
    background: 'transparent',
    color: 'var(--color-text)',
    fontSize: 14,
    fontWeight: 600,
    cursor: 'pointer',
    transition: 'background 0.15s',
  },

  btnIconAction: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    width: 40,
    height: 40,
    borderRadius: '50%',
    border: '1px solid var(--color-highlight-elevated)',
    background: 'transparent',
    color: 'var(--color-subtext)',
    cursor: 'pointer',
    transition: 'background 0.15s, color 0.15s',
  },

  // ── Track table ──
  emptyTracks: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    padding: '60px 24px',
  },

  trackTable: {
    padding: '0 16px',
  },

  trackHeaderRow: {
    display: 'flex',
    alignItems: 'center',
    gap: 12,
    padding: '0 12px 8px',
    borderBottom: '1px solid var(--color-highlight)',
    marginBottom: 4,
  },

  trackCell: {
    fontSize: 12,
    fontWeight: 600,
    color: 'var(--color-subtext)',
    letterSpacing: '0.04em',
    textTransform: 'uppercase',
    overflow: 'hidden',
    whiteSpace: 'nowrap',
    display: 'flex',
    alignItems: 'center',
  },

  trackRow: {
    display: 'flex',
    alignItems: 'center',
    gap: 12,
    padding: '6px 12px',
    borderRadius: 6,
    cursor: 'default',
    userSelect: 'none',
    transition: 'background 0.1s',
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

  trackTitle: {
    fontSize: 14,
    fontWeight: 500,
    color: 'var(--color-text)',
    overflow: 'hidden',
    whiteSpace: 'nowrap',
    textOverflow: 'ellipsis',
    margin: 0,
  },

  trackChannel: {
    fontSize: 13,
    color: 'var(--color-subtext)',
    overflow: 'hidden',
    whiteSpace: 'nowrap',
    textOverflow: 'ellipsis',
    margin: 0,
  },

  rowIconBtn: {
    background: 'none',
    border: 'none',
    color: 'var(--color-button)',
    cursor: 'pointer',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 4,
    borderRadius: 4,
    transition: 'opacity 0.15s',
  },

  // ── Context menu ──
  ctxMenu: {
    position: 'fixed',
    background: 'var(--color-card)',
    border: '1px solid var(--color-highlight-elevated)',
    borderRadius: 8,
    boxShadow: '0 8px 24px rgba(0,0,0,0.5)',
    minWidth: 210,
    zIndex: 200,
    padding: '4px 0',
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

  // ── Dialogs ──
  backdrop: {
    position: 'fixed',
    inset: 0,
    background: 'rgba(0,0,0,0.65)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 300,
  },

  dialog: {
    background: 'var(--color-card)',
    border: '1px solid var(--color-highlight-elevated)',
    borderRadius: 12,
    padding: '28px 32px',
    width: '100%',
    maxWidth: 420,
    boxShadow: '0 16px 48px rgba(0,0,0,0.5)',
  },

  dialogTitle: {
    fontSize: 20,
    fontWeight: 700,
    color: 'var(--color-text)',
    marginBottom: 12,
  },

  dialogMsg: {
    fontSize: 14,
    color: 'var(--color-subtext)',
    marginBottom: 24,
    lineHeight: 1.5,
  },

  dialogInput: {
    width: '100%',
    padding: '10px 14px',
    borderRadius: 8,
    border: '1px solid var(--color-highlight-elevated)',
    background: 'var(--color-highlight)',
    color: 'var(--color-text)',
    fontSize: 14,
    outline: 'none',
    boxSizing: 'border-box',
  },

  dialogActions: {
    display: 'flex',
    justifyContent: 'flex-end',
    gap: 12,
    marginTop: 24,
  },

  btnOutline: {
    padding: '9px 22px',
    borderRadius: 24,
    border: '1px solid var(--color-highlight-elevated)',
    background: 'transparent',
    color: 'var(--color-text)',
    fontSize: 14,
    fontWeight: 600,
    cursor: 'pointer',
  },

  btnSolid: {
    padding: '9px 22px',
    borderRadius: 24,
    border: 'none',
    background: 'var(--color-button)',
    color: '#fff',
    fontSize: 14,
    fontWeight: 700,
    cursor: 'pointer',
  },
}
