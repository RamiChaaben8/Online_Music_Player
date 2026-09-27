import { useCallback, useEffect, useMemo, useState } from 'react'
import { collection, getDocs } from 'firebase/firestore'
import { ArrowLeft, Check, ChevronLeft, ChevronRight, Copy, Pencil, Plus, RefreshCw, Search, ShieldCheck, Trash2, Users, X } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { db } from '../firebase'
import { useAuthStore } from '../stores/authStore'
import { createAdminManagedProfile, createSignupCode, deleteAdminManagedProfile, updateAdminManagedProfile } from '../services/firestoreService'

const PAGE_SIZE = 50
const showValue = (value) => {
  if (value && typeof value.toDate === 'function') return value.toDate().toLocaleString()
  if (value instanceof Date) return value.toLocaleString()
  return value && typeof value === 'object' ? JSON.stringify(value) : String(value ?? '—')
}

function Detail({ title, data }) {
  const entries = Object.entries(data || {})
  if (!entries.length) return null
  return (
    <section style={{ minWidth: 220 }}>
      <h3 style={{ color: 'var(--color-button)', fontSize: 11, textTransform: 'uppercase', letterSpacing: '.1em' }}>{title}</h3>
      <dl style={{ margin: 0, display: 'grid', gridTemplateColumns: 'minmax(100px, auto) 1fr', gap: '7px 14px', fontSize: 12 }}>
        {entries.map(([key, value]) => <div key={key} style={{ display: 'contents' }}>
          <dt style={{ color: 'var(--color-subtext)' }}>{key}</dt>
          <dd style={{ margin: 0, overflowWrap: 'anywhere' }}>{showValue(value)}</dd>
        </div>)}
      </dl>
    </section>
  )
}

function ProfileEditor({ profile, onClose, onSave }) {
  const [form, setForm] = useState({
    uid: profile?.uid || '',
    username: profile?.username || '',
    displayName: profile?.displayName || '',
    photoURL: profile?.photoURL || '',
    privacy: {
      showOnlineStatus: profile?.privacy?.showOnlineStatus ?? true,
      showActivity: profile?.privacy?.showActivity ?? true,
      allowFriendRequests: profile?.privacy?.allowFriendRequests ?? true,
    },
  })
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')

  const fieldStyle = { width: '100%', boxSizing: 'border-box', padding: '10px 12px', color: 'var(--color-text)', background: 'var(--color-highlight)', border: '1px solid var(--color-highlight-elevated)', borderRadius: 7 }
  const updateField = (key, value) => setForm((current) => ({ ...current, [key]: value }))
  const togglePrivacy = (key) => setForm((current) => ({ ...current, privacy: { ...current.privacy, [key]: !current.privacy[key] } }))

  const submit = async (event) => {
    event.preventDefault()
    setError('')
    setSaving(true)
    try {
      await onSave(form)
      onClose()
    } catch (e) {
      setError(e.message || 'Could not save this profile.')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div role="presentation" onMouseDown={(event) => event.target === event.currentTarget && !saving && onClose()} style={{ position: 'fixed', inset: 0, zIndex: 1000, display: 'grid', placeItems: 'center', padding: 18, background: 'rgba(0,0,0,.72)' }}>
      <form onSubmit={submit} role="dialog" aria-modal="true" aria-labelledby="profile-editor-title" style={{ width: 'min(100%, 520px)', maxHeight: '90vh', overflow: 'auto', padding: 24, color: 'var(--color-text)', background: 'var(--color-card)', border: '1px solid var(--color-highlight-elevated)', borderRadius: 14, boxSizing: 'border-box' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}><h2 id="profile-editor-title" style={{ margin: 0, fontSize: 19 }}>{profile ? 'Edit Utify profile' : 'Create Utify profile'}</h2><button type="button" onClick={onClose} disabled={saving} aria-label="Close" style={{ ...buttonStyle, padding: 7 }}><X size={17} /></button></div>
        {!profile && <label style={labelStyle}>User ID<input required value={form.uid} onChange={(e) => updateField('uid', e.target.value)} style={{ ...fieldStyle, marginTop: 6 }} placeholder="Firebase UID for this profile" /></label>}
        <label style={labelStyle}>Username<input required minLength={3} maxLength={20} pattern="[a-zA-Z0-9_]{3,20}" value={form.username} onChange={(e) => updateField('username', e.target.value)} style={{ ...fieldStyle, marginTop: 6 }} /></label>
        <label style={labelStyle}>Display name<input value={form.displayName} onChange={(e) => updateField('displayName', e.target.value)} style={{ ...fieldStyle, marginTop: 6 }} /></label>
        <label style={labelStyle}>Photo URL<input type="url" value={form.photoURL} onChange={(e) => updateField('photoURL', e.target.value)} style={{ ...fieldStyle, marginTop: 6 }} /></label>
        <fieldset style={{ margin: '18px 0', padding: 14, border: '1px solid var(--color-highlight-elevated)', borderRadius: 8 }}><legend style={{ color: 'var(--color-subtext)', fontSize: 12 }}>Profile privacy</legend>
          {[
            ['showOnlineStatus', 'Show online status'],
            ['showActivity', 'Show listening activity'],
            ['allowFriendRequests', 'Allow friend requests'],
          ].map(([key, label]) => <label key={key} style={{ display: 'flex', gap: 9, alignItems: 'center', padding: '5px 0', color: 'var(--color-text)', fontSize: 13 }}><input type="checkbox" checked={form.privacy[key]} onChange={() => togglePrivacy(key)} />{label}</label>)}
        </fieldset>
        {error && <div role="alert" style={{ color: 'var(--color-error)', fontSize: 13, marginBottom: 14 }}>{error}</div>}
        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 9 }}><button type="button" disabled={saving} onClick={onClose} style={buttonStyle}>Cancel</button><button type="submit" disabled={saving} style={{ ...buttonStyle, background: 'var(--color-button)', color: '#fff' }}>{saving ? 'Saving…' : 'Save profile'}</button></div>
      </form>
    </div>
  )
}

