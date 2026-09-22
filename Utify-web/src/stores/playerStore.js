// src/stores/playerStore.js
// Central playback state — mirrors player_provider.dart
// Audio is driven by the YouTube IFrame API (see useYouTubePlayer hook).
// This store holds state only; the hook holds the YT player instance.

import { create } from 'zustand'

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
    
    // Check if we are a passive device
    import("../hooks/useSyncSession").then(({ useSyncStore }) => {
      const syncStore = useSyncStore.getState()
      const isPassive = syncStore.activeDevice?.id && syncStore.activeDevice.id !== syncStore.deviceId
      if (isPassive) {
        import("../services/firestoreService").then(({ publishRemoteCommand }) => {
          import("./authStore").then(({ useAuthStore }) => {
            const uid = useAuthStore.getState().user?.uid
            if (uid) publishRemoteCommand(uid, "playSong", { currentSong: song, queue: q, queueIndex: i, position: 0, playing: true }).catch(console.error)
          })
        })
      } else {
        set({ currentSong: song, queue: q, queueIndex: i, playing: true, position: 0 })
      }
    })
  },

  playQueue(songs, startIndex = 0) {
    if (!songs.length) return
    set({
      queue: songs,
      queueIndex: startIndex,
      currentSong: songs[startIndex],
      playing: true,
      position: 0,
    })
  },

  setPlaying(playing) { set({ playing }) },
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
    const { queue, queueIndex, shuffle, repeat } = get()
    if (!queue.length) return

    if (repeat === RepeatMode.ONE) {
      // signal player to seek to 0 — handled by useYouTubePlayer
      set({ position: 0, playing: true })
      return
    }

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
    const { queue, queueIndex, position } = get()
    if (position > 3) {
      // seek to beginning
      set({ position: 0 })
      return
    }
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


