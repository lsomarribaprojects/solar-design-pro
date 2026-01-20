'use server'

import { createClient } from '@/shared/lib/supabase/server'
import { redirect } from 'next/navigation'
import type { LoginCredentials, SignupCredentials, AuthResponse } from '../types'

export async function login(credentials: LoginCredentials): Promise<AuthResponse> {
  const supabase = await createClient()

  const { data, error } = await supabase.auth.signInWithPassword({
    email: credentials.email,
    password: credentials.password,
  })

  if (error) {
    return { success: false, error: error.message }
  }

  return { success: true, user: data.user }
}

export async function signup(credentials: SignupCredentials): Promise<AuthResponse> {
  const supabase = await createClient()

  const { data, error } = await supabase.auth.signUp({
    email: credentials.email,
    password: credentials.password,
    options: {
      data: {
        full_name: credentials.fullName,
        company: credentials.company || null,
      },
    },
  })

  if (error) {
    return { success: false, error: error.message }
  }

  return { success: true, user: data.user ?? undefined }
}

export async function logout(): Promise<void> {
  const supabase = await createClient()
  await supabase.auth.signOut()
  redirect('/login')
}

export async function getUser() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  return user
}

export async function getProfile() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) return null

  const { data: profile } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', user.id)
    .single()

  return profile
}
