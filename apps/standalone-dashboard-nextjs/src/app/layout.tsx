import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import LayoutClient from "@/components/LayoutClient";
import Providers from "./providers";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
});

export const metadata: Metadata = {
  title: "Scout v7.1 - Analytics Dashboard",
  description: "Agentic Analytics Dashboard with Amazon Challenge Theme",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <head>
        <link 
          rel="stylesheet" 
          href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0-beta3/css/all.min.css"
        />
      </head>
      <body className={`${inter.variable} antialiased`}>
        <Providers>
          <LayoutClient>
            {children}
          </LayoutClient>
        </Providers>
      </body>
    </html>
  );
}
