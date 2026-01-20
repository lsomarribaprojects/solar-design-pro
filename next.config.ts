import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  // MCP server solo en desarrollo local
  ...(process.env.NODE_ENV === 'development' && {
    experimental: {
      mcpServer: true,
    },
  }),
}

export default nextConfig
