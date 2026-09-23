// src/services/firestoreService.js
// All Firestore reads/writes — mirrors firestore_service.dart

import {
  collection,
  doc,
  setDoc,
  getDoc,
  getDocs,
  addDoc,
  updateDoc,
  deleteDoc,
  onSnapshot,
  serverTimestamp,
  arrayUnion,
  arrayRemove,
  query,
  where,
  orderBy,
  writeBatch,
  increment,
} from 'firebase/firestore'
import { db } from '../firebase'

// ── Helpers ───────────────────────────────────────────────────────────────────

const userCol = (uid, col) => collection(db, 'users', uid, col)
const userDoc = (uid, col, id) => doc(db, 'users', uid, col, id)
const stateDoc = (uid, sub) => doc(db, 'users', uid, 'state', sub)

// Serialize a Song object → Firestore map (matches Flutter's _songToMap)
const songToMap = (song) => ({
  id:          song.id,
  title:       song.title,
  artist:      song.channelName,   // Flutter uses 'artist'
  coverUrl:    song.thumbnailUrl,  // Flutter uses 'coverUrl'
  durationMs:  (song.durationSeconds ?? 0) * 1000,
})

// Deserialize a Firestore map → Song object (matches Flutter's _docToSong)
const songFromMap = (data) => ({
  id:              data.id           || '',
  title:           data.title        || 'Unknown',
  channelName:     data.artist       || data.channelName || '',  // support both
  thumbnailUrl:    data.coverUrl     || data.thumbnailUrl || '',
  durationSeconds: data.durationMs
    ? Math.round(data.durationMs / 1000)
    : (data.durationSeconds ?? 0),
})

// ── Profile ───────────────────────────────────────────────────────────────────

export async function upsertProfile(user) {
  await setDoc(
    doc(db, 'users', user.uid),
    {
      displayName: user.displayName || '',
      email: user.email || '',
      photoURL: user.photoURL || '',
      updatedAt: serverTimestamp(),
    },
    { merge: true }
  )
}

export async function getPublicProfile(uid) {
  const snap = await getDoc(doc(db, 'publicProfiles', uid))
  if (!snap.exists()) return null
  return { uid, ...snap.data() }
}

export async function createPublicProfile(user, username) {
  const normalized = username.trim().toLowerCase()
  if (!/^[a-z0-9_]{3,20}$/.test(normalized)) {
    throw new Error('Username must be 3-20 characters: lowercase letters, numbers, or _')
  }

  const usernameRef = doc(db, 'usernames', normalized)
  const profileRef = doc(db, 'publicProfiles', user.uid)

  const [usernameSnap, profileSnap] = await Promise.all([
    getDoc(usernameRef),
    getDoc(profileRef),
  ])

  if (usernameSnap.exists()) throw new Error('That username is already taken.')
  if (profileSnap.exists()) throw new Error('Your public profile already exists.')

  const batch = writeBatch(db)
  batch.set(profileRef, {
    username: normalized,
    displayName: user.displayName || '',
    photoURL: user.photoURL || '',
    createdAt: serverTimestamp(),
    friendCount: 0,
    privacy: 'public',
  })
  batch.set(usernameRef, { uid: user.uid })
  await batch.commit()
}

// ── Playlists ─────────────────────────────────────────────────────────────────

export function subscribeToPlaylists(uid, callback) {
  let p1 = []
  let p2 = []

  const update = () => callback([...p1, ...p2])

  const q1 = query(userCol(uid, 'playlists'), orderBy('createdAt', 'asc'))
  const unsub1 = onSnapshot(q1, (snap) => {
    p1 = snap.docs.map((d) => {
      const data = d.data()
      const tracks = (data.tracks || data.songs || []).map(songFromMap)
      return {
        id:          d.id,
        name:        data.name        || 'Untitled',
        description: data.description || '',
        visibility:  data.visibility  || 'private',
        pinned:      data.pinned      || false,
        folderId:    data.folderId    || null,
        ownerUid:    data.ownerUid    || uid,
        ownerName:   data.ownerName   || '',
        sharedId:    data.sharedId    || null,
        songs:       tracks,
        createdAt:   data.createdAt?.toDate?.() ?? new Date(),
        updatedAt:   data.updatedAt?.toDate?.() ?? new Date(),
      }
    })
    update()
  })

  const q2 = query(collection(db, 'sharedPlaylists'), where('memberUids', 'array-contains', uid))
  const unsub2 = onSnapshot(q2, (snap) => {
    p2 = snap.docs.map((d) => {
      const data = d.data()
      const tracks = (data.tracks || data.songs || []).map(songFromMap)
      return {
        id:          d.id, // we use sharedId as id so it renders correctly
        name:        data.name        || 'Untitled',
        description: data.description || '',
        visibility:  data.visibility  || 'private',
        pinned:      data.pinned      || false,
        folderId:    data.folderId    || null,
        ownerUid:    data.ownerUid    || uid,
        ownerName:   data.ownerName   || '',
        sharedId:    d.id,
        songs:       tracks,
        createdAt:   data.createdAt?.toDate?.() ?? new Date(),
        updatedAt:   data.updatedAt?.toDate?.() ?? new Date(),
      }
    })
    update()
  })

  return () => { unsub1(); unsub2() }
}

