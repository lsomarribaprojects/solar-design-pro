import { SignupForm } from '@/features/auth'

export default function SignupPage() {
  return (
    <div className="flex min-h-screen items-center justify-center">
      <div className="w-full max-w-md space-y-8 p-8">
        <div className="text-center">
          <h1 className="text-3xl font-bold text-gray-900">SolarDesign Pro</h1>
          <p className="mt-2 text-gray-600">Crea tu cuenta gratis</p>
        </div>
        <SignupForm />
      </div>
    </div>
  )
}
