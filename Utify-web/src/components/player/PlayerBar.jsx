/**
 * PlayerBar.jsx
 * Fixed 80-px bottom bar — mirrors desktop_player_bar.dart from the Flutter app.
 *
 * Layout (3 equal-ish columns):
 *   LEFT  (30%) — thumbnail · title · channel · like
 *   CENTER(40%) — transport controls + seek bar
 *   RIGHT (30%) — panel toggles + volume
 *
 * Styling: CSS variables only, no Tailwind.
 * Icons: lucide-react.
 */

import { useCallback, useEffect, useRef, useState } from 'react'
import {
  Heart,
  LayoutList,
  ListMusic,
  Mic2,
  Pause,
  Play,
  Repeat,
  Repeat1,
  Shuffle,
  SkipBack,
  SkipForward,
  Volume2,
  VolumeX,
  MonitorSpeaker,
} from "lucide-react"

import { usePlayerStore, PanelMode, RepeatMode } from "../../stores/playerStore"
import { useAuthStore } from "../../stores/authStore"
import { useSyncStore } from "../../hooks/useSyncSession"
import { useLibraryStore } from '../../stores/libraryStore'


// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/** Formats a time in seconds to m:ss  (e.g. 75 → "1:15") */
function formatTime(seconds) {
  if (!seconds || isNaN(seconds) || seconds < 0) return '0:00'
  const s = Math.floor(seconds)
  const m = Math.floor(s / 60)
  const remaining = s % 60
  return `${m}:${remaining.toString().padStart(2, '0')}`
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-components
// ─────────────────────────────────────────────────────────────────────────────

/** Invisible button reset — keeps a consistent base style. */
function IconBtn({ onClick, title, active, highlight, children, style = {} }) {
  const [hovered, setHovered] = useState(false)

  return (
    <button
      onClick={onClick}
      title={title}
      aria-label={title}
      aria-pressed={active}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        background: 'none',
        border: 'none',
        cursor: 'pointer',
        padding: 6,
        borderRadius: 4,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        color: highlight
          ? 'var(--color-button)'
          : active
          ? 'var(--color-text)'
          : 'var(--color-subtext)',
        opacity: hovered ? 1 : active || highlight ? 0.9 : 0.7,
        transition: 'opacity 0.15s, color 0.15s',
        flexShrink: 0,
        ...style,
      }}
    >
      {children}
    </button>
  )
}

// ─────────────────────────────────────────────────────────────────────────────
// Seek + Volume slider — shared range styling via injected <style>
// ─────────────────────────────────────────────────────────────────────────────

const SLIDER_STYLE_ID = 'utify-slider-styles'

function ensureSliderStyles() {
  if (document.getElementById(SLIDER_STYLE_ID)) return
  const style = document.createElement('style')
  style.id = SLIDER_STYLE_ID
  style.textContent = `
    .utify-range {
      -webkit-appearance: none;
      appearance: none;
      cursor: pointer;
      height: 4px;
      border-radius: 2px;
      /* background is set via inline style (gradient fill) */
    }
    .utify-range:focus {
      outline: none;
    }
    /* Track — must be transparent so inline background gradient shows through */
    .utify-range::-webkit-slider-runnable-track {
      height: 4px;
      border-radius: 2px;
      background: transparent !important;
    }
    .utify-range::-moz-range-track {
      height: 4px;
      border-radius: 2px;
      background: transparent !important;
    }
    /* Thumb */
    .utify-range::-webkit-slider-thumb {
      -webkit-appearance: none;
      appearance: none;
      width: 12px;
      height: 12px;
      border-radius: 50%;
      background: #fff;
      margin-top: -4px;
      transition: transform 0.15s ease, box-shadow 0.15s ease;
    }
    .utify-range::-moz-range-thumb {
      width: 12px;
      height: 12px;
      border-radius: 50%;
      background: #fff;
      border: none;
      transition: transform 0.15s ease, box-shadow 0.15s ease;
    }
    .utify-range:hover::-webkit-slider-thumb {
      transform: scale(1.3);
      box-shadow: 0 0 10px rgba(255, 255, 255, 0.8), 0 0 4px rgba(29, 185, 84, 0.5);
    }
    .utify-range:hover::-moz-range-thumb {
      transform: scale(1.3);
      box-shadow: 0 0 10px rgba(255, 255, 255, 0.8), 0 0 4px rgba(29, 185, 84, 0.5);
    }
    .utify-vol-range {
      width: 80px;
    }
  `
  document.head.appendChild(style)
}