export async function createPlaylist(uid, data) {
  const ref = await addDoc(userCol(uid, 'playlists'), {
    name:        data.name,
    description: data.description || '',
    coverUrl:    '',               // Flutter uses coverUrl
    trackIds:    [],               // Flutter uses trackIds
    tracks:      [],               // Flutter uses tracks (not songs)
    visibility:  data.visibility || 'private',
    pinned:      data.pinned || false,
    folderId:    data.folderId || null,
    ownerUid:    uid,
    createdAt:   serverTimestamp(),
    updatedAt:   serverTimestamp(),
  })
  return ref.id
}

export async function updatePlaylist(uid, playlistId, updates) {
  await updateDoc(userDoc(uid, 'playlists', playlistId), {
    ...updates,
    updatedAt: serverTimestamp(),
  })
}

export async function deletePlaylist(uid, playlistId) {
  await deleteDoc(userDoc(uid, 'playlists', playlistId))
}

export async function addSongToPlaylist(uid, playlistId, song) {
  const ref = userDoc(uid, 'playlists', playlistId)
  const snap = await getDoc(ref)
  if (!snap.exists()) return
  const tracks = snap.data().tracks || snap.data().songs || []
  if (tracks.some((t) => t.id === song.id)) return // already in playlist
  await updateDoc(ref, {
    trackIds:   arrayUnion(song.id),
    tracks:     [...tracks, songToMap(song)],
    updatedAt:  serverTimestamp(),
  })
}

export async function removeSongFromPlaylist(uid, playlistId, songId) {
  const ref = userDoc(uid, 'playlists', playlistId)
  const snap = await getDoc(ref)
  if (!snap.exists()) return
  const tracks = (snap.data().tracks || snap.data().songs || []).filter((t) => t.id !== songId)
  await updateDoc(ref, {
    trackIds:  arrayRemove(songId),
    tracks,
    updatedAt: serverTimestamp(),
  })
}

export async function reorderPlaylistSongs(uid, playlistId, songs) {
  await updateDoc(userDoc(uid, 'playlists', playlistId), {
    trackIds:  songs.map((s) => s.id),
    tracks:    songs.map(songToMap),
    updatedAt: serverTimestamp(),
  })
}

// ── Liked Songs ───────────────────────────────────────────────────────────────

export function subscribeToLikedSongs(uid, callback) {
  return onSnapshot(userCol(uid, 'likes'), (snap) => {
    const songs = snap.docs.map((d) => songFromMap(d.data()))
    callback(songs)
  })
}

export async function likeSong(uid, song) {
  await setDoc(userDoc(uid, 'likes', song.id), {
    ...songToMap(song),
    likedAt: serverTimestamp(),
  })
}

export async function unlikeSong(uid, songId) {
  await deleteDoc(userDoc(uid, 'likes', songId))
}

// ── Playback State ────────────────────────────────────────────────────────────


// ── Remote command (passive → active) ─────────────────────────────────────────
// Writes a command to the remoteCommand doc.
// The active device (Flutter or web) reads this and executes it.

export async function sendRemoteCommand(uid, command, extra = {}) {
  const deviceId = localStorage.getItem("utify_device_id") || "web-unknown"
  const { usePlayerStore } = await import("../stores/playerStore")
  const s = usePlayerStore.getState()
  const song = extra.currentSong ?? s.currentSong
  await setDoc(stateDoc(uid, "remoteCommand"), {
    command,
    currentTrack: song ? songToMap(song) : null,
    queue:        (extra.queue ?? s.queue ?? []).map(songToMap),
    queueIndex:   extra.queueIndex ?? s.queueIndex ?? 0,
    positionMs:   Math.round(((extra.position ?? s.position) ?? 0) * 1000),
    isPlaying:    extra.playing ?? s.playing ?? false,
    deviceId,
    deviceName:   "Utify Web",
    updatedAt:    serverTimestamp(),
  })
}


export async function savePlaybackState(uid, state) {
  const deviceId = localStorage.getItem("utify_device_id") || "web-unknown"
  await setDoc(stateDoc(uid, "remoteCommand"), {
    command:      state.command || "none",
    currentTrack: state.songData ? songToMap(state.songData) : null,
    queue:        (state.queueData || []).map(songToMap),
    queueIndex:   state.queueIndex ?? 0,
    positionMs:   Math.round((state.position ?? 0) * 1000),
    isPlaying:    state.playing ?? false,
    deviceId,
    deviceName:   "Utify Web",
    updatedAt:    serverTimestamp(),
  })
}

