// src/hooks/useYouTubePlayer.js
// Manages the YouTube IFrame API player instance.
// The actual <div id="yt-player"> must exist in the DOM before this hook
// initialises — render it once in App.jsx (hidden, position fixed off-screen).

import { useEffect, useRef, useCallback } from 'react'
import { usePlayerStore } from '../stores/playerStore'

// ── Script loader (runs once per page load) ──────────────────────────────────

let ytApiReady = false          // true once window.YT.Player is available
let ytApiLoading = false        // prevents duplicate <script> injection
const ytReadyCallbacks = []     // queue of callbacks waiting for the API

function loadYTApi() {
  if (ytApiReady || ytApiLoading) return
  ytApiLoading = true

  // YT calls this global when the API is fully loaded
  const prevCallback = window.onYouTubeIframeAPIReady
  window.onYouTubeIframeAPIReady = () => {
    ytApiReady = true
    if (prevCallback) prevCallback()
    ytReadyCallbacks.forEach((cb) => cb())
    ytReadyCallbacks.length = 0
  }

  const script = document.createElement('script')
  script.src = 'https://www.youtube.com/iframe_api'
  script.async = true
  document.head.appendChild(script)
}

function onYTReady(cb) {
  if (ytApiReady) {
    cb()
  } else {
    ytReadyCallbacks.push(cb)
    loadYTApi()
  }
}

// ── Hook ─────────────────────────────────────────────────────────────────────

