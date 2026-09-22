// src/stores/libraryStore.js
// Mirrors library_provider.dart — playlists + liked songs, synced from Firestore

import { create } from 'zustand'
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

export const useLibraryStore = create((set, get) => ({
  playlists: [],
  likedSongs: [],
  loading: false,
  unsubscribePlaylists: null,
  unsubscribeLikes: null,

  // Subscribe to Firestore real-time updates for current user
  init(uid) {
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

  destroy() {
    const { unsubscribePlaylists, unsubscribeLikes } = get()
    unsubscribePlaylists?.()
    unsubscribeLikes?.()
    set({ playlists: [], likedSongs: [], unsubscribePlaylists: null, unsubscribeLikes: null })
  },

  async createPlaylist(uid, name, description = '') {
    return createPlaylist(uid, { name, description, songs: [], visibility: 'private', pinned: false })
  },

  async updatePlaylist(uid, playlistId, updates) {
    await updatePlaylist(uid, playlistId, updates)
  },

  async deletePlaylist(uid, playlistId) {
    await deletePlaylist(uid, playlistId)
  },

  async addSongToPlaylist(uid, playlistId, song) {
    await addSongToPlaylist(uid, playlistId, song)
  },

  async removeSongFromPlaylist(uid, playlistId, songId) {
    await removeSongFromPlaylist(uid, playlistId, songId)
  },

  async reorderSongs(uid, playlistId, songs) {
    await reorderPlaylistSongs(uid, playlistId, songs)
  },

  isLiked(songId) {
    return get().likedSongs.some((s) => s.id === songId)
  },

  async toggleLike(uid, song) {
    const liked = get().isLiked(song.id)
    if (liked) {
      await unlikeSong(uid, song.id)
    } else {
      await likeSong(uid, song)
    }
  },
}))