export async function publishRemoteCommand(uid, cmd, overrideState = {}) {
  const { usePlayerStore } = await import("../stores/playerStore")
  const s = usePlayerStore.getState()
  const deviceId = localStorage.getItem("utify_device_id") || "web-unknown"
  const song = overrideState.currentSong || s.currentSong
  await setDoc(stateDoc(uid, "remoteCommand"), {
    command:      cmd,
    currentTrack: song ? songToMap(song) : null,
    queue:        (overrideState.queue || s.queue || []).map(songToMap),
    queueIndex:   overrideState.queueIndex ?? s.queueIndex ?? 0,
    positionMs:   Math.round(((overrideState.position ?? s.position) ?? 0) * 1000),
    isPlaying:    overrideState.playing ?? s.playing ?? false,
    deviceId,
    deviceName:   "Utify Web",
    updatedAt:    serverTimestamp(),
  })
}

export async function loadPlaybackState(uid) {
  const snap = await getDoc(stateDoc(uid, "remoteCommand"))
  if (!snap.exists()) return null
  const d = snap.data()
  // Support both currentTrack (Flutter/web) and legacy field names
  const trackMap = d.currentTrack ?? d.currentSong ?? null
  return {
    songData:   trackMap ? songFromMap(trackMap) : null,
    queueData:  (d.queue || []).map(songFromMap),
    queueIndex: d.queueIndex ?? 0,
    position:   Math.round((d.positionMs ?? 0) / 1000),
    playing:    d.isPlaying ?? false,
    command:    d.command ?? "none",
    deviceId:   d.deviceId ?? null,
  }
}

export function subscribeToPlaybackState(uid, callback) {
  return onSnapshot(stateDoc(uid, "remoteCommand"), (snap) => {
    if (!snap.exists()) return
    const d = snap.data()
    const trackMap = d.currentTrack ?? d.currentSong ?? null
    callback({
      songData:   trackMap ? songFromMap(trackMap) : null,
      queueData:  (d.queue || []).map(songFromMap),
      queueIndex: d.queueIndex ?? 0,
      position:   (d.positionMs ?? 0) / 1000,
      playing:    d.isPlaying ?? false,
      command:    d.command ?? "none",
      deviceId:   d.deviceId ?? null,
    })
  })
}

// ── Devices / Presence ────────────────────────────────────────────────────────

export async function registerDevice(uid, deviceId, deviceName) {
  // Flutter schema: devices/{deviceId} has name, platform, lastActiveAt
  // (no isActive field — active state is in state/activeDevice doc)
  // Also write lastSeen for backward compat, clear old isActive field
  await setDoc(userDoc(uid, 'devices', deviceId), {
    name:         deviceName,
    platform:     'web',
    lastActiveAt: serverTimestamp(),
    lastSeen:     serverTimestamp(),   // backward compat
    isActive:     false,               // clear old field so it doesn't confuse things
  }, { merge: true })
}

export async function claimActiveDevice(uid, deviceId) {
  // Flutter schema: state/activeDevice = { activeDeviceId, activeDeviceName, activeAt }
  // Get our device name first
  const devSnap = await getDoc(userDoc(uid, 'devices', deviceId))
  const deviceName = devSnap.exists() ? (devSnap.data().name || 'Utify Web') : 'Utify Web'

  await setDoc(
    doc(db, 'users', uid, 'state', 'activeDevice'),
    {
      activeDeviceId:   deviceId,
      activeDeviceName: deviceName,
      activeAt:         serverTimestamp(),
    }
  )
  // Also heartbeat our device doc
  await setDoc(userDoc(uid, 'devices', deviceId), {
    lastActiveAt: serverTimestamp(),
  }, { merge: true })
}

export async function releaseDevice(uid, deviceId) {
  // Only release if we are the current active device
  const snap = await getDoc(doc(db, 'users', uid, 'state', 'activeDevice'))
  if (snap.exists() && snap.data()?.activeDeviceId === deviceId) {
    await deleteDoc(doc(db, 'users', uid, 'state', 'activeDevice'))
  }
}

