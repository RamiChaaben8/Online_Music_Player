// src/stores/playerStore.js
// Central playback state — mirrors player_provider.dart
// Audio is driven by the YouTube IFrame API (see useYouTubePlayer hook).
// This store holds state only; the hook holds the YT player instance.

import { create } from 'zustand'

// Lazy passive-check to avoid circular imports.
// isPassiveDevice() reads Zustand state synchronously — no async needed.
let _isPassiveDevice = () => false
let _sendCmd = null

export function _initSyncBridge(isPassiveFn, sendCmdFn) {
  _isPassiveDevice = isPassiveFn
  _sendCmd = sendCmdFn
}

export const RepeatMode = {
  NONE: 'none',
  ONE: 'one',
  ALL: 'all',
}

export const PanelMode = {
  NONE: 'none',
  QUEUE: 'queue',
  NOW_PLAYING: 'nowplaying',
  LYRICS: 'lyrics',
}

export const usePlayerStore = create((set, get) => ({
  // ── Current track ────────────────────────────────────────────────────────
  currentSong: null,
  queue: [],          // full ordered queue
  queueIndex: -1,     // index of currentSong in queue

  // ── Playback state ───────────────────────────────────────────────────────
  playing: false,
  position: 0,        // seconds
  duration: 0,        // seconds
  buffering: false,

  // ── Controls state ───────────────────────────────────────────────────────
  volume: 0.8,
  muted: false,
  shuffle: false,
  repeat: RepeatMode.NONE,

  // ── UI panels ────────────────────────────────────────────────────────────
  panelMode: PanelMode.NONE,

  // ── Actions ──────────────────────────────────────────────────────────────

  playSong(song, queue = null, index = 0) {
    const q = queue ?? [song]
    const i = queue ? index : 0
    if (_isPassiveDevice()) {
      // Send command to active device; don't touch local state
      _sendCmd?.('playSong', { currentSong: song, queue: q, queueIndex: i, position: 0, playing: true })
      return
    }
    // If this exact song is already playing, just ensure playing=true (don't restart)
    const current = get()
    if (current.currentSong?.id === song.id && current.playing) return
    set({ currentSong: song, queue: q, queueIndex: i, playing: true, position: 0 })
  },

  playQueue(songs, startIndex = 0) {
    if (!songs.length) return
    if (_isPassiveDevice()) {
      const song = songs[startIndex]
      _sendCmd?.('playSong', { currentSong: song, queue: songs, queueIndex: startIndex, position: 0, playing: true })
      return
    }
    // If clicking the same song that's already playing, don't restart
    const current = get()
    const targetSong = songs[startIndex]
    if (current.currentSong?.id === targetSong?.id && current.playing) return
    set({
      queue: songs,
      queueIndex: startIndex,
      currentSong: songs[startIndex],
      playing: true,
      position: 0,
    })
  },

  setPlaying(playing) {
    if (_isPassiveDevice()) {
      _sendCmd?.('play_pause', playing)
    } else {
      set({ playing })
    }
  },

  setPosition(position) { set({ position }) },
  setDuration(duration) { set({ duration }) },
  setBuffering(buffering) { set({ buffering }) },

  setVolume(volume) { set({ volume, muted: false }) },
  toggleMute() {
    const { muted } = get()
    set({ muted: !muted })
  },

  toggleShuffle() { set((s) => ({ shuffle: !s.shuffle })) },

  cycleRepeat() {
    const { repeat } = get()
    const next = {
      [RepeatMode.NONE]: RepeatMode.ALL,
      [RepeatMode.ALL]:  RepeatMode.ONE,
      [RepeatMode.ONE]:  RepeatMode.NONE,
    }
    set({ repeat: next[repeat] })
  },

  skipNext() {
    if (_isPassiveDevice()) {
      _sendCmd?.('next')
      return
    }
    const { queue, queueIndex, shuffle, repeat } = get()
    if (!queue.length) return
    if (repeat === RepeatMode.ONE) { set({ position: 0, playing: true }); return }
    let next
    if (shuffle) {
      next = Math.floor(Math.random() * queue.length)
    } else {
      next = queueIndex + 1
      if (next >= queue.length) {
        if (repeat === RepeatMode.ALL) next = 0
        else { set({ playing: false }); return }
      }
    }
    set({ queueIndex: next, currentSong: queue[next], position: 0, playing: true })
  },

  skipPrev() {
    if (_isPassiveDevice()) {
      _sendCmd?.('prev')
      return
    }
    const { queue, queueIndex, position } = get()
    if (position > 3) { set({ position: 0 }); return }
    const prev = Math.max(0, queueIndex - 1)
    set({ queueIndex: prev, currentSong: queue[prev], position: 0, playing: true })
  },

  addToQueue(song) {
    set((s) => ({ queue: [...s.queue, song] }))
  },

  removeFromQueue(index) {
    set((s) => {
      const queue = [...s.queue]
      queue.splice(index, 1)
      const queueIndex = index < s.queueIndex
        ? s.queueIndex - 1
        : s.queueIndex
      return { queue, queueIndex }
    })
  },

  reorderQueue(from, to) {
    set((s) => {
      const queue = [...s.queue]
      const [item] = queue.splice(from, 1)
      queue.splice(to, 0, item)
      let queueIndex = s.queueIndex
      if (from === s.queueIndex) queueIndex = to
      else if (from < s.queueIndex && to >= s.queueIndex) queueIndex--
      else if (from > s.queueIndex && to <= s.queueIndex) queueIndex++
      return { queue, queueIndex }
    })
  },

  setPanelMode(mode) {
    set((s) => ({ panelMode: s.panelMode === mode ? PanelMode.NONE : mode }))
  },

  // Called by sync hook when restoring remote session
  restoreSession(song, queue, queueIndex, position) {
    set({
      currentSong: song,
      queue,
      queueIndex,
      position,
      playing: false, // restore paused, user decides when to resume
    })
  },
}))


