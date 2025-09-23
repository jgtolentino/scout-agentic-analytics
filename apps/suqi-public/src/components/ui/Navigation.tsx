'use client'

import React, { useState } from 'react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import {
  BarChart3,
  TrendingUp,
  Users,
  Package,
  MapPin,
  Target,
  Filter,
  Download,
  Search,
  Menu,
  X,
  MessageCircle
} from 'lucide-react'

const Navigation: React.FC = () => {
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false)
  const pathname = usePathname()

  const navigationItems = [
    {
      name: 'Consumer Behavior',
      href: '/consumer-behavior',
      icon: Users,
      description: 'Purchase decisions & signals',
      active: pathname === '/consumer-behavior'
    },
    {
      name: 'Transaction Trends',
      href: '/transaction-trends',
      icon: TrendingUp,
      description: 'Volume, timing & patterns',
      active: pathname === '/transaction-trends'
    },
    {
      name: 'Product Mix & SKU',
      href: '/product-mix',
      icon: Package,
      description: 'Categories, brands & combos',
      active: pathname === '/product-mix'
    },
    {
      name: 'Consumer Profiling',
      href: '/consumer-profiling',
      icon: Target,
      description: 'Demographics & location',
      active: pathname === '/consumer-profiling'
    },
    {
      name: 'Competitive Analysis',
      href: '/competitive-analysis',
      icon: BarChart3,
      description: 'Brand vs brand comparisons',
      active: pathname === '/competitive-analysis'
    },
    {
      name: 'Geographical Intelligence',
      href: '/geographical-intelligence',
      icon: MapPin,
      description: 'Location & regional insights',
      active: pathname === '/geographical-intelligence'
    }
  ]

  return (
    <>
      {/* Desktop Navigation */}
      <div className="hidden lg:flex lg:w-64 lg:flex-col lg:fixed lg:inset-y-0">
        <div className="flex flex-col flex-grow bg-white border-r border-gray-200 pt-5 pb-4 overflow-y-auto">

          {/* Logo/Header */}
          <div className="flex items-center flex-shrink-0 px-6 mb-8">
            <div className="flex items-center space-x-3">
              <div className="w-8 h-8 bg-gradient-to-br from-blue-500 to-purple-600 rounded-lg flex items-center justify-center">
                <BarChart3 className="w-5 h-5 text-white" />
              </div>
              <div>
                <h1 className="text-xl font-bold text-gray-900">Suqi Analytics</h1>
                <p className="text-xs text-gray-500">Retail Intelligence</p>
              </div>
            </div>
          </div>

          {/* Navigation Items */}
          <nav className="flex-1 px-3 space-y-2">
            {navigationItems.map((item) => {
              const Icon = item.icon
              return (
                <Link
                  key={item.name}
                  href={item.href}
                  className={`
                    group flex items-start p-3 text-sm font-medium rounded-lg transition-colors
                    ${item.active
                      ? 'bg-blue-50 text-blue-700 border-r-2 border-blue-600'
                      : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'
                    }
                  `}
                >
                  <Icon
                    className={`
                      flex-shrink-0 w-5 h-5 mr-3 mt-0.5
                      ${item.active ? 'text-blue-600' : 'text-gray-400 group-hover:text-gray-500'}
                    `}
                  />
                  <div>
                    <div className="font-medium">{item.name}</div>
                    <div className="text-xs text-gray-500 mt-0.5">{item.description}</div>
                  </div>
                </Link>
              )
            })}
          </nav>

          {/* Bottom Actions */}
          <div className="flex-shrink-0 px-3 pb-4 space-y-2">
            <button className="w-full flex items-center justify-center px-4 py-2 text-sm font-medium text-white bg-gradient-to-r from-blue-500 to-purple-600 rounded-lg hover:from-blue-600 hover:to-purple-700 transition-colors">
              <MessageCircle className="w-4 h-4 mr-2" />
              Ask Suqi
            </button>

            <button className="w-full flex items-center justify-center px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200 transition-colors">
              <Download className="w-4 h-4 mr-2" />
              Export
            </button>
          </div>

          {/* Data Source Info */}
          <div className="flex-shrink-0 px-6 py-4 border-t border-gray-200">
            <div className="text-xs text-gray-500">
              <div className="font-medium text-gray-700 mb-1">Data Source</div>
              <div>Scout v7 Transactions</div>
              <div>NCR Metro Manila</div>
              <div className="mt-2 flex items-center space-x-2">
                <div className="w-2 h-2 bg-green-400 rounded-full"></div>
                <span>Live Data</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Mobile Navigation */}
      <div className="lg:hidden">
        {/* Mobile header */}
        <div className="flex items-center justify-between h-16 px-4 bg-white border-b border-gray-200">
          <div className="flex items-center space-x-3">
            <div className="w-8 h-8 bg-gradient-to-br from-blue-500 to-purple-600 rounded-lg flex items-center justify-center">
              <BarChart3 className="w-5 h-5 text-white" />
            </div>
            <div>
              <h1 className="text-lg font-bold text-gray-900">Suqi Analytics</h1>
            </div>
          </div>

          <button
            onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
            className="p-2 rounded-md text-gray-600 hover:text-gray-900 hover:bg-gray-100"
          >
            {isMobileMenuOpen ? (
              <X className="w-6 h-6" />
            ) : (
              <Menu className="w-6 h-6" />
            )}
          </button>
        </div>

        {/* Mobile menu overlay */}
        {isMobileMenuOpen && (
          <div className="fixed inset-0 z-50 lg:hidden">
            <div className="fixed inset-0 bg-black bg-opacity-25" onClick={() => setIsMobileMenuOpen(false)} />

            <div className="relative flex flex-col w-full max-w-xs ml-auto h-full bg-white shadow-xl">
              <div className="flex items-center justify-between h-16 px-4 border-b border-gray-200">
                <h2 className="text-lg font-medium text-gray-900">Navigation</h2>
                <button
                  onClick={() => setIsMobileMenuOpen(false)}
                  className="p-2 rounded-md text-gray-600 hover:text-gray-900"
                >
                  <X className="w-6 h-6" />
                </button>
              </div>

              <nav className="flex-1 px-4 py-4 space-y-2 overflow-y-auto">
                {navigationItems.map((item) => {
                  const Icon = item.icon
                  return (
                    <Link
                      key={item.name}
                      href={item.href}
                      onClick={() => setIsMobileMenuOpen(false)}
                      className={`
                        flex items-start p-3 text-sm font-medium rounded-lg transition-colors
                        ${item.active
                          ? 'bg-blue-50 text-blue-700'
                          : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'
                        }
                      `}
                    >
                      <Icon className="flex-shrink-0 w-5 h-5 mr-3 mt-0.5" />
                      <div>
                        <div className="font-medium">{item.name}</div>
                        <div className="text-xs text-gray-500 mt-0.5">{item.description}</div>
                      </div>
                    </Link>
                  )
                })}
              </nav>

              <div className="px-4 py-4 border-t border-gray-200 space-y-2">
                <button className="w-full flex items-center justify-center px-4 py-2 text-sm font-medium text-white bg-gradient-to-r from-blue-500 to-purple-600 rounded-lg">
                  <MessageCircle className="w-4 h-4 mr-2" />
                  Ask Suqi
                </button>

                <button className="w-full flex items-center justify-center px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 rounded-lg">
                  <Download className="w-4 h-4 mr-2" />
                  Export
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </>
  )
}

export default Navigation