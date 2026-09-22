// src/stores/themeStore.js
import { create } from 'zustand'

export const THEMES = [
  { id: 'green',                name: 'Green' },
  { id: 'red',                  name: 'Red' },
  { id: 'dribbblish-white',     name: 'Dribbblish White' },
  { id: 'catppuccin-latte',     name: 'Catppuccin Latte' },
  { id: 'nord',                 name: 'Nord' },
  { id: 'dracula',              name: 'Dracula' },
  { id: 'dreary-bib',           name: 'Dreary BIB' },
  { id: 'dreary-deeper',        name: 'Dreary Deeper' },
  { id: 'gruvbox-material-dark',name: 'Gruvbox Material Dark' },
  { id: 'onepunch-dark',        name: 'Onepunch Dark' },
]

const STORAGE_KEY = 'utify_theme'

const applyTheme = (id) => {
  document.documentElement.setAttribute('data-theme', id)
  localStorage.setItem(STORAGE_KEY, id)
}

const savedTheme = localStorage.getItem(STORAGE_KEY) || 'green'
applyTheme(savedTheme)

export const useThemeStore = create((set) => ({
  themeId: savedTheme,
  setTheme(id) {
    applyTheme(id)
    set({ themeId: id })
  },
}))
