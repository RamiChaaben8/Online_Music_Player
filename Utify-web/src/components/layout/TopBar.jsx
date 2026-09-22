/**
 * TopBar.jsx
 * Fixed 48-px bar at the top of AppShell.
 *
 * Layout:
 *   [Logo] [←] [→]  ·  [Search input ——————————]  ·  [Avatar ▾]
 *
 * Profile dropdown:
 *   • Profile header (displays email)
 *   • Theme picker (inline sub-select listing all 10 THEMES)
 *   • Settings
 *   • Friends
 *   • ─────────
 *   • Sign Out
 */

import {
  useCallback,
  useEffect,
  useRef,
  useState,
} from 'react'
import { useNavigate } from 'react-router-dom'
import {
  ArrowLeft,
  ArrowRight,
  Check,
  ChevronRight,
  LogOut,
  Music2,
  Palette,
  Search,
  Settings,
  Users,
  X,
} from 'lucide-react'

import { useAuthStore }  from '../../stores/authStore'
import { THEMES, useThemeStore } from '../../stores/themeStore'
import { useNavigationContext }  from './AppShell'

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Returns up-to-2 uppercase initials from a display name or email. */
function getInitials(user) {
  if (!user) return '?'
  const name = user.displayName || user.email || ''
  const parts = name.trim().split(/\s+/)
  if (parts.length >= 2) {
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
  }
  return name.slice(0, 2).toUpperCase()
}

/** Simple deterministic color from a string (for avatar bg when no photo). */
function stringToColor(str = '') {
  let hash = 0
  for (let i = 0; i < str.length; i++) {
    hash = str.charCodeAt(i) + ((hash << 5) - hash)
  }
  const h = Math.abs(hash) % 360
  return `hsl(${h}, 45%, 40%)`
}

// ── Debounce hook ─────────────────────────────────────────────────────────────

function useDebounce(value, delay) {
  const [debounced, setDebounced] = useState(value)
  useEffect(() => {
    const t = setTimeout(() => setDebounced(value), delay)
    return () => clearTimeout(t)
  }, [value, delay])
  return debounced
}

// ── Sub-components ────────────────────────────────────────────────────────────

/** Styled icon button used for back/forward arrows. */
function NavButton({ onClick, disabled, title, children }) {
  const [hovered, setHovered] = useState(false)

  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      title={title}
      aria-label={title}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        display:         'flex',
        alignItems:      'center',
        justifyContent:  'center',
        width:           32,
        height:          32,
        borderRadius:    '50%',
        border:          'none',
        background:      hovered && !disabled
          ? 'var(--color-highlight)'
          : 'rgba(0,0,0,0.3)',
        color:           disabled
          ? 'var(--color-subtext)'
          : 'var(--color-text)',
        cursor:          disabled ? 'not-allowed' : 'pointer',
        opacity:         disabled ? 0.4 : 1,
        transition:      'background 0.15s, opacity 0.15s',
        flexShrink:      0,
      }}
    >
      {children}
    </button>
  )
}

// ── Theme sub-panel (rendered inside dropdown) ────────────────────────────────

