// src/services/lyricsService.js
// Fetches lyrics from LRCLIB (https://lrclib.net) — free, no API key required.
// Docs: https://lrclib.net/docs

const LRCLIB_BASE = 'https://lrclib.net/api'

// ── LRC parser ────────────────────────────────────────────────────────────────

/**
 * Parse an LRC-format string into a time-stamped array.
 *
 * LRC format example:
 *   [00:12.34] First line of lyrics
 *   [00:15.00] Second line
 *
 * @param {string} lrcString - Raw LRC text
 * @returns {{ time: number, text: string }[]} Sorted ascending by time (seconds)
 */
export function parseLRC(lrcString) {
  if (!lrcString) return []

  const lines = lrcString.split('\n')
  // Regex matches one or more [mm:ss.xx] or [mm:ss.xxx] timestamps per line
  const timestampRe = /\[(\d{1,3}):(\d{2})\.(\d{2,3})\]/g
  const results = []

  for (const line of lines) {
    // Collect all timestamps on this line
    const timestamps = []
    let match
    // Reset lastIndex for each line
    timestampRe.lastIndex = 0
    while ((match = timestampRe.exec(line)) !== null) {
      const minutes = parseInt(match[1], 10)
      const seconds = parseInt(match[2], 10)
      // Handle both centiseconds (2 digits) and milliseconds (3 digits)
      const frac    = match[3]
      const fractional = frac.length === 3
        ? parseInt(frac, 10) / 1000
        : parseInt(frac, 10) / 100
      timestamps.push(minutes * 60 + seconds + fractional)
    }

    if (!timestamps.length) continue

    // Strip all timestamp tags to get the lyric text
    const text = line.replace(/\[\d{1,3}:\d{2}\.\d{2,3}\]/g, '').trim()

    // A single LRC line can carry multiple timestamps (same lyric repeats)
    for (const time of timestamps) {
      results.push({ time, text })
    }
  }

  // Sort ascending by timestamp
  results.sort((a, b) => a.time - b.time)
  return results
}

// ── Main fetch functions ───────────────────────────────────────────────────────

/**
 * Fetch lyrics by track name + artist + optional duration.
 * LRCLIB uses the duration to disambiguate between versions of the same song.
 *
 * @param {string} title           - Track / song title
 * @param {string} artist          - Artist name
 * @param {number} [durationSeconds] - Track duration in seconds (improves accuracy)
 * @returns {Promise<{
 *   syncedLyrics: string | null,
 *   plainLyrics:  string | null,
 *   parsed:       { time: number, text: string }[],
 * }>}
 */
export async function fetchLyrics(title, artist, durationSeconds) {
  if (!title || !artist) {
    return { syncedLyrics: null, plainLyrics: null, parsed: [] }
  }

  const params = new URLSearchParams({
    track_name:  title,
    artist_name: artist,
  })
  if (durationSeconds != null && durationSeconds > 0) {
    params.set('duration', Math.round(durationSeconds).toString())
  }

  try {
    const res = await fetch(`${LRCLIB_BASE}/get?${params.toString()}`)

    if (res.status === 404) {
      // No lyrics found — not an error, just unavailable
      return { syncedLyrics: null, plainLyrics: null, parsed: [] }
    }

    if (!res.ok) {
      throw new Error(`LRCLIB error: ${res.status} ${res.statusText}`)
    }

    const data = await res.json()

    const syncedLyrics = data.syncedLyrics ?? null
    const plainLyrics  = data.plainLyrics  ?? null
    const parsed       = parseLRC(syncedLyrics ?? '')

    return { syncedLyrics, plainLyrics, parsed }
  } catch (err) {
    console.error('[lyricsService] fetchLyrics failed:', err)
    return { syncedLyrics: null, plainLyrics: null, parsed: [] }
  }
}