// ─────────────────────────────────────────────────────────────────────────────
// LEFT SECTION — thumbnail · title · channel · like
// ─────────────────────────────────────────────────────────────────────────────

function LeftSection({ currentSong, onOpenNowPlaying }) {
  const uid = useAuthStore((s) => s.user?.uid)
  const isLiked = useLibraryStore((s) =>
    currentSong ? s.likedSongs.some((x) => x.id === currentSong.id) : false
  )
  const toggleLike = useLibraryStore((s) => s.toggleLike)

  // Next song in queue
  const queue      = usePlayerStore((s) => s.queue)
  const queueIndex = usePlayerStore((s) => s.queueIndex)
  const nextSong   = queue[queueIndex + 1] ?? null

  const handleLike = useCallback(() => {
    if (!uid || !currentSong) return
    toggleLike(uid, currentSong)
  }, [uid, currentSong, toggleLike])

  if (!currentSong) {
    return <div style={{ width: '30%', minWidth: 0 }} />
  }

  const thumbnailUrl =
    currentSong.thumbnail ||
    `https://i.ytimg.com/vi/${currentSong.id}/default.jpg`

  const nextThumbUrl = nextSong
    ? (nextSong.thumbnail || `https://i.ytimg.com/vi/${nextSong.id}/default.jpg`)
    : null

  return (
    <div
      style={{
        width: '30%',
        minWidth: 0,
        display: 'flex',
        alignItems: 'center',
        gap: 12,
        paddingLeft: 16,
        overflow: 'hidden',
      }}
    >
      {/* Thumbnail */}
      <img
        src={thumbnailUrl}
        alt={currentSong.title}
        width={48}
        height={48}
        style={{
          width: 48,
          height: 48,
          borderRadius: 6,
          objectFit: 'cover',
          flexShrink: 0,
          cursor: 'pointer',
        }}
        onClick={onOpenNowPlaying}
      />

      {/* Title + channel */}
      <div
        style={{
          minWidth: 0,
          flex: 1,
          overflow: 'hidden',
        }}
      >
        <div
          onClick={onOpenNowPlaying}
          title={currentSong.title}
          style={{
            fontSize: 13,
            fontWeight: 600,
            color: 'var(--color-text)',
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            cursor: 'pointer',
          }}
        >
          {currentSong.title}
        </div>
        <div
          title={currentSong.channel || currentSong.channelTitle}
          style={{
            fontSize: 11,
            color: 'var(--color-subtext)',
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            marginTop: 2,
          }}
        >
          {currentSong.channel || currentSong.channelTitle || ''}
        </div>
      </div>

      {/* Like button */}
      <IconBtn
        onClick={handleLike}
        title={isLiked ? 'Remove from liked songs' : 'Save to liked songs'}
        active={isLiked}
        highlight={isLiked}
        style={{ color: isLiked ? 'var(--color-button)' : 'var(--color-subtext)' }}
      >
        <Heart
          size={18}
          fill={isLiked ? 'var(--color-button)' : 'none'}
          strokeWidth={isLiked ? 0 : 2}
        />
      </IconBtn>

      {/* Next song — shown when queue has a next track */}
      {nextSong && (
        <div style={{
          display:      'flex',
          alignItems:   'center',
          gap:          8,
          paddingLeft:  12,
          borderLeft:   '1px solid var(--color-highlight)',
          minWidth:     0,
          overflow:     'hidden',
          flexShrink:   0,
          maxWidth:     160,
        }}>
          <div style={{ minWidth: 0, overflow: 'hidden' }}>
            <div style={{
              fontSize:     10,
              fontWeight:   700,
              color:        'var(--color-button)',
              letterSpacing: 0.5,
              textTransform: 'uppercase',
              marginBottom: 2,
            }}>
              Next
            </div>
            <div style={{
              fontSize:     12,
              fontWeight:   600,
              color:        'var(--color-text)',
              whiteSpace:   'nowrap',
              overflow:     'hidden',
              textOverflow: 'ellipsis',
            }}>
              {nextSong.title}
            </div>
            <div style={{
              fontSize:     11,
              color:        'var(--color-subtext)',
              whiteSpace:   'nowrap',
              overflow:     'hidden',
              textOverflow: 'ellipsis',
              marginTop:    1,
            }}>
              {nextSong.channelName || nextSong.channel || nextSong.channelTitle || ''}
            </div>
          </div>
          {nextThumbUrl && (
            <img
              src={nextThumbUrl}
              alt=""
              style={{
                width:        36,
                height:       36,
                borderRadius: 4,
                objectFit:    'cover',
                flexShrink:   0,
              }}
            />
          )}
        </div>
      )}
    </div>
  )
}

