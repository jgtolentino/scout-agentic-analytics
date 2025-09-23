import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Suqi Analytics - Scout Dashboard Transactions',
  description: 'Consumer Behavior Analytics and Retail Intelligence for TBWA Project Scout',
  keywords: 'analytics, retail intelligence, consumer behavior, TBWA, Scout, transactions',
  authors: [{ name: 'Scout Team' }],
  creator: 'TBWA SMP',
  publisher: 'TBWA SMP',
  openGraph: {
    title: 'Suqi Analytics - Scout Dashboard Transactions',
    description: 'Consumer Behavior Analytics and Retail Intelligence',
    type: 'website',
    locale: 'en_US',
  },
  viewport: 'width=device-width, initial-scale=1',
  robots: 'index, follow',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <head>
        <link rel="icon" href="/favicon.ico" />
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link
          href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap"
          rel="stylesheet"
        />
      </head>
      <body className="min-h-screen bg-gray-50 font-sans antialiased">
        <div className="min-h-screen flex flex-col">
          {children}
        </div>
      </body>
    </html>
  )
}