export function useYouTubePlayer() {
  const playerRef = useRef(null)          // YT.Player instance
  const playerReadyRef = useRef(false)    // true once onReady fires
  const positionPollRef = useRef(null)    // setInterval id

  // Snapshot only the primitives / stable actions we need to avoid re-running
  // effects on every position tick.
  const currentSong   = usePlayerStore((s) => s.currentSong)
  const playing       = usePlayerStore((s) => s.playing)
  const volume        = usePlayerStore((s) => s.volume)
  const muted         = usePlayerStore((s) => s.muted)
  const repeat        = usePlayerStore((s) => s.repeat)

  const setPosition   = usePlayerStore((s) => s.setPosition)
  const setDuration   = usePlayerStore((s) => s.setDuration)
  const setBuffering  = usePlayerStore((s) => s.setBuffering)
  const setPlaying    = usePlayerStore((s) => s.setPlaying)
  const skipNext      = usePlayerStore((s) => s.skipNext)

  // ── position poll ─────────────────────────────────────────────────────────

  const startPoll = useCallback(() => {
    if (positionPollRef.current) return
    positionPollRef.current = setInterval(() => {
      const p = playerRef.current
      if (p && typeof p.getCurrentTime === 'function') {
        const pos = p.getCurrentTime()
        if (typeof pos === 'number' && !isNaN(pos)) {
          setPosition(pos)
        }
      }
    }, 500)
  }, [setPosition])

  const stopPoll = useCallback(() => {
    if (positionPollRef.current) {
      clearInterval(positionPollRef.current)
      positionPollRef.current = null
    }
  }, [])

  // ── Initialise YT.Player ──────────────────────────────────────────────────

  useEffect(() => {
    // Ensure the anchor div exists (fallback if App hasn't rendered it yet)
    if (!document.getElementById('yt-player')) {
      const div = document.createElement('div')
      div.id = 'yt-player'
      // Hidden off-screen so it doesn't affect layout
      div.style.cssText =
        'position:fixed;top:-9999px;left:-9999px;width:1px;height:1px;pointer-events:none;'
      document.body.appendChild(div)
    }

    onYTReady(() => {
      if (playerRef.current) return // already created

      playerRef.current = new window.YT.Player('yt-player', {
        height: '1',
        width: '1',
        playerVars: {
          autoplay: 0,
          controls: 0,
          disablekb: 1,
          enablejsapi: 1,
          modestbranding: 1,
          playsinline: 1,
          rel: 0,
          origin: window.location.origin,
        },
        events: {
          onReady(event) {
            playerReadyRef.current = true

            // Apply stored volume immediately
            const { volume: vol, muted: isMuted } = usePlayerStore.getState()
            event.target.setVolume(isMuted ? 0 : Math.round(vol * 100))

            // If a song was already selected before the player was ready, load it
            const { currentSong: song, playing: isPlaying } =
              usePlayerStore.getState()
            if (song?.id) {
              event.target.loadVideoById(song.id)
              if (!isPlaying) event.target.pauseVideo()
            }
          },

          onStateChange(event) {
            const YT = window.YT.PlayerState
            switch (event.data) {
              case YT.PLAYING:
                setBuffering(false)
                setPlaying(true)
                // Capture duration on first play
                {
                  const dur = playerRef.current?.getDuration?.()
                  if (dur && dur > 0) setDuration(dur)
                }
                startPoll()
                break

              case YT.PAUSED:
                setBuffering(false)
                setPlaying(false)
                stopPoll()
                // Capture final position
                {
                  const pos = playerRef.current?.getCurrentTime?.()
                  if (pos != null) setPosition(pos)
                }
                break

              case YT.ENDED:
                stopPoll()
                setPlaying(false)
                skipNext()
                break

              case YT.BUFFERING:
                setBuffering(true)
                break

              case YT.CUED:
                setBuffering(false)
                break

              default:
                break
            }
          },

          onError(event) {
            console.error('[YT Player] error code', event.data)
            setBuffering(false)
            // Skip to next on unplayable video errors (101, 150)
            if (event.data === 101 || event.data === 150) {
              skipNext()
            }
          },
        },
      })
    })

    return () => {
      stopPoll()
      // Don't destroy the player on unmount — hook may remount on HMR.
      // Destruction is only done when the whole app unmounts.
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []) // intentionally empty — run once

  // ── React to currentSong changes ──────────────────────────────────────────

  useEffect(() => {
    const p = playerRef.current
    if (!playerReadyRef.current || !p) return

    if (currentSong?.id) {
      p.loadVideoById(currentSong.id)
      // loadVideoById auto-plays; if store says not playing, pause after cue
      if (!playing) {
        // Brief timeout to let the player initialise before pausing
        setTimeout(() => p.pauseVideo?.(), 200)
      }
    }
  // We deliberately exclude `playing` here — the playing effect below handles that.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentSong?.id])

  // ── React to playing state changes ────────────────────────────────────────

  useEffect(() => {
    const p = playerRef.current
    if (!playerReadyRef.current || !p) return

    if (playing) {
      p.playVideo?.()
    } else {
      p.pauseVideo?.()
    }
  }, [playing])

  // ── React to volume / mute changes ───────────────────────────────────────

  useEffect(() => {
    const p = playerRef.current
    if (!playerReadyRef.current || !p) return
    p.setVolume?.(muted ? 0 : Math.round(volume * 100))
  }, [volume, muted])

  // ── React to repeat ONE — seek to 0 when position resets ─────────────────
  // (skipNext in the store sets position:0 + playing:true for RepeatMode.ONE)
  // The playing effect above will call playVideo, which continues from current
  // position. We need to also seek to 0.
  const storePosition = usePlayerStore((s) => s.position)

  useEffect(() => {
    const { repeat: r } = usePlayerStore.getState()
    const p = playerRef.current
    if (!playerReadyRef.current || !p) return
    // Only seek when store explicitly resets to 0 for repeat-one
    if (r === 'one' && storePosition === 0) {
      p.seekTo?.(0, true)
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [storePosition === 0 && repeat === 'one'])

  // ── Imperative API ────────────────────────────────────────────────────────

  const play = useCallback((videoId) => {
    const p = playerRef.current
    if (!p) return
    if (videoId) {
      p.loadVideoById(videoId)
    } else {
      p.playVideo?.()
    }
  }, [])

  const pause = useCallback(() => {
    playerRef.current?.pauseVideo?.()
  }, [])

  const resume = useCallback(() => {
    playerRef.current?.playVideo?.()
  }, [])

  const seekTo = useCallback((seconds) => {
    playerRef.current?.seekTo?.(seconds, true)
    setPosition(seconds)
  }, [setPosition])

  const setVolume = useCallback((pct) => {
    // pct: 0-100
    playerRef.current?.setVolume?.(Math.round(Math.max(0, Math.min(100, pct))))
  }, [])

  const getPosition = useCallback(() => {
    return playerRef.current?.getCurrentTime?.() ?? 0
  }, [])

  // ── Expose imperative API globally ───────────────────────────────────────
  // window.utifyPlayer is used by PlayerBar (and other components) to drive
  // seek and volume imperatively without going through React props.
  // We keep it in sync with the latest callbacks on every render.
  useEffect(() => {
    window.utifyPlayer = { play, pause, resume, seekTo, setVolume, getPosition }
    return () => {
      // Clear only if we are still the owner (guard against future re-mounts)
      if (window.utifyPlayer?.seekTo === seekTo) {
        window.utifyPlayer = null
      }
    }
  }, [play, pause, resume, seekTo, setVolume, getPosition])

  return {
    playerReady: playerReadyRef.current,
    play,
    pause,
    resume,
    seekTo,
    setVolume,
    getPosition,
  }
}
