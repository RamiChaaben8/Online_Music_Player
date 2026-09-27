// src/stores/libraryStore.js
// Mirrors library_provider.dart — playlists + liked songs, synced from Firestore

import { create } from 'zustand'
import { useAuthStore } from './authStore'
import {
  subscribeToPlaylists,
  subscribeToLikedSongs,
  createPlaylist,
  updatePlaylist,
  deletePlaylist,
  likeSong,
  unlikeSong,
  addSongToPlaylist,
  removeSongFromPlaylist,
  reorderPlaylistSongs,
} from '../services/firestoreService'

const GUEST_LIBRARY_KEY = 'utify_guest_library_v1'
const guestMode = () => useAuthStore.getState().isGuest
function readGuestLibrary() {
  try {
    const saved = JSON.parse(localStorage.getItem(GUEST_LIBRARY_KEY) || '{}')
    return {
      playlists: Array.isArray(saved.playlists) ? saved.playlists : [],
      likedSongs: Array.isArray(saved.likedSongs) ? saved.likedSongs : [],
    }
  } catch {
    return { playlists: [], likedSongs: [] }
  }
}
function saveGuestLibrary(playlists, likedSongs) {
  localStorage.setItem(GUEST_LIBRARY_KEY, JSON.stringify({ playlists, likedSongs }))
}

export const useLibraryStore = create((set, get) => ({
  playlists: [],
  likedSongs: [],
  loading: false,
  unsubscribePlaylists: null,
  unsubscribeLikes: null,

  // Subscribe to Firestore real-time updates for current user
  init(uid) {
    if (guestMode()) return get().initGuest()
    // Clean up any existing subscriptions
    get().destroy()

    const unsubPlaylists = subscribeToPlaylists(uid, (playlists) => {
      set({ playlists })
    })

    const unsubLikes = subscribeToLikedSongs(uid, (likedSongs) => {
      set({ likedSongs })
    })

    set({ unsubscribePlaylists: unsubPlaylists, unsubscribeLikes: unsubLikes })
  },

  initGuest() {
    get().destroy()
    set({ ...readGuestLibrary(), loading: false })
  },

  destroy() {
    const { unsubscribePlaylists, unsubscribeLikes } = get()
    unsubscribePlaylists?.()
    unsubscribeLikes?.()
    set({ playlists: [], likedSongs: [], unsubscribePlaylists: null, unsubscribeLikes: null })
  },

  async createPlaylist(uid, name, description = '') {
    if (guestMode()) {
      const id = `guest-${crypto.randomUUID()}`
      const playlists = [...get().playlists, {
        id, ownerUid: null, name, description, songs: [], visibility: 'private',
        pinned: false, createdAt: Date.now(), sharedId: null,
      }]
      set({ playlists })
      saveGuestLibrary(playlists, get().likedSongs)
      return id
    }
    return createPlaylist(uid, { name, description, songs: [], visibility: 'private', pinned: false })
  },

  async updatePlaylist(uid, playlistId, updates) {
    if (guestMode()) {
      const playlists = get().playlists.map((p) => p.id === playlistId ? { ...p, ...updates } : p)
      set({ playlists })
      saveGuestLibrary(playlists, get().likedSongs)
      return
    }
    await updatePlaylist(uid, playlistId, updates)
  },

  async deletePlaylist(uid, playlistId) {
    if (guestMode()) {
      const playlists = get().playlists.filter((p) => p.id !== playlistId)
      set({ playlists })
      saveGuestLibrary(playlists, get().likedSongs)
      return
    }
    await deletePlaylist(uid, playlistId)
  },

  async addSongToPlaylist(uid, playlistId, song) {
    if (guestMode()) {
      const playlists = get().playlists.map((p) => p.id === playlistId && !p.songs.some((s) => s.id === song.id)
        ? { ...p, songs: [...p.songs, song] } : p)
      set({ playlists })
      saveGuestLibrary(playlists, get().likedSongs)
      return
    }
    await addSongToPlaylist(uid, playlistId, song)
  },

  async removeSongFromPlaylist(uid, playlistId, songId) {
    if (guestMode()) {
      const playlists = get().playlists.map((p) => p.id === playlistId
        ? { ...p, songs: p.songs.filter((s) => s.id !== songId) } : p)
      set({ playlists })
      saveGuestLibrary(playlists, get().likedSongs)
      return
    }
    await removeSongFromPlaylist(uid, playlistId, songId)
  },

  async reorderSongs(uid, playlistId, songs) {
    if (guestMode()) {
      const playlists = get().playlists.map((p) => p.id === playlistId ? { ...p, songs } : p)
      set({ playlists })
      saveGuestLibrary(playlists, get().likedSongs)
      return
    }
    await reorderPlaylistSongs(uid, playlistId, songs)
  },

  isLiked(songId) {
    return get().likedSongs.some((s) => s.id === songId)
  },

  async toggleLike(uid, song) {
    const liked = get().isLiked(song.id)
    if (guestMode()) {
      const likedSongs = liked
        ? get().likedSongs.filter((item) => item.id !== song.id)
        : [...get().likedSongs, song]
      set({ likedSongs })
      saveGuestLibrary(get().playlists, likedSongs)
      return
    }
    if (liked) {
      await unlikeSong(uid, song.id)
    } else {
      await likeSong(uid, song)
    }
  },
}))
