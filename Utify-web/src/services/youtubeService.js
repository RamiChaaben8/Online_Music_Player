// src/services/youtubeService.js
// Proxies requests through Vite dev server locally to bypass Firebase Functions.

import {
  searchYouTubeParser,
  getTrendingMusicParser,
  getVideoStreamUrlParser,
  getCaptionTracksParser,
  getCaptionTrackParser
} from './youtubeParser'

const streamUrlCache = new Map() // videoId -> { url, mimeType, expiresAt }

// ── searchYouTube ─────────────────────────────────────────────────────────────

export async function searchYouTube(query, pageToken = null) {
  const res = await searchYouTubeParser({ data: { query, pageToken } })
  return res
}

// ── getTrendingMusic ──────────────────────────────────────────────────────────

export async function getTrendingMusic(regionCode = 'US') {
  const res = await getTrendingMusicParser({ data: { regionCode } })
  return res
}

// ── getVideoStreamUrl ─────────────────────────────────────────────────────────

export async function getVideoStreamUrl(videoId) {
  const now = Date.now()
  if (streamUrlCache.has(videoId)) {
    const cached = streamUrlCache.get(videoId)
    if (cached.expiresAt > now + 60_000) return cached
    streamUrlCache.delete(videoId)
  }

  const res = await getVideoStreamUrlParser({ data: { videoId } })
  const result = res
  streamUrlCache.set(videoId, result)
  return result
}

// ── getCaptionTracks ──────────────────────────────────────────────────────────

export async function getCaptionTracks(videoId) {
  const res = await getCaptionTracksParser({ data: { videoId } })
  return res.tracks || []
}

// ── getCaptionTrack ───────────────────────────────────────────────────────────

export async function getCaptionTrack(videoId, languageCode) {
  const res = await getCaptionTrackParser({ data: { videoId, languageCode } })
  return res.lines || []
}
