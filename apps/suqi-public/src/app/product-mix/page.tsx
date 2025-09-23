'use client'

import React from 'react'
import { Package, BarChart2, PieChart, ShoppingCart } from 'lucide-react'

const ProductMix: React.FC = () => {
  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="border-b border-gray-200 pb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Product Mix & SKU Analytics</h1>
        <p className="text-gray-600">Product performance and inventory optimization</p>
      </div>

      {/* Coming Soon Message */}
      <div className="bg-teal-50 border border-teal-200 rounded-lg p-8 text-center">
        <Package className="w-16 h-16 text-teal-600 mx-auto mb-4" />
        <h2 className="text-2xl font-bold text-teal-900 mb-2">Coming Soon</h2>
        <p className="text-teal-700 mb-4">
          Advanced product mix analysis with SKU performance tracking, inventory optimization, and product portfolio insights.
        </p>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mt-6">
          <div className="bg-white p-4 rounded-lg border border-teal-200">
            <BarChart2 className="w-8 h-8 text-teal-600 mb-2" />
            <h3 className="font-semibold text-teal-900">SKU Performance</h3>
            <p className="text-sm text-teal-700">Individual product analytics</p>
          </div>
          <div className="bg-white p-4 rounded-lg border border-teal-200">
            <PieChart className="w-8 h-8 text-teal-600 mb-2" />
            <h3 className="font-semibold text-teal-900">Category Analysis</h3>
            <p className="text-sm text-teal-700">Product category performance</p>
          </div>
          <div className="bg-white p-4 rounded-lg border border-teal-200">
            <ShoppingCart className="w-8 h-8 text-teal-600 mb-2" />
            <h3 className="font-semibold text-teal-900">Basket Analysis</h3>
            <p className="text-sm text-teal-700">Cross-sell and bundle insights</p>
          </div>
          <div className="bg-white p-4 rounded-lg border border-teal-200">
            <Package className="w-8 h-8 text-teal-600 mb-2" />
            <h3 className="font-semibold text-teal-900">Inventory Optimization</h3>
            <p className="text-sm text-teal-700">Stock level recommendations</p>
          </div>
        </div>
      </div>
    </div>
  )
}

export default ProductMix