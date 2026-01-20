'use client'

import { useEffect, useState, useCallback } from 'react'
import { createClient } from '@/shared/lib/supabase/client'
import type { User, Session } from '@supabase/supabase-js'
import type { AuthState } from '../types'

export function useAuth() {
  const [state, setState] = useState<AuthState>({
    user: null,
    session: null,
    loading: true,
    error: null,
  })

  const supabase = createClient()

  useEffect(() => {
    // Get initial session
    supabase.auth.getSession().then(({ data: { session } }) => {
      setState(prev => ({
        ...prev,
        session,
        user: session?.user ?? null,
        loading: false,
      }))
    })

    // Listen for auth changes
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setState(prev => ({
        ...prev,
        session,
        user: session?.user ?? null,
        loading: false,
      }))
    })

    return () => subscription.unsubscribe()
  }, [])

  const signOut = useCallback(async () => {
    setState(prev => ({ ...prev, loading: true }))
    const { error } = await supabase.auth.signOut()
    if (error) {
      setState(prev => ({ ...prev, error: error.message, loading: false }))
    }
  }, [])

  return {
    ...state,
    signOut,
    isAuthenticated: !!state.user,
  }
}
