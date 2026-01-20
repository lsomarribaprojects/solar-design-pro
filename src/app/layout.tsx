import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'SolarDesign Pro - Diseño Fotovoltaico con IA',
  description: 'Plataforma de diseño de sistemas fotovoltaicos con inteligencia artificial y cumplimiento NEC',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="es">
      <body className="antialiased">{children}</body>
    </html>
  )
}