function ThemeSubPanel({ onClose }) {
  const { themeId, setTheme } = useThemeStore()

  return (
    <div
      style={{
        position:     'absolute',
        top:          0,
        left:         'calc(100% + 4px)',
        width:        220,
        background:   'var(--color-card)',
        border:       '1px solid var(--color-highlight)',
        borderRadius: 8,
        boxShadow:    '0 8px 24px rgba(0,0,0,0.5)',
        overflow:     'hidden',
        zIndex:       310,
      }}
    >
      {/* Header */}
      <div
        style={{
          display:        'flex',
          alignItems:     'center',
          justifyContent: 'space-between',
          padding:        '10px 14px',
          borderBottom:   '1px solid var(--color-highlight)',
        }}
      >
        <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--color-text)' }}>
          Themes
        </span>
        <button
          type="button"
          onClick={onClose}
          aria-label="Close theme picker"
          style={{
            background: 'none',
            border:     'none',
            color:      'var(--color-subtext)',
            cursor:     'pointer',
            padding:    2,
            display:    'flex',
          }}
        >
          <X size={14} />
        </button>
      </div>

      {/* Theme list */}
      <ul
        role="listbox"
        aria-label="Select theme"
        style={{ listStyle: 'none', margin: 0, padding: '4px 0' }}
      >
        {THEMES.map((theme) => {
          const active = theme.id === themeId
          return (
            <li
              key={theme.id}
              role="option"
              aria-selected={active}
            >
              <button
                type="button"
                onClick={() => {
                  setTheme(theme.id)
                  onClose()
                }}
                style={{
                  width:           '100%',
                  display:         'flex',
                  alignItems:      'center',
                  gap:             10,
                  padding:         '9px 14px',
                  background:      active
                    ? 'var(--color-selected-row)'
                    : 'transparent',
                  border:          'none',
                  color:           'var(--color-text)',
                  cursor:          'pointer',
                  fontSize:        13,
                  textAlign:       'left',
                  transition:      'background 0.12s',
                }}
                onMouseEnter={(e) => {
                  if (!active)
                    e.currentTarget.style.background = 'var(--color-highlight)'
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.background = active
                    ? 'var(--color-selected-row)'
                    : 'transparent'
                }}
              >
                {/* Color swatch */}
                <span
                  aria-hidden="true"
                  data-theme={theme.id}
                  style={{
                    width:        14,
                    height:       14,
                    borderRadius: '50%',
                    flexShrink:   0,
                    border:       '2px solid var(--color-highlight-elevated)',
                    background:   'var(--color-button)',
                  }}
                />
                <span style={{ flexGrow: 1 }}>{theme.name}</span>
                {active && (
                  <Check size={14} style={{ color: 'var(--color-button)' }} />
                )}
              </button>
            </li>
          )
        })}
      </ul>
    </div>
  )
}

// ── Profile dropdown ──────────────────────────────────────────────────────────

