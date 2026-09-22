/**
 * useSyncSession.js
 *
 * React hook that mirrors sync_service.dart.
 *
 * Responsibilities:
 *  - Generate / persist a stable deviceId in localStorage
 *  - Register this device in Firestore on mount
 *  - Load the last saved playback state from Firestore, restore it into
 *    playerStore (paused) so the user can choose when to resume
 *  - Subscribe to the devices collection to detect other active devices
 *  - Save playback state every 10 s while playing, and immediately on
 *    pause / seek / track change
 *  - Release device presence on unmount with a final state save
 *
 * Exports:
 *  - useSyncSession()     → { activeDevice, isThisDeviceActive, claimDevice }
 *  - useRemotePlayback()  → { remoteDevice, claimHere }
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

/**
 * Returns a human-readable name for this browser/device.
 * Used so the remote-playback banner can say "Playing on Chrome – MacBook".
 */
function getDeviceName() {
  const ua = navigator.userAgent
  let browser = 'Browser'
  if (ua.includes('Firefox'))      browser = 'Firefox'
  else if (ua.includes('Edg'))     browser = 'Edge'
  else if (ua.includes('Chrome'))  browser = 'Chrome'
  else if (ua.includes('Safari'))  browser = 'Safari'

  let os = ''
  if (ua.includes('Win'))        os = ' · Windows'
  else if (ua.includes('Mac'))   os = ' · Mac'
  else if (ua.includes('Linux')) os = ' · Linux'
  else if (ua.includes('Android')) os = ' · Android'
  else if (ua.includes('iPhone') || ua.includes('iPad')) os = ' · iOS'

  return `${browser}${os}`
}

// ── Internal sync store (not exported directly) ────────────────────────────

/**
 * Small Zustand slice that holds cross-hook sync state.
 * Both useSyncSession and useRemotePlayback read from here.
 */
export const useSyncStore = create((set) => ({
  /** Device object from Firestore that is currently marked isActive=true
   *  (could be this device or another one). */
  activeDevice:       null,
  /** All known devices for this user. */
  allDevices:         [],
  /** The stable deviceId for this browser tab. */
  deviceId:           getOrCreateDeviceId(),
  /** Human-readable name for this device. */
  deviceName:         getDeviceName(),

  setActiveDevice:  (d) => set({ activeDevice: d }),
  setAllDevices:    (ds) => set({ allDevices: ds }),
}))

// ── Main hook ─────────────────────────────────────────────────────────────────

/**
 * useSyncSession()
 *
 * Should be called once near the root of the authenticated app tree
 * (e.g. in AppShell).
 *
 * Returns:
 *  - activeDevice          Object | null — the Firestore device doc that is
 *                          currently active, or null.
 *  - isThisDeviceActive    boolean — true when *this* tab is the active device.
 *  - claimDevice()         async fn — marks this device active in Firestore
 *                          and saves current playback state.
 */
