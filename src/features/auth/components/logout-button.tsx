'use client'

import { logout } from '../services/auth-service'

interface LogoutButtonProps {
  className?: string
}

export function LogoutButton({ className }: LogoutButtonProps) {
  return (
    <form action={logout}>
      <button
        type="submit"
        className={className || 'text-gray-600 hover:text-gray-900'}
      >
        Cerrar sesión
      </button>
    </form>
  )
}