function ProfileDropdown({ anchorRef, onClose }) {
  const { user, signOut }     = useAuthStore()
  const navigate              = useNavigate()
  const [showThemes, setShowThemes] = useState(false)
  const dropdownRef           = useRef(null)

  // Close on outside click
  useEffect(() => {
    function handler(e) {
      if (
        dropdownRef.current &&
        !dropdownRef.current.contains(e.target) &&
        anchorRef.current &&
        !anchorRef.current.contains(e.target)
      ) {
        onClose()
      }
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [anchorRef, onClose])

  // Close on Escape
  useEffect(() => {
    function handler(e) {
      if (e.key === 'Escape') onClose()
    }
    document.addEventListener('keydown', handler)
    return () => document.removeEventListener('keydown', handler)
  }, [onClose])

  const handleSignOut = async () => {
    onClose()
    await signOut()
    navigate('/login')
  }

  const menuItemStyle = (extra = {}) => ({
    width:      '100%',
    display:    'flex',
    alignItems: 'center',
    gap:        10,
    padding:    '10px 16px',
    background: 'transparent',
    border:     'none',
    color:      'var(--color-text)',
    cursor:     'pointer',
    fontSize:   14,
    textAlign:  'left',
    transition: 'background 0.12s',
    ...extra,
  })

  const hoverHandlers = (isDestructive = false) => ({
    onMouseEnter: (e) => {
      e.currentTarget.style.background = isDestructive
        ? 'rgba(232,23,58,0.15)'
        : 'var(--color-highlight)'
    },
    onMouseLeave: (e) => {
      e.currentTarget.style.background = 'transparent'
    },
  })

  return (
    <div
      ref={dropdownRef}
      role="menu"
      aria-label="Profile menu"
      style={{
        position:     'absolute',
        top:          'calc(100% + 8px)',
        right:        0,
        width:        240,
        background:   'var(--color-card)',
        border:       '1px solid var(--color-highlight)',
        borderRadius: 8,
        boxShadow:    '0 8px 24px rgba(0,0,0,0.5)',
        zIndex:       300,
        overflow:     'visible',
      }}
    >
      {/* Profile header */}
      <div
        style={{
          padding:      '14px 16px 10px',
          borderBottom: '1px solid var(--color-highlight)',
        }}
      >
        <p
          style={{
            margin:   0,
            fontSize: 13,
            fontWeight: 600,
            color:    'var(--color-text)',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
          }}
        >
          {user?.displayName || 'Utify User'}
        </p>
        <p
          style={{
            margin:   '2px 0 0',
            fontSize: 12,
            color:    'var(--color-subtext)',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace:   'nowrap',
          }}
        >
          {user?.email || ''}
        </p>
      </div>

      {/* Menu items */}
      <div style={{ padding: '4px 0' }}>
        {/* Theme picker — shows sub-panel on hover/click */}
        <div style={{ position: 'relative' }}>
          <button
            type="button"
            role="menuitem"
            aria-haspopup="true"
            aria-expanded={showThemes}
            onClick={() => setShowThemes((v) => !v)}
            style={menuItemStyle({ justifyContent: 'space-between' })}
            {...hoverHandlers()}
          >
            <span style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <Palette size={16} style={{ color: 'var(--color-subtext)' }} />
              Theme
            </span>
            <ChevronRight
              size={14}
              style={{
                color:     'var(--color-subtext)',
                transform: showThemes ? 'rotate(90deg)' : 'none',
                transition: 'transform 0.15s',
              }}
            />
          </button>
          {showThemes && (
            <ThemeSubPanel onClose={() => setShowThemes(false)} />
          )}
        </div>

        {/* Settings */}
        <button
          type="button"
          role="menuitem"
          onClick={() => { navigate('/settings'); onClose() }}
          style={menuItemStyle()}
          {...hoverHandlers()}
        >
          <Settings size={16} style={{ color: 'var(--color-subtext)' }} />
          Settings
        </button>

        {/* Friends */}
        <button
          type="button"
          role="menuitem"
          onClick={() => { navigate('/friends'); onClose() }}
          style={menuItemStyle()}
          {...hoverHandlers()}
        >
          <Users size={16} style={{ color: 'var(--color-subtext)' }} />
          Friends
        </button>
      </div>

      {/* Divider */}
      <div
        style={{
          height:     1,
          background: 'var(--color-highlight)',
          margin:     '2px 0',
        }}
      />

      {/* Sign out */}
      <div style={{ padding: '4px 0 6px' }}>
        <button
          type="button"
          role="menuitem"
          onClick={handleSignOut}
          style={menuItemStyle({ color: 'var(--color-error)' })}
          {...hoverHandlers(true)}
        >
          <LogOut size={16} />
          Sign Out
        </button>
      </div>
    </div>
  )
}

// ── Avatar button ─────────────────────────────────────────────────────────────

function AvatarButton({ onClick, buttonRef }) {
  const { user } = useAuthStore()
  const [hovered, setHovered] = useState(false)

  const initials = getInitials(user)
  const bgColor  = stringToColor(user?.email || user?.uid || '')
  const photoURL = user?.photoURL

  return (
    <button
      ref={buttonRef}
      type="button"
      onClick={onClick}
      aria-label="Open profile menu"
      aria-haspopup="true"
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        display:        'flex',
        alignItems:     'center',
        gap:            8,
        background:     hovered ? 'var(--color-highlight)' : 'transparent',
        border:         'none',
        borderRadius:   24,
        padding:        '4px 8px 4px 4px',
        cursor:         'pointer',
        color:          'var(--color-text)',
        transition:     'background 0.15s',
        flexShrink:     0,
      }}
    >
      {/* Avatar image or initials circle */}
      {photoURL ? (
        <img
          src={photoURL}
          alt={user?.displayName || 'Profile'}
          style={{
            width:        28,
            height:       28,
            borderRadius: '50%',
            objectFit:    'cover',
            flexShrink:   0,
          }}
        />
      ) : (
        <span
          aria-hidden="true"
          style={{
            width:           28,
            height:          28,
            borderRadius:    '50%',
            background:      bgColor,
            color:           '#fff',
            fontSize:        11,
            fontWeight:      700,
            display:         'flex',
            alignItems:      'center',
            justifyContent:  'center',
            flexShrink:      0,
            letterSpacing:   0.5,
          }}
        >
          {initials}
        </span>
      )}

      {/* Display name (hidden on narrow screens via maxWidth trick) */}
      <span
        style={{
          fontSize:   13,
          fontWeight: 600,
          color:      'var(--color-text)',
          maxWidth:   120,
          overflow:   'hidden',
          textOverflow: 'ellipsis',
          whiteSpace:   'nowrap',
        }}
      >
        {user?.displayName || user?.email?.split('@')[0] || 'Account'}
      </span>
    </button>
  )
}