// ─────────────────────────────────────────────────────────────────────────────
// CENTER SECTION — controls + seek bar
// ─────────────────────────────────────────────────────────────────────────────

function CenterSection({ seekTo }) {
  const isThisDeviceActive = useSyncStore((s) => s.activeDevice?.id === s.deviceId)
  const uid = useAuthStore((s) => s.user?.uid)
  const playing = usePlayerStore((s) => s.playing)
  const position = usePlayerStore((s) => s.position)
  const duration = usePlayerStore((s) => s.duration)
  const shuffle = usePlayerStore((s) => s.shuffle)
  const repeat = usePlayerStore((s) => s.repeat)
  const buffering = usePlayerStore((s) => s.buffering)

  const setPlaying = usePlayerStore((s) => s.setPlaying)
  const toggleShuffle = usePlayerStore((s) => s.toggleShuffle)
  const cycleRepeat = usePlayerStore((s) => s.cycleRepeat)
  const skipNext = usePlayerStore((s) => s.skipNext)
  const skipPrev = usePlayerStore((s) => s.skipPrev)
  const setPosition = usePlayerStore((s) => s.setPosition)

  // Local seeking state — while dragging, display the drag value, not the
  // live polled position.
  const [seeking, setSeeking] = useState(false)
  const [seekValue, setSeekValue] = useState(0)

  const displayPosition = seeking ? seekValue : position
  const progress = duration > 0 ? (displayPosition / duration) * 100 : 0

  // Build colorful multi-highlight gradient for the passed seek timeline track
  const seekTrackStyle = {
    background: `linear-gradient(to right, transparent ${progress}%, var(--color-highlight) ${progress}%), linear-gradient(to right, #FF007F 0%, #FF5E36 20%, #FFAE00 40%, #1DB954 60%, #00F2FE 80%, #9D4EDD 100%)`,
  }

  const handleSeekMouseDown = () => {
    setSeeking(true)
    setSeekValue(position)
  }

  const handleSeekChange = (e) => {
    setSeekValue(Number(e.target.value))
  }

  const handleSeekMouseUp = (e) => {
    const val = Number(e.target.value)
    setSeeking(false)
    seekTo(val)
    setPosition(val)
  }

  // Repeat icon
  const RepeatIcon =
    repeat === RepeatMode.ONE ? Repeat1 : Repeat
  const repeatActive = repeat !== RepeatMode.NONE

  return (
    <div
      style={{
        width: '40%',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 6,
        userSelect: 'none',
      }}
    >
      {/* ── Row 1: Transport controls ── */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 4,
        }}
      >
        {/* Shuffle */}
        <IconBtn
          onClick={toggleShuffle}
          title={shuffle ? 'Disable shuffle' : 'Enable shuffle'}
          active={shuffle}
          highlight={shuffle}
        >
          <Shuffle size={18} />
        </IconBtn>

        {/* Skip Previous */}
        <IconBtn onClick={skipPrev} title="Previous" active>
          <SkipBack size={20} />
        </IconBtn>

        {/* Play / Pause — larger circle */}
        <button
          onClick={() => setPlaying(!playing)}
          title={playing ? 'Pause' : 'Play'}
          aria-label={playing ? 'Pause' : 'Play'}
          disabled={buffering}
          style={{
            width: 36,
            height: 36,
            borderRadius: '50%',
            background: 'var(--color-button)',
            border: 'none',
            cursor: buffering ? 'default' : 'pointer',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
            opacity: buffering ? 0.6 : 1,
            transition: 'opacity 0.15s, transform 0.1s',
            color: 'var(--color-player)',
          }}
          onMouseEnter={(e) => { if (!buffering) e.currentTarget.style.transform = 'scale(1.06)' }}
          onMouseLeave={(e) => { e.currentTarget.style.transform = 'scale(1)' }}
        >
          {playing
            ? <Pause size={18} fill="var(--color-player)" strokeWidth={0} />
            : <Play size={18} fill="var(--color-player)" strokeWidth={0} style={{ marginLeft: 2 }} />
          }
        </button>

        {/* Skip Next */}
        <IconBtn onClick={skipNext} title="Next" active>
          <SkipForward size={20} />
        </IconBtn>

        {/* Repeat */}
        <IconBtn
          onClick={cycleRepeat}
          title={
            repeat === RepeatMode.NONE
              ? 'Enable repeat'
              : repeat === RepeatMode.ALL
              ? 'Enable repeat one'
              : 'Disable repeat'
          }
          active={repeatActive}
          highlight={repeatActive}
        >
          <RepeatIcon size={18} />
        </IconBtn>
      </div>

      {/* ── Row 2: Progress bar ── */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 8,
          width: '100%',
          maxWidth: 480,
        }}
      >
        {/* Current time */}
        <span
          style={{
            fontSize: 11,
            color: 'var(--color-subtext)',
            minWidth: 32,
            textAlign: 'right',
            fontVariantNumeric: 'tabular-nums',
          }}
        >
          {formatTime(displayPosition)}
        </span>

        {/* Seek bar */}
        <input
          type="range"
          className="utify-range utify-seek-range"
          min={0}
          max={duration > 0 ? duration : 100}
          step={0.5}
          value={displayPosition}
          onMouseDown={handleSeekMouseDown}
          onChange={handleSeekChange}
          onMouseUp={handleSeekMouseUp}
          // Touch devices
          onTouchStart={handleSeekMouseDown}
          onTouchEnd={handleSeekMouseUp}
          aria-label="Seek"
          aria-valuemin={0}
          aria-valuemax={duration}
          aria-valuenow={Math.floor(displayPosition)}
          style={{
            flex: 1,
            ...seekTrackStyle,
          }}
        />

        {/* Total duration */}
        <span
          style={{
            fontSize: 11,
            color: 'var(--color-subtext)',
            minWidth: 32,
            fontVariantNumeric: 'tabular-nums',
          }}
        >
          {formatTime(duration)}
        </span>
      </div>
    </div>
  )
}