const labelStyle = { display: 'block', margin: '14px 0', color: 'var(--color-subtext)', fontSize: 12, fontWeight: 600 }

export default function AdminDashboard() {
  const navigate = useNavigate()
  const signOut = useAuthStore((s) => s.signOut)
  const adminUser = useAuthStore((s) => s.user)
  const [users, setUsers] = useState([])
  const [page, setPage] = useState(0)
  const [query, setQuery] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [editingProfile, setEditingProfile] = useState(undefined)
  const [actionMessage, setActionMessage] = useState('')
  const [signupCode, setSignupCode] = useState('')
  const [creatingCode, setCreatingCode] = useState(false)
  const [copiedCode, setCopiedCode] = useState(false)

  const loadProfiles = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const snapshot = await getDocs(collection(db, 'publicProfiles'))
      const profiles = snapshot.docs.map((profileDoc) => ({ uid: profileDoc.id, ...profileDoc.data() }))
      profiles.sort((a, b) => String(a.username || '').localeCompare(String(b.username || '')))
      setUsers(profiles)
    } catch (e) {
      setUsers([])
      setError(`${e.code ? `${e.code}: ` : ''}${e.message || 'Could not load Utify profiles.'}`)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { loadProfiles() }, [loadProfiles])

  const filteredUsers = useMemo(() => {
    const term = query.trim().toLowerCase()
    if (!term) return users
    return users.filter((user) => [user.displayName, user.username, user.uid]
      .some((value) => String(value || '').toLowerCase().includes(term)))
  }, [query, users])

  const pageCount = Math.max(1, Math.ceil(filteredUsers.length / PAGE_SIZE))
  const pageUsers = filteredUsers.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE)

  const saveProfile = async (form) => {
    if (editingProfile) {
      await updateAdminManagedProfile(editingProfile.uid, form)
      setActionMessage(`Updated @${form.username}.`)
    } else {
      await createAdminManagedProfile(form)
      setActionMessage(`Created @${form.username}.`)
    }
    await loadProfiles()
  }

  const removeProfile = async (profile) => {
    if (!window.confirm(`Delete the Utify profile @${profile.username}? This does not delete its Firebase Authentication account.`)) return
    setActionMessage('')
    setError('')
    try {
      await deleteAdminManagedProfile(profile.uid)
      setActionMessage(`Deleted @${profile.username}.`)
      await loadProfiles()
    } catch (e) {
      setError(`${e.code ? `${e.code}: ` : ''}${e.message || 'Could not delete profile.'}`)
    }
  }

  const addSignupCode = async () => {
    setCreatingCode(true)
    setError('')
    setActionMessage('')
    setSignupCode('')
    setCopiedCode(false)
    try {
      setSignupCode(await createSignupCode(adminUser?.uid))
    } catch (e) {
      setError(`${e.code ? `${e.code}: ` : ''}${e.message || 'Could not create a signup code.'}`)
    } finally {
      setCreatingCode(false)
    }
  }

  const copySignupCode = async () => {
    try {
      await navigator.clipboard.writeText(signupCode)
      setCopiedCode(true)
    } catch {
      setError('Clipboard access failed. Select and copy the code manually.')
    }
  }

  const pageStyle = { minHeight: '100vh', background: 'var(--color-main)', color: 'var(--color-text)', padding: '32px clamp(18px, 5vw, 72px)', boxSizing: 'border-box', fontFamily: 'inherit' }
  const cardStyle = { background: 'var(--color-card)', border: '1px solid var(--color-highlight)', borderRadius: 14 }

  return (
    <main style={pageStyle}>
      <header style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 18, maxWidth: 1440, margin: '0 auto 38px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <div style={{ width: 44, height: 44, borderRadius: 12, display: 'grid', placeItems: 'center', background: 'var(--color-tab-active)', color: 'var(--color-button)' }}><ShieldCheck size={24} /></div>
          <div><div style={{ fontSize: 12, color: 'var(--color-subtext)' }}>UTIFY CONTROL CENTER</div><div style={{ fontWeight: 750, fontSize: 22 }}>Admin dashboard</div></div>
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          <button onClick={() => navigate('/')} style={buttonStyle}><ArrowLeft size={16} /> Music app</button>
          <button onClick={async () => { await signOut(); navigate('/login') }} style={buttonStyle}>Sign out</button>
        </div>
      </header>

      <div style={{ maxWidth: 1440, margin: 'auto' }}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(210px, 1fr))', gap: 16, marginBottom: 26 }}>
          <div style={{ ...cardStyle, padding: 22 }}><div style={{ color: 'var(--color-subtext)', fontSize: 13 }}>Utify profiles</div><div style={{ display: 'flex', alignItems: 'center', gap: 12, fontSize: 30, fontWeight: 750, marginTop: 12 }}><Users color="var(--color-button)" />{loading || error ? '—' : users.length}</div></div>
          <div style={{ ...cardStyle, padding: 22 }}><div style={{ color: 'var(--color-subtext)', fontSize: 13 }}>With usernames</div><div style={{ fontSize: 30, fontWeight: 750, marginTop: 12 }}>{loading || error ? '—' : users.filter((user) => user.username).length}</div></div>
          <div style={{ ...cardStyle, padding: 22 }}><div style={{ color: 'var(--color-subtext)', fontSize: 13 }}>Listed friends</div><div style={{ fontSize: 30, fontWeight: 750, marginTop: 12 }}>{loading || error ? '—' : users.reduce((total, user) => total + (Number(user.friendCount) || 0), 0)}</div></div>
        </div>

        <section style={{ ...cardStyle, overflow: 'hidden' }}>
          <div style={{ padding: 20, borderBottom: '1px solid var(--color-highlight)', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 14 }}>
            <div><h1 style={{ margin: 0, fontSize: 18 }}>User profiles</h1><p style={{ margin: '5px 0 0', color: 'var(--color-subtext)', fontSize: 13 }}>Utify profile details available in Firestore</p></div>
            <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 10 }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: 9, border: '1px solid var(--color-highlight-elevated)', borderRadius: 8, padding: '9px 12px', minWidth: 240 }}><Search size={16} color="var(--color-subtext)" /><input value={query} onChange={(e) => { setQuery(e.target.value); setPage(0) }} placeholder="Search name, username, UID" style={{ color: 'var(--color-text)', background: 'transparent', border: 0, outline: 0, width: '100%' }} /></label>
              <button type="button" onClick={loadProfiles} disabled={loading} style={buttonStyle}><RefreshCw size={15} />Refresh</button>
              <button type="button" onClick={() => { setActionMessage(''); setEditingProfile(null) }} style={{ ...buttonStyle, background: 'var(--color-button)', color: '#fff' }}><Plus size={16} />Create profile</button>
              <button type="button" onClick={addSignupCode} disabled={creatingCode} style={buttonStyle}><Plus size={16} />{creatingCode ? 'Creating code…' : 'Create signup code'}</button>
            </div>
          </div>

          <div style={{ margin: '16px 18px', padding: 13, color: 'var(--color-subtext)', background: 'var(--color-main)', borderRadius: 8, fontSize: 12, lineHeight: 1.55 }}>Free plan directory: this lists profiles already stored in Utify. Firebase Auth accounts without a public Utify profile, plus email verification and sign-in metadata, aren’t available in this view.</div>
          {signupCode && <div role="status" style={{ margin: 18, padding: 16, color: 'var(--color-text)', background: 'var(--color-main)', border: '1px solid var(--color-highlight-elevated)', borderRadius: 8 }}><div style={{ fontSize: 13, marginBottom: 9 }}>Signup code created. Copy it now; it won’t be shown again after leaving this page.</div><div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 10 }}><code style={{ fontSize: 16, letterSpacing: '.08em', overflowWrap: 'anywhere' }}>{signupCode}</code><button type="button" onClick={copySignupCode} style={buttonStyle}>{copiedCode ? <Check size={15} /> : <Copy size={15} />}{copiedCode ? 'Copied' : 'Copy code'}</button></div></div>}
          {actionMessage && <div role="status" style={{ margin: 18, padding: 12, color: 'var(--color-button)', background: 'var(--color-main)', borderRadius: 8, fontSize: 13 }}>{actionMessage}</div>}
          {error && <div role="alert" style={{ margin: 18, padding: 14, color: 'var(--color-error)', background: 'var(--color-main)', borderRadius: 8, lineHeight: 1.6 }}>{error}<button type="button" onClick={loadProfiles} style={{ ...buttonStyle, marginLeft: 12 }}>Retry</button></div>}
          {loading ? <div style={{ padding: 36, color: 'var(--color-subtext)' }}>Loading Utify profiles…</div> : !filteredUsers.length ? <div style={{ padding: 36, color: 'var(--color-subtext)' }}>{query ? 'No profiles match this search.' : 'No public Utify profiles are stored yet.'}</div> : (
            <div style={{ overflowX: 'auto' }}>
              <table style={{ borderCollapse: 'collapse', width: '100%', minWidth: 800, textAlign: 'left' }}>
                <thead><tr style={{ color: 'var(--color-subtext)', fontSize: 11, textTransform: 'uppercase', letterSpacing: '.07em' }}>{['Profile', 'Username', 'Friends', 'Created', 'Details', 'Actions'].map((label, i) => <th key={i} style={{ padding: '13px 18px', fontWeight: 600 }}>{label}</th>)}</tr></thead>
                <tbody>{pageUsers.map((user) => <tr key={user.uid} style={{ borderTop: '1px solid var(--color-highlight)' }}>
                  <td style={{ padding: '15px 18px' }}><div style={{ fontWeight: 650 }}>{user.displayName || 'Unnamed user'}</div><div style={{ color: 'var(--color-subtext)', fontSize: 12, marginTop: 4 }}>UID: {user.uid}</div></td>
                  <td style={{ padding: '15px 18px', color: 'var(--color-subtext)' }}>{user.username ? `@${user.username}` : '—'}</td>
                  <td style={{ padding: '15px 18px', color: 'var(--color-subtext)' }}>{user.friendCount ?? 0}</td>
                  <td style={{ padding: '15px 18px', color: 'var(--color-subtext)', fontSize: 12 }}>{user.createdAt ? showValue(user.createdAt) : '—'}</td>
                  <td style={{ padding: '15px 18px' }}><details><summary style={{ cursor: 'pointer', color: 'var(--color-button)', fontSize: 12 }}>All details</summary><div style={{ position: 'relative', zIndex: 1, marginTop: 12, padding: 16, borderRadius: 10, background: 'var(--color-main)', display: 'flex', flexWrap: 'wrap', gap: 24, minWidth: 520 }}>
                    <Detail title="Utify profile" data={{ uid: user.uid, ...user }} />
                  </div></details></td>
                  <td style={{ padding: '15px 18px', whiteSpace: 'nowrap' }}>
                    <button type="button" aria-label={`Edit ${user.username}`} title="Edit profile" onClick={() => { setActionMessage(''); setEditingProfile(user) }} style={{ ...buttonStyle, padding: 8, marginRight: 6 }}><Pencil size={15} /></button>
                    <button type="button" aria-label={`Delete ${user.username}`} title="Delete profile" onClick={() => removeProfile(user)} style={{ ...buttonStyle, padding: 8, color: 'var(--color-error)' }}><Trash2 size={15} /></button>
                  </td>
                </tr>)}</tbody>
              </table>
            </div>
          )}

          <footer style={{ padding: 16, borderTop: '1px solid var(--color-highlight)', display: 'flex', alignItems: 'center', justifyContent: 'space-between', color: 'var(--color-subtext)', fontSize: 12 }}>
            <span>{filteredUsers.length ? `${page * PAGE_SIZE + 1}–${Math.min((page + 1) * PAGE_SIZE, filteredUsers.length)} of ${filteredUsers.length} profiles` : '0 profiles'}</span>
            <div style={{ display: 'flex', gap: 8 }}><button disabled={page === 0 || loading} onClick={() => setPage((current) => Math.max(0, current - 1))} style={buttonStyle}><ChevronLeft size={16} />Previous</button><button disabled={page + 1 >= pageCount || loading} onClick={() => setPage((current) => Math.min(pageCount - 1, current + 1))} style={buttonStyle}>Next<ChevronRight size={16} /></button></div>
          </footer>
        </section>
      </div>
      {editingProfile !== undefined && <ProfileEditor profile={editingProfile || null} onClose={() => setEditingProfile(undefined)} onSave={saveProfile} />}
    </main>
  )
}

const buttonStyle = { display: 'inline-flex', alignItems: 'center', gap: 7, padding: '9px 12px', color: 'var(--color-text)', background: 'var(--color-highlight)', border: '1px solid var(--color-highlight-elevated)', borderRadius: 8, cursor: 'pointer', fontSize: 12 }