// ── TopBar ────────────────────────────────────────────────────────────────────

export default function TopBar() {
  const navigate          = useNavigate()
  const { canGoBack, canGoForward, goBack, goForward } = useNavigationContext()

  // Search state
  const [searchValue, setSearchValue]     = useState('')
  const [searchFocused, setSearchFocused] = useState(false)
  const debouncedSearch                   = useDebounce(searchValue, 400)
  const searchRef                         = useRef(null)

  // Profile dropdown
  const [dropdownOpen, setDropdownOpen] = useState(false)
  const avatarBtnRef                    = useRef(null)

  // Navigate to /search when debounced value changes (only if non-empty)
  useEffect(() => {
    if (debouncedSearch.trim()) {
      navigate(`/search?q=${encodeURIComponent(debouncedSearch.trim())}`)
    }
  }, [debouncedSearch, navigate])

  const handleSearchClear = useCallback(() => {
    setSearchValue('')
    searchRef.current?.focus()
  }, [])

  const handleSearchKeyDown = useCallback((e) => {
    if (e.key === 'Enter' && searchValue.trim()) {
      navigate(`/search?q=${encodeURIComponent(searchValue.trim())}`)
    }
    if (e.key === 'Escape') {
      setSearchValue('')
      searchRef.current?.blur()
    }
  }, [navigate, searchValue])

  // ── Styles ──────────────────────────────────────────────────────────────

  const barStyle = {
    height:         48,
    minHeight:      48,
    background:     'var(--color-main)',
    borderBottom:   '1px solid var(--color-highlight)',
    display:        'flex',
    alignItems:     'center',
    padding:        '0 16px',
    gap:            12,
    flexShrink:     0,
    zIndex:         50,
    position:       'relative', // for dropdown positioning
  }

  const searchWrapStyle = {
    flexGrow:       1,
    maxWidth:       360,
    position:       'relative',
    display:        'flex',
    alignItems:     'center',
  }

  const searchInputStyle = {
    width:          '100%',
    height:         34,
    background:     searchFocused
      ? 'var(--color-highlight-elevated, var(--color-highlight))'
      : 'var(--color-highlight)',
    border:         searchFocused
      ? '1px solid var(--color-button)'
      : '1px solid transparent',
    borderRadius:   20,
    padding:        '0 32px 0 36px', // room for search icon left, clear btn right
    color:          'var(--color-text)',
    fontSize:       14,
    outline:        'none',
    transition:     'border 0.15s, background 0.15s',
  }

  return (
    <header style={barStyle} role="banner">
      {/* ── Logo ── */}
      <div
        aria-label="Utify"
        style={{
          display:    'flex',
          alignItems: 'center',
          gap:        6,
          flexShrink: 0,
          cursor:     'pointer',
          userSelect: 'none',
        }}
        onClick={() => navigate('/')}
        role="link"
        tabIndex={0}
        onKeyDown={(e) => e.key === 'Enter' && navigate('/')}
      >
        <Music2
          size={22}
          style={{ color: 'var(--color-button)' }}
          aria-hidden="true"
        />
        <span
          style={{
            fontSize:   16,
            fontWeight: 800,
            color:      'var(--color-text)',
            letterSpacing: -0.3,
          }}
        >
          Utify
        </span>
      </div>

      {/* ── Back / Forward ── */}
      <div style={{ display: 'flex', gap: 6, flexShrink: 0 }}>
        <NavButton
          onClick={goBack}
          disabled={!canGoBack}
          title="Go back"
        >
          <ArrowLeft size={16} />
        </NavButton>
        <NavButton
          onClick={goForward}
          disabled={!canGoForward}
          title="Go forward"
        >
          <ArrowRight size={16} />
        </NavButton>
      </div>

      {/* ── Search bar (center, grows) ── */}
      <div style={{ flexGrow: 1, display: 'flex', justifyContent: 'center' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, width: '100%', maxWidth: 400 }}>
          <button
            title="Home"
            aria-label="Home"
            onClick={() => navigate('/')}
            style={{
              background: 'none', border: 'none', cursor: 'pointer',
              color: window.location.pathname === '/' ? 'var(--color-text)' : 'var(--color-subtext)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              padding: 8, borderRadius: '50%',
            }}
            onMouseEnter={(e) => { e.currentTarget.style.background = 'var(--color-highlight)' }}
            onMouseLeave={(e) => { e.currentTarget.style.background = 'none' }}
          >
            <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor">
              <path d="M12 3l-10 9h3v8h14v-8h3z" />
            </svg>
          </button>
          
          <div style={searchWrapStyle}>
            {/* Search icon */}
            <Search
              size={15}
              aria-hidden="true"
              style={{
                position: 'absolute',
                left:     11,
                color:    searchFocused
                  ? 'var(--color-text)'
                  : 'var(--color-subtext)',
                pointerEvents: 'none',
                transition: 'color 0.15s',
              }}
            />

            <input
              ref={searchRef}
              type="search"
              role="searchbox"
              aria-label="Search songs, artists, playlists"
              placeholder="What do you want to play?"
              value={searchValue}
              onChange={(e) => setSearchValue(e.target.value)}
              onFocus={() => setSearchFocused(true)}
              onBlur={() => setSearchFocused(false)}
              onKeyDown={handleSearchKeyDown}
              style={searchInputStyle}
              autoComplete="off"
              spellCheck={false}
            />

            {/* Clear button — only visible when there's input */}
            {searchValue && (
              <button
                type="button"
                aria-label="Clear search"
                onClick={handleSearchClear}
                style={{
                  position:   'absolute',
                  right:      8,
                  background: 'none',
                  border:     'none',
                  color:      'var(--color-subtext)',
                  cursor:     'pointer',
                  display:    'flex',
                  padding:    2,
                  borderRadius: '50%',
                }}
              >
                <X size={14} />
              </button>
            )}
          </div>
        </div>
      </div>

      {/* Spacer pushes avatar to the right */}
      <div style={{ flexGrow: 1 }} />

      {/* ── Profile avatar button + dropdown ── */}
      <div style={{ position: 'relative', flexShrink: 0 }}>
        <AvatarButton
          buttonRef={avatarBtnRef}
          onClick={() => setDropdownOpen((v) => !v)}
        />
        {dropdownOpen && (
          <ProfileDropdown
            anchorRef={avatarBtnRef}
            onClose={() => setDropdownOpen(false)}
          />
        )}
      </div>
    </header>
  )
}
