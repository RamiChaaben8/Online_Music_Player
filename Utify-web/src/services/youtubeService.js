// src/services/youtubeService.js
// Proxies requests through Vite dev server locally to bypass Firebase Functions.

import {
  searchYouTubeParser,
  getTrendingMusicParser,
  getCaptionTracksParser,
  getCaptionTrackParser
} from './youtubeParser'

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