export function subscribeToDevices(uid, callback) {
  // Subscribe to both the devices collection and the activeDevice doc
  // so we can merge them into a unified list with isActive flag
  let devicesList  = []
  let activeDeviceId = null

  function emit() {
    const now = Date.now()

    const getMs = (ts) => {
      if (!ts) return null
      if (typeof ts.toMillis === 'function') return ts.toMillis()
      if (typeof ts.seconds === 'number') return ts.seconds * 1000
      if (typeof ts === 'number') return ts
      return null
    }

    const active = devicesList
      .filter((d) => {
        // Use lastActiveAt first, fall back to lastSeen (old web field)
        const ms = getMs(d.lastActiveAt) ?? getMs(d.lastSeen)
        if (ms == null) return true   // timestamp pending, include it
        return (now - ms) < 5 * 60 * 1000  // 5 min window (generous for cross-device)
      })
      .map((d) => ({
        ...d,
        isActive: d.id === activeDeviceId,
      }))
    callback(active)
  }

  const unsubDevices = onSnapshot(
    collection(db, 'users', uid, 'devices'),
    (snap) => {
      devicesList = snap.docs.map((d) => ({ id: d.id, ...d.data() }))
      emit()
    }
  )

  const unsubActive = onSnapshot(
    doc(db, 'users', uid, 'state', 'activeDevice'),
    (snap) => {
      activeDeviceId = snap.exists() ? snap.data()?.activeDeviceId : null
      emit()
    }
  )

  return () => { unsubDevices(); unsubActive() }
}

// ── Friends ───────────────────────────────────────────────────────────────────

export function subscribeToFriendRequests(uid, callback) {
  return onSnapshot(
    query(collection(db, 'friendships'), where('members', 'array-contains', uid), where('status', '==', 'pending')),
    (snap) => {
      const requests = snap.docs
        .map((d) => ({ id: d.id, ...d.data() }))
        .filter((r) => r.requestedBy !== uid) // only incoming
        .map((r) => ({ ...r, fromUid: r.requestedBy }))
      callback(requests)
    }
  )
}

export async function sendFriendRequest(fromUid, toUid) {
  const fid = [fromUid, toUid].sort().join('_')
  const ref = doc(db, 'friendships', fid)
  const existing = await getDoc(ref)
  if (existing.exists()) {
    if (existing.data().status === 'accepted') throw new Error('You are already friends.')
    throw new Error('Request already sent.')
  }
  await setDoc(ref, {
    members: [fromUid, toUid].sort(),
    status: 'pending',
    requestedBy: fromUid,
    createdAt: serverTimestamp(),
  })
}

export async function acceptFriendRequest(requestId) {
  await updateDoc(doc(db, 'friendships', requestId), {
    status: 'accepted',
    acceptedAt: serverTimestamp(),
  })
}

export async function declineFriendRequest(requestId) {
  await deleteDoc(doc(db, 'friendships', requestId))
}

export function subscribeToFriends(uid, callback) {
  return onSnapshot(
    query(collection(db, 'friendships'), where('members', 'array-contains', uid), where('status', '==', 'accepted')),
    async (snap) => {
      if (snap.empty) { callback([]); return }
      const profiles = await Promise.all(snap.docs.map(async (d) => {
        const otherUid = d.data().members.find(m => m !== uid)
        return await getPublicProfile(otherUid)
      }))
      callback(profiles.filter(Boolean))
    }
  )
}

// ── Listen Party ──────────────────────────────────────────────────────────────

export async function createListenParty(uid, songId, songData) {
  const ref = await addDoc(collection(db, 'listenParties'), {
    hostUid: uid,
    songId,
    songData: songToMap(songData),
    position: 0,
    playing: true,
    members: [uid],
    createdAt: serverTimestamp(),
  })
  return ref.id
}

export async function joinListenParty(partyId, uid) {
  await updateDoc(doc(db, 'listenParties', partyId), {
    members: arrayUnion(uid),
  })
}

export async function leaveListenParty(partyId, uid) {
  await updateDoc(doc(db, 'listenParties', partyId), {
    members: arrayRemove(uid),
  })
}

export function subscribeToListenParty(partyId, callback) {
  return onSnapshot(doc(db, 'listenParties', partyId), (snap) => {
    if (!snap.exists()) { callback(null); return }
    callback({ id: snap.id, ...snap.data() })
  })
}

export async function updateListenPartyState(partyId, position, playing) {
  await updateDoc(doc(db, 'listenParties', partyId), { position, playing, updatedAt: serverTimestamp() })
}

// ── Delete user data ──────────────────────────────────────────────────────────

export async function deleteUserData(uid) {
  const collections = ['playlists', 'likes', 'devices']
  for (const col of collections) {
    const snap = await getDocs(userCol(uid, col))
    const batch = writeBatch(db)
    snap.docs.forEach((d) => batch.delete(d.ref))
    await batch.commit()
  }
  // Delete state docs
  const stateSnap = await getDocs(collection(db, 'users', uid, 'state'))
  const batch2 = writeBatch(db)
  stateSnap.docs.forEach((d) => batch2.delete(d.ref))
  batch2.delete(doc(db, 'users', uid))
  await batch2.commit()
}


