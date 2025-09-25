export const metadata = {
  title: 'Scout DAL Agent',
  description: 'Data Access Layer Agent for Scout v7 Analytics Platform'
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}