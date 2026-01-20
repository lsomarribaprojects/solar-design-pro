import type { User, Session } from '@supabase/supabase-js'

export interface AuthState {
  user: User | null
  session: Session | null
  loading: boolean
  error: string | null
}

export interface LoginCredentials {
  email: string
  password: string
}

export interface SignupCredentials {
  email: string
  password: string
  fullName: string
  company?: string
}

export interface Profile {
  id: string
  email: string
  full_name: string | null
  company: string | null
  role: 'free' | 'pro' | 'enterprise'
  avatar_url: string | null
  created_at: string
  updated_at: string
}

export interface AuthResponse {
  success: boolean
  error?: string
  user?: User
}
