// src/stores/authStore.js
import { create } from 'zustand'
import {
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signInWithPopup,
  signOut,
  sendPasswordResetEmail,
  updateProfile,
  deleteUser,
  onAuthStateChanged,
} from 'firebase/auth'
import { auth, googleProvider } from '../firebase'
import { deleteUserData } from '../services/firestoreService'

const friendlyMessage = (code) => {
  const map = {
    'auth/user-not-found': 'No account found with that email address.',
    'auth/wrong-password': 'Incorrect email or password.',
    'auth/invalid-credential': 'Incorrect email or password.',
    'auth/email-already-in-use': 'An account with that email already exists.',
    'auth/weak-password': 'Password must be at least 6 characters.',
    'auth/invalid-email': 'Please enter a valid email address.',
    'auth/too-many-requests': 'Too many attempts. Please wait and try again.',
    'auth/network-request-failed': 'No internet connection.',
    'auth/user-disabled': 'This account has been disabled.',
  }
  return map[code] || 'Authentication failed. Please try again.'
}

export const useAuthStore = create((set, get) => ({
  user: null,
  loading: true,
  error: null,

  // Called once from main.jsx to subscribe to auth state
  init() {
    return onAuthStateChanged(auth, (user) => {
      set({ user, loading: false })
    })
  },

  async signInWithEmail(email, password) {
    set({ error: null })
    try {
      await signInWithEmailAndPassword(auth, email.trim(), password)
    } catch (e) {
      const msg = friendlyMessage(e.code)
      set({ error: msg })
      throw new Error(msg)
    }
  },

  async signUpWithEmail(email, password, displayName) {
    set({ error: null })
    try {
      const cred = await createUserWithEmailAndPassword(auth, email.trim(), password)
      await updateProfile(cred.user, { displayName: displayName.trim() })
    } catch (e) {
      const msg = friendlyMessage(e.code)
      set({ error: msg })
      throw new Error(msg)
    }
  },

  async signInWithGoogle() {
    set({ error: null })
    try {
      await signInWithPopup(auth, googleProvider)
    } catch (e) {
      const msg = friendlyMessage(e.code) || 'Google sign-in failed.'
      set({ error: msg })
      throw new Error(msg)
    }
  },

  async sendPasswordReset(email) {
    set({ error: null })
    try {
      await sendPasswordResetEmail(auth, email.trim())
    } catch (e) {
      const msg = friendlyMessage(e.code)
      set({ error: msg })
      throw new Error(msg)
    }
  },

  async signOut() {
    try {
      await signOut(auth)
    } catch (_) {}
  },

  async deleteAccount() {
    const user = auth.currentUser
    if (!user) throw new Error('No user signed in.')
    try {
      await deleteUserData(user.uid)
      await deleteUser(user)
    } catch (e) {
      if (e.code === 'auth/requires-recent-login') {
        throw new Error('Please sign out and sign back in before deleting your account.')
      }
      throw e
    }
  },

  clearError() { set({ error: null }) },
}))