/**
 * Fetch lyrics by LRCLIB's internal track ID.
 * Useful when you already have the exact LRCLIB id from a previous search.
 *
 * @param {number|string} id - LRCLIB track ID
 * @returns {Promise<{
 *   syncedLyrics: string | null,
 *   plainLyrics:  string | null,
 *   parsed:       { time: number, text: string }[],
 * }>}
 */
export async function fetchLyricsById(id) {
  if (!id) return { syncedLyrics: null, plainLyrics: null, parsed: [] }

  try {
    const res = await fetch(`${LRCLIB_BASE}/get/${encodeURIComponent(id)}`)

    if (res.status === 404) {
      return { syncedLyrics: null, plainLyrics: null, parsed: [] }
    }

    if (!res.ok) {
      throw new Error(`LRCLIB error: ${res.status} ${res.statusText}`)
    }

    const data = await res.json()

    const syncedLyrics = data.syncedLyrics ?? null
    const plainLyrics  = data.plainLyrics  ?? null
    const parsed       = parseLRC(syncedLyrics ?? '')

    return { syncedLyrics, plainLyrics, parsed }
  } catch (err) {
    console.error('[lyricsService] fetchLyricsById failed:', err)
    return { syncedLyrics: null, plainLyrics: null, parsed: [] }
  }
}

/**
 * Search LRCLIB for lyrics by query string.
 * Returns an array of candidates — the caller can pick the best match.
 *
 * @param {string} query - Free-text search (e.g. "Shape of You Ed Sheeran")
 * @returns {Promise<LRCLibTrack[]>}
 */
export async function searchLyrics(query) {
  if (!query?.trim()) return []

  try {
    const params = new URLSearchParams({ q: query.trim() })
    const res = await fetch(`${LRCLIB_BASE}/search?${params.toString()}`)

    if (!res.ok) {
      throw new Error(`LRCLIB search error: ${res.status} ${res.statusText}`)
    }

    return await res.json() // array of track objects
  } catch (err) {
    console.error('[lyricsService] searchLyrics failed:', err)
    return []
  }
}

/**
 * Convenience: fetch lyrics for a Song object from the player store.
 * Automatically strips common YouTube title noise (e.g. "(Official Video)").
 *
 * @param {{ title: string, channelName: string, durationSeconds: number }} song
 * @returns Same shape as fetchLyrics
 */
export async function fetchLyricsForSong(song) {
  if (!song) return { syncedLyrics: null, plainLyrics: null, parsed: [] }

  const cleanTitle = cleanYouTubeTitle(song.title)
  const artist     = song.channelName ?? ''

  return fetchLyrics(cleanTitle, artist, song.durationSeconds)
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * Strip common YouTube title suffixes that confuse lyrics APIs.
 * e.g. "Shape of You (Official Music Video)" → "Shape of You"
 */
function cleanYouTubeTitle(title = '') {
  return title
    .replace(/\(.*?(official|video|audio|lyric|hd|hq|mv|4k|visualizer).*?\)/gi, '')
    .replace(/\[.*?(official|video|audio|lyric|hd|hq|mv|4k|visualizer).*?\]/gi, '')
    .replace(/【.*?(official|video|audio|lyric|hd|hq|mv|4k|visualizer).*?】/gi, '')
    .replace(/[-|—|–]\s*(official|lyrics?|audio|video|hd|mv).*/gi, '')
    .replace(/\b(MV|Music Video|Official Video|Official Audio)\b/gi, '')
    .replace(/[「」『』]/g, ' ')
    .replace(/\s{2,}/g, ' ')
    .trim()
}

/**
 * @typedef {Object} LRCLibTrack
 * @property {number}      id            - LRCLIB track ID
 * @property {string}      trackName     - Song title
 * @property {string}      artistName    - Artist name
 * @property {string}      albumName     - Album name
 * @property {number}      duration      - Duration in seconds
 * @property {boolean}     instrumental  - True if no vocals
 * @property {string|null} plainLyrics   - Plain text lyrics
 * @property {string|null} syncedLyrics  - LRC-format synced lyrics
 */
