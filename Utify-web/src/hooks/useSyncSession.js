/**
 * useSyncSession.js
 *
 * React hook that mirrors sync_service.dart.
 *
 * Active device model:
 *  - One device owns playback (isActive=true in Firestore devices collection)
 *  - Active device saves state to state/remoteCommand every 10s + on events
 *  - Passive devices mirror the active device's state (song, position, playing)
 *  - Any device can claim active by writing isActive to its device doc
 *
 * Fixes applied:
 *  - Passive devices now mirror playing state (not always paused)
 *  - Passive devices apply live position updates from Firestore
 *  - claimDevice properly saves current state so other devices see the handoff
 *  - subscribeToPlaybackState only applies updates from the active device
 */

import { useCallback, useEffect, useRef } from 'react'
import { create } from 'zustand'
import { useAuthStore } from '../stores/authStore'
import { usePlayerStore } from '../stores/playerStore'
import {
  registerDevice,
  claimActiveDevice,
  releaseDevice,
  subscribeToDevices,
  savePlaybackState,
  loadPlaybackState,
  subscribeToPlaybackState,
  sendRemoteCommand,
} from '../services/firestoreService'

// ── Device ID ─────────────────────────────────────────────────────────────────

const DEVICE_ID_KEY = 'utify_device_id'

function getOrCreateDeviceId() {
  let id = localStorage.getItem(DEVICE_ID_KEY)
  if (!id) {
    id = crypto.randomUUID()
    localStorage.setItem(DEVICE_ID_KEY, id)
  }
  return id
}

function getDeviceName() {
  const ua = navigator.userAgent
  let browser = 'Browser'
  if (ua.includes('Firefox'))      browser = 'Firefox'
  else if (ua.includes('Edg'))     browser = 'Edge'
  else if (ua.includes('Chrome'))  browser = 'Chrome'
  else if (ua.includes('Safari'))  browser = 'Safari'

  let os = ''
  if (ua.includes('Win'))          os = ' · Windows'
  else if (ua.includes('Mac'))     os = ' · Mac'
  else if (ua.includes('Linux'))   os = ' · Linux'
  else if (ua.includes('Android')) os = ' · Android'
  else if (ua.includes('iPhone') || ua.includes('iPad')) os = ' · iOS'

  return `${browser}${os}`
}

// ── Internal sync store ───────────────────────────────────────────────────────

export const useSyncStore = create((set) => ({
  activeDevice: null,
  allDevices:   [],
  deviceId:     getOrCreateDeviceId(),
  deviceName:   getDeviceName(),

  setActiveDevice: (d)  => set({ activeDevice: d }),
  setAllDevices:   (ds) => set({ allDevices: ds }),
}))

// ── Main hook ─────────────────────────────────────────────────────────────────