// ─────────────────────────────────────────────────────────────────────────────
// RIGHT SECTION — panel toggles + volume
// ─────────────────────────────────────────────────────────────────────────────

import DevicePicker from "../sync/DevicePicker"

function RightSection() {
  const [devicePickerOpen, setDevicePickerOpen] = useState(false)
  const deviceBtnRef = useRef(null)
  const panelMode = usePlayerStore((s) => s.panelMode)
  const setPanelMode = usePlayerStore((s) => s.setPanelMode)
  const volume = usePlayerStore((s) => s.volume)
  const muted = usePlayerStore((s) => s.muted)
  const setVolume = usePlayerStore((s) => s.setVolume)
  const toggleMute = usePlayerStore((s) => s.toggleMute)

  // Show green tint on device button when another device is the active one
  const activeDevice = useSyncStore((s) => s.activeDevice)
  const myDeviceId   = useSyncStore((s) => s.deviceId)
  const remoteIsActive = activeDevice && activeDevice.id !== myDeviceId

  // Clamp to 0-100 for the slider
  const volPct = Math.round(volume * 100)
  const volProgress = muted ? 0 : volPct

  const volTrackStyle = {
    background: `linear-gradient(to right, #1DB954 0%, #1ED760 ${volProgress}%, var(--color-highlight) ${volProgress}%)`,
  }

  const handleVolumeChange = (e) => {
    const pct = Number(e.target.value) // 0-100
    setVolume(pct / 100)               // store uses 0.0–1.0
    // Drive the YT player imperatively so there is zero lag
    window.utifyPlayer?.setVolume?.(pct)
  }

  const handleMuteToggle = () => {
    toggleMute()
    // Imperatively mute/unmute the YT player
    if (!muted) {
      window.utifyPlayer?.setVolume?.(0)
    } else {
      window.utifyPlayer?.setVolume?.(volPct)
    }
  }

  return (
    <div
      style={{
        width: '30%',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'flex-end',
        gap: 4,
        paddingRight: 16,
        position: 'relative',
      }}
    >
      {/* Device Picker */}
        <div ref={deviceBtnRef} style={{ position: "relative" }}>
          <IconBtn
            onClick={() => setDevicePickerOpen(!devicePickerOpen)}
            title={remoteIsActive ? `Playing on ${activeDevice?.name}` : "Connect to a device"}
            highlight={remoteIsActive}
          >
            <MonitorSpeaker size={18} />
          </IconBtn>
          {devicePickerOpen && <DevicePicker anchorRef={deviceBtnRef} onClose={() => setDevicePickerOpen(false)} />}
        </div>
        {/* Now Playing panel toggle */}
      <IconBtn
        onClick={() => setPanelMode(PanelMode.NOW_PLAYING)}
        title="Now playing"
        highlight={panelMode === PanelMode.NOW_PLAYING}
      >
        <LayoutList size={18} />
      </IconBtn>

      {/* Queue panel toggle */}
      <IconBtn
        onClick={() => setPanelMode(PanelMode.QUEUE)}
        title="Queue"
        highlight={panelMode === PanelMode.QUEUE}
      >
        <ListMusic size={18} />
      </IconBtn>

      {/* Lyrics panel toggle */}
      <IconBtn
        onClick={() => setPanelMode(PanelMode.LYRICS)}
        title="Lyrics"
        highlight={panelMode === PanelMode.LYRICS}
      >
        <Mic2 size={18} />
      </IconBtn>

      {/* Volume icon — click to mute/unmute */}
      <IconBtn
        onClick={handleMuteToggle}
        title={muted ? 'Unmute' : 'Mute'}
        active
      >
        {muted || volPct === 0
          ? <VolumeX size={18} />
          : <Volume2 size={18} />
        }
      </IconBtn>

      {/* Volume slider */}
      <input
        type="range"
        className="utify-range utify-vol-range"
        min={0}
        max={100}
        step={1}
        value={muted ? 0 : volPct}
        onChange={handleVolumeChange}
        aria-label="Volume"
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={muted ? 0 : volPct}
        style={volTrackStyle}
      />
    </div>
  )
}

