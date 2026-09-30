// src/stores/themeStore.js
import { create } from 'zustand'

export const THEMES = [
  { id: 'green',         name: 'Green' },
  { id: 'red',           name: 'Red' },
  { id: 'verdant-night', name: 'Verdant Night' },
]

const STORAGE_KEY = 'utify_theme'

const applyTheme = (id) => {
  document.documentElement.setAttribute('data-theme', id)
  localStorage.setItem(STORAGE_KEY, id)
}

// A theme saved by an older version may no longer exist, so only honour a
// stored id that is still in THEMES. Otherwise fall back to the default.
const storedId = localStorage.getItem(STORAGE_KEY)
const savedTheme = THEMES.some((t) => t.id === storedId) ? storedId : 'green'
applyTheme(savedTheme)

export const useThemeStore = create((set) => ({
  themeId: savedTheme,
  setTheme(id) {
    applyTheme(id)
    set({ themeId: id })
  },
}))
