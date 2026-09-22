/**
 * QueuePanel.jsx
 *
 * 320px right-side panel that mirrors queue_panel.dart.
 * Displays the playback queue with drag-to-reorder, jump-to-track, and remove.
 *
 * Drag-and-drop is implemented with the HTML5 native drag API so no extra
 * dependencies are needed.  The reorderQueue action in playerStore handles the
 * index arithmetic.
 */

import { useCallback, useRef, useState } from 'react'
import { usePlayerStore, PanelMode } from '../../stores/playerStore'

// ── QueueItem ─────────────────────────────────────────────────────────────────

function QueueItem({
  song,
  index,
  isCurrent,
  onPlay,
  onRemove,
  onDragStart,
  onDragEnter,
  onDragEnd,
  isDragOver,
}) {
  const [hovered, setHovered] = useState(false)

  return (
    <div
      draggable
      onDragStart={() => onDragStart(index)}
      onDragEnter={() => onDragEnter(index)}
      onDragEnd={onDragEnd}
      onDragOver={(e) => e.preventDefault()} // allow drop
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      aria-current={isCurrent ? 'true' : undefined}
      style={{
        display:     'flex',
        alignItems:  'center',
        gap:          10,
        padding:     '6px 8px',
        borderRadius: 6,
        cursor:      'grab',
        background:  isDragOver
          ? 'var(--color-highlight-elevated)'
          : hovered
            ? 'var(--color-highlight)'
            : 'transparent',
        borderLeft:  isCurrent ? '3px solid var(--color-button)' : '3px solid transparent',
        transition:  'background 0.15s',
        userSelect:  'none',
      }}
    >
      {/* Index / playing indicator */}
      <span
        style={{
          width:          22,
          textAlign:      'center',
          fontSize:        12,
          color:           isCurrent ? 'var(--color-button)' : 'var(--color-subtext)',
          fontWeight:      isCurrent ? 700 : 400,
          flexShrink:      0,
          fontVariantNumeric: 'tabular-nums',
        }}
      >
        {isCurrent ? '▶' : index + 1}
      </span>

      {/* Thumbnail */}
      <div
        style={{
          width:        40,
          height:       40,
          borderRadius: 4,
          overflow:     'hidden',
          flexShrink:   0,
          background:   'var(--color-highlight)',
          cursor:       'pointer',
        }}
        onClick={() => onPlay(index)}
      >
        {song.thumbnailUrl ? (
          <img
            src={song.thumbnailUrl}
            alt=""
            aria-hidden="true"
            style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
          />
        ) : null}
      </div>

      {/* Title + channel */}
      <div
        style={{
          flex:     1,
          minWidth: 0,
          cursor:   'pointer',
        }}
        onClick={() => onPlay(index)}
      >
        <p
          style={{
            margin:       0,
            fontSize:     13,
            fontWeight:   isCurrent ? 600 : 400,
            color:        isCurrent ? 'var(--color-button)' : 'var(--color-text)',
            whiteSpace:   'nowrap',
            overflow:     'hidden',
            textOverflow: 'ellipsis',
            lineHeight:   1.3,
          }}
        >
          {song.title}
        </p>
        <p
          style={{
            margin:       '1px 0 0',
            fontSize:     11,
            color:        'var(--color-subtext)',
            whiteSpace:   'nowrap',
            overflow:     'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          {song.channelName}
        </p>
      </div>

      {/* Remove button — visible on hover */}
      <button
        type="button"
        onClick={(e) => { e.stopPropagation(); onRemove(index) }}
        aria-label={`Remove ${song.title} from queue`}
        style={{
          background:   'none',
          border:       'none',
          cursor:       'pointer',
          padding:      4,
          borderRadius: '50%',
          color:        'var(--color-subtext)',
          display:      'flex',
          alignItems:   'center',
          justifyContent: 'center',
          flexShrink:   0,
          opacity:      hovered ? 1 : 0,
          transition:   'opacity 0.15s, color 0.15s',
          pointerEvents: hovered ? 'auto' : 'none',
        }}
        onMouseEnter={(e) => { e.currentTarget.style.color = 'var(--color-text)' }}
        onMouseLeave={(e) => { e.currentTarget.style.color = 'var(--color-subtext)' }}
      >
        <svg
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2.5"
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden="true"
        >
          <line x1="18" y1="6" x2="6" y2="18" />
          <line x1="6"  y1="6" x2="18" y2="18" />
        </svg>
      </button>
    </div>
  )
}

// ── QueuePanel ────────────────────────────────────────────────────────────────

export default function QueuePanel() {
  const queue          = usePlayerStore((s) => s.queue)
  const queueIndex     = usePlayerStore((s) => s.queueIndex)
  const reorderQueue   = usePlayerStore((s) => s.reorderQueue)
  const removeFromQueue= usePlayerStore((s) => s.removeFromQueue)
  const playQueue      = usePlayerStore((s) => s.playQueue)
  const setPanelMode   = usePlayerStore((s) => s.setPanelMode)

  // ── Drag state ────────────────────────────────────────────────────────────
  const dragFromRef  = useRef(null)
  const [dragOver, setDragOver] = useState(null) // index currently dragged over

  const handleDragStart = useCallback((index) => {
    dragFromRef.current = index
  }, [])

  const handleDragEnter = useCallback((index) => {
    setDragOver(index)
  }, [])

  const handleDragEnd = useCallback(() => {
    const from = dragFromRef.current
    const to   = dragOver
    if (from !== null && to !== null && from !== to) {
      reorderQueue(from, to)
    }
    dragFromRef.current = null
    setDragOver(null)
  }, [dragOver, reorderQueue])

  // ── Jump to track ─────────────────────────────────────────────────────────
  const handlePlay = useCallback((index) => {
    playQueue(queue, index)
  }, [queue, playQueue])

  // ── Remove from queue ─────────────────────────────────────────────────────
  const handleRemove = useCallback((index) => {
    removeFromQueue(index)
  }, [removeFromQueue])

  // ── Clear queue ───────────────────────────────────────────────────────────
  const handleClear = useCallback(() => {
    // Remove all songs except the currently playing one
    const store = usePlayerStore.getState()
    const current = store.currentSong
    if (current) {
      // Reset queue to only current song
      store.playQueue([current], 0)
    } else {
      // Nothing playing — wipe the queue entirely via repeated removes
      const len = usePlayerStore.getState().queue.length
      for (let i = len - 1; i >= 0; i--) {
        usePlayerStore.getState().removeFromQueue(i)
      }
    }
  }, [])

  // ── Close ─────────────────────────────────────────────────────────────────
  const handleClose = useCallback(() => {
    setPanelMode(PanelMode.QUEUE) // toggle off
  }, [setPanelMode])

  return (
    <aside
      aria-label="Queue"
      style={{
        width:        320,
        minWidth:     280,
        background:   'var(--color-main)',
        flexShrink:   0,
        display:      'flex',
        flexDirection:'column',
        overflow:     'hidden',
        boxSizing:    'border-box',
        borderTopLeftRadius: 12,
        borderBottomLeftRadius: 12,
      }}
    >
      {/* ── Header ── */}
      <div
        style={{
          display:        'flex',
          alignItems:     'center',
          justifyContent: 'space-between',
          padding:        '14px 16px 10px',
          flexShrink:     0,
          borderBottom:   '1px solid var(--color-highlight)',
        }}
      >
        <h2
          style={{
            margin:     0,
            fontSize:   16,
            fontWeight: 700,
            color:      'var(--color-text)',
          }}
        >
          Queue
        </h2>

        <button
          type="button"
          onClick={handleClose}
          aria-label="Close queue"
          style={{
            background:   'none',
            border:       'none',
            cursor:       'pointer',
            padding:      6,
            borderRadius: '50%',
            color:        'var(--color-subtext)',
            display:      'flex',
            alignItems:   'center',
            justifyContent: 'center',
            transition:   'color 0.15s, background 0.15s',
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.color = 'var(--color-text)'
            e.currentTarget.style.background = 'var(--color-highlight)'
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.color = 'var(--color-subtext)'
            e.currentTarget.style.background = 'none'
          }}
        >
          <svg
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.5"
            strokeLinecap="round"
            strokeLinejoin="round"
            aria-hidden="true"
          >
            <line x1="18" y1="6" x2="6" y2="18" />
            <line x1="6"  y1="6" x2="18" y2="18" />
          </svg>
        </button>
      </div>

      {/* ── Queue count ── */}
      {queue.length > 0 && (
        <p
          style={{
            margin:  0,
            padding: '8px 16px 2px',
            fontSize: 11,
            color:   'var(--color-subtext)',
            flexShrink: 0,
          }}
        >
          {queue.length} {queue.length === 1 ? 'song' : 'songs'}
        </p>
      )}

      {/* ── Scrollable list ── */}
      <div
        style={{
          flex:      1,
          overflowY: 'auto',
          overflowX: 'hidden',
          padding:   '4px 8px',
        }}
      >
        {queue.length === 0 ? (
          <div
            style={{
              display:        'flex',
              flexDirection:  'column',
              alignItems:     'center',
              justifyContent: 'center',
              height:         '100%',
              gap:            10,
              color:          'var(--color-subtext)',
              fontSize:       14,
              textAlign:      'center',
              padding:        '0 24px',
            }}
          >
            {/* Queue icon placeholder */}
            <svg
              width="40"
              height="40"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.5"
              strokeLinecap="round"
              strokeLinejoin="round"
              aria-hidden="true"
            >
              <line x1="8"  y1="6"  x2="21" y2="6"  />
              <line x1="8"  y1="12" x2="21" y2="12" />
              <line x1="8"  y1="18" x2="21" y2="18" />
              <line x1="3"  y1="6"  x2="3.01" y2="6"  />
              <line x1="3"  y1="12" x2="3.01" y2="12" />
              <line x1="3"  y1="18" x2="3.01" y2="18" />
            </svg>
            <span>Your queue is empty</span>
          </div>
        ) : (
          queue.map((song, i) => (
            <QueueItem
              key={`${song.id}-${i}`}
              song={song}
              index={i}
              isCurrent={i === queueIndex}
              onPlay={handlePlay}
              onRemove={handleRemove}
              onDragStart={handleDragStart}
              onDragEnter={handleDragEnter}
              onDragEnd={handleDragEnd}
              isDragOver={dragOver === i}
            />
          ))
        )}
      </div>

      {/* ── Clear queue button ── */}
      {queue.length > 1 && (
        <div
          style={{
            padding:     '10px 16px 14px',
            flexShrink:  0,
            borderTop:   '1px solid var(--color-highlight)',
          }}
        >
          <button
            type="button"
            onClick={handleClear}
            style={{
              width:        '100%',
              background:   'none',
              border:       '1px solid var(--color-highlight-elevated)',
              borderRadius:  6,
              padding:      '7px 0',
              fontSize:      13,
              fontWeight:    600,
              color:         'var(--color-subtext)',
              cursor:        'pointer',
              transition:    'color 0.15s, border-color 0.15s, background 0.15s',
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.color = 'var(--color-text)'
              e.currentTarget.style.borderColor = 'var(--color-text)'
              e.currentTarget.style.background = 'var(--color-highlight)'
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.color = 'var(--color-subtext)'
              e.currentTarget.style.borderColor = 'var(--color-highlight-elevated)'
              e.currentTarget.style.background = 'none'
            }}
          >
            Clear queue
          </button>
        </div>
      )}
    </aside>
  )
}