// ─────────────────────────────────────────────────────────────────────────────
// Main export
// ─────────────────────────────────────────────────────────────────────────────

export default function PlayerBar() {
  // Inject slider CSS once
  useEffect(() => { ensureSliderStyles() }, [])

  const currentSong = usePlayerStore((s) => s.currentSong)
  const setPanelMode = usePlayerStore((s) => s.setPanelMode)
  const setPosition = usePlayerStore((s) => s.setPosition)
  const user = useAuthStore((s) => s.user)

  // seekTo: if passive → send seek command to active device
  //          if active  → seek local YT player
  const seekTo = useCallback((seconds) => {
    const { activeDevice, deviceId } = useSyncStore.getState()
    const isPassive = activeDevice?.id && activeDevice.id !== deviceId
    if (isPassive && user?.uid) {
      import('../../services/firestoreService').then(({ sendRemoteCommand }) => {
        sendRemoteCommand(user.uid, 'seek', { position: seconds }).catch(console.error)
      })
    } else {
      window.utifyPlayer?.seekTo?.(seconds)
      setPosition(seconds)
    }
  }, [setPosition, user?.uid])
  const openNowPlaying = useCallback(() => {
    setPanelMode(PanelMode.NOW_PLAYING)
  }, [setPanelMode])

  // Expose the YT player imperatively so PlayerBar (and other components) can
  // call setVolume / seekTo without prop-drilling.  The hook in AppShell
  // already returns these; we re-expose them here for completeness.
  // AppShell's useYouTubePlayer() sets window.utifyPlayer via the hook.
  // (See: useYouTubePlayer returns { seekTo, setVolume, … })

  return (
    <footer
      role="region"
      aria-label="Player controls"
      style={{
        height: 80,
        minHeight: 80,
        background: 'var(--color-player)',
        flexShrink: 0,
        display: 'flex',
        alignItems: 'center',
        zIndex: 100,
        overflow: 'hidden',
      }}
    >
      <LeftSection
        currentSong={currentSong}
        onOpenNowPlaying={openNowPlaying}
      />

      <CenterSection seekTo={seekTo} />

      <RightSection />
    </footer>
  )
}