export function useSyncSession() {
  const user          = useAuthStore((s) => s.user)
  const { deviceId, deviceName, setActiveDevice, setAllDevices } =
    useSyncStore()

  // Player state selectors — use getState() for non-reactive reads in
  // callbacks to avoid stale closure issues.
  const currentSong   = usePlayerStore((s) => s.currentSong)
  const playing       = usePlayerStore((s) => s.playing)
  const position      = usePlayerStore((s) => s.position)
  const queueIndex    = usePlayerStore((s) => s.queueIndex)

  const restoreSession = usePlayerStore((s) => s.restoreSession)

  const activeDevice       = useSyncStore((s) => s.activeDevice)
  const isThisDeviceActive = activeDevice?.id === deviceId

  // ── Refs ──────────────────────────────────────────────────────────────────────
  const intervalRef        = useRef(null)
  const unsubDevicesRef    = useRef(null)
  const unsubPlaybackRef   = useRef(null)
  const initializedRef     = useRef(false)
  const prevSongIdRef      = useRef(null)
  const prevPlayingRef     = useRef(null)
  const prevPositionRef    = useRef(null)

  // ── Build the playback state payload ─────────────────────────────────────
  const buildStatePayload = useCallback((cmd = "none") => {
    const s = usePlayerStore.getState()
    return {
      songId:    s.currentSong?.id    ?? null,
      songData:  s.currentSong        ?? null,
      queueIds:  s.queue.map((x) => x.id),
      queueData: s.queue,
      queueIndex: s.queueIndex,
      position:  s.position,
      playing:   s.playing,
      command:   cmd,
      shuffle:   s.shuffle,
      repeat:    s.repeat,
    }
  }, [])

  // ── Save playback state ───────────────────────────────────────────────────
  const saveState = useCallback(async () => {
    if (!user) return
    try {
      await savePlaybackState(user.uid, buildStatePayload("none"))
    } catch (err) {
      // Non-fatal — offline persistence will queue it
      console.warn('[useSyncSession] saveState failed:', err)
    }
  }, [user, buildStatePayload])

  // ── Claim device as active ────────────────────────────────────────────────
  const claimDevice = useCallback(async () => {
    if (!user) return
    try {
      await claimActiveDevice(user.uid, deviceId)
      await saveState()
    } catch (err) {
      console.warn('[useSyncSession] claimDevice failed:', err)
    }
  }, [user, deviceId, saveState])
  

  // ── Init: register device, load state, subscribe to devices ──────────────
  useEffect(() => {
    if (!user || initializedRef.current) return
    initializedRef.current = true

    const uid = user.uid

    // 1. Register / heartbeat this device
    registerDevice(uid, deviceId, deviceName).catch(() => {})

    // 2. Load last playback state and restore it (paused)
    loadPlaybackState(uid).then((state) => {
      if (!state || !state.songData) return
      restoreSession(
        state.songData,
        state.queueData ?? [state.songData],
        state.queueIndex ?? 0,
        state.position  ?? 0
      )
    }).catch(() => {})

    // 3. Subscribe to devices collection
    unsubDevicesRef.current = subscribeToDevices(uid, (devices) => {
      setAllDevices(devices)
      const active = devices.find((d) => d.isActive) ?? null
      setActiveDevice(active)
    })

    // 4. Subscribe to playback state updates (for passive syncing)
    unsubPlaybackRef.current = subscribeToPlaybackState(uid, (state) => {
      const activeId = useSyncStore.getState().activeDevice?.id
      // If we are NOT the active device, stay in sync with the active device
      if (activeId && activeId !== deviceId && state && state.songData) {
        restoreSession(
          state.songData,
          state.queueData ?? [state.songData],
          state.queueIndex ?? 0,
          state.position  ?? 0
        )
      }
    })

    // 5. Start 10-second auto-save interval (only saves if we are active)
    intervalRef.current = setInterval(() => {
      const activeId = useSyncStore.getState().activeDevice?.id
      const { playing: p } = usePlayerStore.getState()
      if (p && activeId === deviceId) saveState()
    }, 10_000)

    return () => {
      // Cleanup on unmount (user signs out or component unmounts)
      initializedRef.current = false

      if (unsubDevicesRef.current) {
        unsubDevicesRef.current()
        unsubDevicesRef.current = null
      }

      if (unsubPlaybackRef.current) {
        unsubPlaybackRef.current()
        unsubPlaybackRef.current = null
      }

      if (intervalRef.current) {
        clearInterval(intervalRef.current)
        intervalRef.current = null
      }

      // Final save + release device
      if (useSyncStore.getState().activeDevice?.id === deviceId) {
        saveState().finally(() => {
          releaseDevice(uid, deviceId).catch(() => {})
        })
      } else {
        releaseDevice(uid, deviceId).catch(() => {})
      }
    }
  }, [user?.uid]) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Watch: save on pause ──────────────────────────────────────────────────
  useEffect(() => {
    if (!user) return
    if (prevPlayingRef.current === null) {
      prevPlayingRef.current = playing
      return
    }
    if (prevPlayingRef.current !== playing) {
      prevPlayingRef.current = playing
      // Save when playback pauses
      if (!playing) saveState()
    }
  }, [playing, user, saveState])

  // ── Watch: save on track change ───────────────────────────────────────────
  useEffect(() => {
    if (!user || !currentSong) return
    if (prevSongIdRef.current && prevSongIdRef.current !== currentSong.id) {
      saveState()
    }
    prevSongIdRef.current = currentSong?.id ?? null
  }, [currentSong?.id, user, saveState]) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Watch: save on seek (position jump > 3 s) ─────────────────────────────
  useEffect(() => {
    if (!user) return
    if (prevPositionRef.current !== null) {
      const delta = Math.abs(position - prevPositionRef.current)
      // A 500ms poll advances position ~0.5 s; treat jumps > 3 s as seeks
      if (delta > 3) saveState()
    }
    prevPositionRef.current = position
  }, [position, user, saveState])

  return { activeDevice, isThisDeviceActive, claimDevice }
}

// ── useRemotePlayback ─────────────────────────────────────────────────────────

/**
 * useRemotePlayback()
 *
 * Lightweight hook for the RemotePlaybackBanner component.
 * Returns { remoteDevice, claimHere } where:
 *  - remoteDevice  Object | null — another device that is currently active
 *  - claimHere     async fn     — calls claimActiveDevice for this device
 */
export function useRemotePlayback() {
  const user       = useAuthStore((s) => s.user)
  const allDevices = useSyncStore((s) => s.allDevices)
  const deviceId   = useSyncStore((s) => s.deviceId)
  const isActive   = useSyncStore((s) => s.activeDevice?.id === deviceId)

  const remoteDevice = allDevices.find(
    (d) => d.isActive && d.id !== deviceId
  ) ?? null

  const claimHere = useCallback(async () => {
    if (!user) return
    try {
      await claimActiveDevice(user.uid, deviceId)
      // Also save current state so the remote device sees we've taken over
      const s = usePlayerStore.getState()
      await savePlaybackState(user.uid, {
        songId:    s.currentSong?.id   ?? null,
        songData:  s.currentSong       ?? null,
        queueIds:  s.queue.map((x) => x.id),
        queueData: s.queue,
        queueIndex: s.queueIndex,
        position:  s.position,
        shuffle:   s.shuffle,
        repeat:    s.repeat,
      })
    } catch (err) {
      console.warn('[useRemotePlayback] claimHere failed:', err)
    }
  }, [user, deviceId])

  return { remoteDevice, claimHere, isActive }
}