export function useSyncSession() {
  const user       = useAuthStore((s) => s.user)
  const { deviceId, deviceName, setActiveDevice, setAllDevices } = useSyncStore()

  const activeDevice       = useSyncStore((s) => s.activeDevice)
  const isThisDeviceActive = activeDevice?.id === deviceId

  const intervalRef     = useRef(null)
  const unsubDevicesRef = useRef(null)
  const unsubPlaybackRef= useRef(null)
  const initializedRef  = useRef(false)

  // Track previous values for change detection
  const prevSongIdRef   = useRef(null)
  const prevPlayingRef  = useRef(null)
  const prevPositionRef = useRef(null)

  // ── Build save payload ────────────────────────────────────────────────────
  const buildStatePayload = useCallback((cmd = 'none') => {
    const s = usePlayerStore.getState()
    return {
      songId:     s.currentSong?.id   ?? null,
      songData:   s.currentSong       ?? null,
      queueIds:   s.queue.map((x) => x.id),
      queueData:  s.queue,
      queueIndex: s.queueIndex,
      position:   s.position,
      playing:    s.playing,
      command:    cmd,
      shuffle:    s.shuffle,
      repeat:     s.repeat,
    }
  }, [])

  // ── Save playback state to Firestore ──────────────────────────────────────
  const saveState = useCallback(async (cmd = 'none') => {
    if (!user) return
    try {
      await savePlaybackState(user.uid, buildStatePayload(cmd))
    } catch (err) {
      console.warn('[useSyncSession] saveState failed:', err)
    }
  }, [user, buildStatePayload])

  // ── Claim this device as active ───────────────────────────────────────────
  const claimDevice = useCallback(async () => {
    if (!user) return
    try {
      await claimActiveDevice(user.uid, deviceId)
      // Save our current state so other devices see the new active device's state
      await saveState('none')
    } catch (err) {
      console.warn('[useSyncSession] claimDevice failed:', err)
    }
  }, [user, deviceId, saveState])

  // ── Init ──────────────────────────────────────────────────────────────────
  useEffect(() => {
    if (!user || initializedRef.current) return
    initializedRef.current = true

    const uid = user.uid

    // 1. Register this device (writes lastActiveAt — Flutter filters on this field, < 75s)
    registerDevice(uid, deviceId, deviceName).catch(() => {})

    // 2. Heartbeat every 30s so Flutter doesn't prune us (75s stale threshold)
    const heartbeatInterval = setInterval(() => {
      registerDevice(uid, deviceId, deviceName).catch(() => {})
    }, 30_000)

    // 3. Load last playback state and restore it paused
    loadPlaybackState(uid).then((state) => {
      if (!state?.songData) return
      usePlayerStore.getState().restoreSession(
        state.songData,
        state.queueData ?? [state.songData],
        state.queueIndex ?? 0,
        state.position ?? 0,
      )
    }).catch(() => {})

    // 4. Subscribe to devices + activeDevice doc (merged by subscribeToDevices)
    unsubDevicesRef.current = subscribeToDevices(uid, (devices) => {
      setAllDevices(devices)
      const active = devices.find((d) => d.isActive) ?? null
      setActiveDevice(active)
    })

    // 4. Subscribe to playback state — passive devices mirror the active device
    unsubPlaybackRef.current = subscribeToPlaybackState(uid, (state) => {
      const syncState    = useSyncStore.getState()
      const activeId     = syncState.activeDevice?.id
      const isThisActive = activeId === deviceId

      // Only mirror if we are NOT the active device and the update came from
      // the active device (check deviceId in the state doc)
      if (isThisActive) return
      if (!state?.songData) return
      // Only apply if the update is from the current active device
      if (state.deviceId && activeId && state.deviceId !== activeId) return

      const ps = usePlayerStore.getState()

      // Update song/queue if it changed
      const songChanged = state.songData.id !== ps.currentSong?.id
      if (songChanged) {
        usePlayerStore.getState().restoreSession(
          state.songData,
          state.queueData ?? [state.songData],
          state.queueIndex ?? 0,
          state.position ?? 0,
        )
        // Mirror playing state from active device
        if (state.playing) {
          usePlayerStore.setState({ playing: true })
        }
        return
      }

      // Same song — sync position if drift > 3 seconds
      const drift = Math.abs(state.position - ps.position)
      if (drift > 3) {
        usePlayerStore.setState({ position: state.position })
        // Imperatively seek the YouTube player
        if (window.utifyPlayer?.seekTo) {
          window.utifyPlayer.seekTo(state.position, true)
        }
      }

      // Mirror play/pause state
      if (state.playing !== ps.playing) {
        usePlayerStore.setState({ playing: state.playing })
      }
    })

    // 5. 10-second auto-save interval (active device only)
    intervalRef.current = setInterval(() => {
      const syncState = useSyncStore.getState()
      const { playing: p } = usePlayerStore.getState()
      if (p && syncState.activeDevice?.id === deviceId) {
        saveState('none')
      }
    }, 10_000)

    return () => {
      initializedRef.current = false
      clearInterval(heartbeatInterval)
      unsubDevicesRef.current?.()
      unsubDevicesRef.current = null

      unsubPlaybackRef.current?.()
      unsubPlaybackRef.current = null

      clearInterval(intervalRef.current)
      intervalRef.current = null

      const isActive = useSyncStore.getState().activeDevice?.id === deviceId
      if (isActive) {
        saveState('none').finally(() => releaseDevice(uid, deviceId).catch(() => {}))
      } else {
        releaseDevice(uid, deviceId).catch(() => {})
      }
    }
  }, [user?.uid]) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Watch: auto-start when THIS device becomes active ────────────────────
  // When activeDevice changes from someone-else to THIS device, start playing
  // (handles the case where another device transfers playback to us)
  const activeDeviceId = useSyncStore((s) => s.activeDevice?.id)
  const prevActiveRef  = useRef(null)
  useEffect(() => {
    const prev    = prevActiveRef.current
    const isNowMe = activeDeviceId === deviceId
    const wasSomeoneElse = prev !== null && prev !== deviceId
    // Just became active (transitioned from another device or null to this device)
    if (isNowMe && wasSomeoneElse && user) {
      // Resume playback — position was already synced by subscribeToPlaybackState
      const ps = usePlayerStore.getState()
      if (ps.currentSong) {
        usePlayerStore.setState({ playing: true })
      }
    }
    prevActiveRef.current = activeDeviceId
  }, [activeDeviceId, deviceId, user])

  // ── Watch: save on pause/resume ───────────────────────────────────────────
  const playing = usePlayerStore((s) => s.playing)
  useEffect(() => {
    if (!user || !isThisDeviceActive) return
    if (prevPlayingRef.current === null) { prevPlayingRef.current = playing; return }
    if (prevPlayingRef.current !== playing) {
      prevPlayingRef.current = playing
      saveState(playing ? 'play' : 'pause')
    }
  }, [playing, user, isThisDeviceActive, saveState])

  // ── Watch: save on track change ───────────────────────────────────────────
  const currentSong = usePlayerStore((s) => s.currentSong)
  useEffect(() => {
    if (!user || !isThisDeviceActive || !currentSong) return
    if (prevSongIdRef.current && prevSongIdRef.current !== currentSong.id) {
      saveState('playSong')
    }
    prevSongIdRef.current = currentSong?.id ?? null
  }, [currentSong?.id, user, isThisDeviceActive, saveState]) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Watch: save on seek ───────────────────────────────────────────────────
  const position = usePlayerStore((s) => s.position)
  useEffect(() => {
    if (!user || !isThisDeviceActive) return
    if (prevPositionRef.current !== null) {
      const delta = Math.abs(position - prevPositionRef.current)
      if (delta > 3) saveState('seek')
    }
    prevPositionRef.current = position
  }, [position, user, isThisDeviceActive, saveState])

  return { activeDevice, isThisDeviceActive, claimDevice }
}

// ── useRemotePlayback ─────────────────────────────────────────────────────────

export function useRemotePlayback() {
  const user       = useAuthStore((s) => s.user)
  const allDevices = useSyncStore((s) => s.allDevices)
  const deviceId   = useSyncStore((s) => s.deviceId)

  const remoteDevice = allDevices.find(
    (d) => d.isActive && d.id !== deviceId
  ) ?? null

  const claimHere = useCallback(async () => {
    if (!user) return
    try {
      // 1. Read current synced position from Firestore so we resume at the right place
      const currentState = await loadPlaybackState(user.uid)

      // 2. Tell the currently active device to pause
      await sendRemoteCommand(user.uid, 'pause')

      // 3. Small delay so the active device receives the pause
      await new Promise((r) => setTimeout(r, 300))

      // 4. Claim this device as active
      await claimActiveDevice(user.uid, deviceId)

      // 5. Restore the position from Firestore into our local store
      if (currentState?.songData) {
        usePlayerStore.setState({
          currentSong: currentState.songData,
          queue:       currentState.queueData ?? [currentState.songData],
          queueIndex:  currentState.queueIndex ?? 0,
          position:    currentState.position ?? 0,
          playing:     false, // start paused, then resume below
        })
        // Seek YT player to the correct position
        if (window.utifyPlayer?.seekTo) {
          window.utifyPlayer.seekTo(currentState.position ?? 0, true)
        }
      }

      // 6. Save our state as active and start playing
      const s = usePlayerStore.getState()
      await savePlaybackState(user.uid, {
        songData:   s.currentSong,
        queueData:  s.queue,
        queueIndex: s.queueIndex,
        position:   s.position,
        playing:    true,
        command:    'play',
      })

      // 7. Start playing
      usePlayerStore.setState({ playing: true })

    } catch (err) {
      console.warn('[useRemotePlayback] claimHere failed:', err)
    }
  }, [user, deviceId])

  return { remoteDevice, claimHere }
}
