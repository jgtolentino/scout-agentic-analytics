import React, { useState } from 'react'
import { Slider } from '@/components/ui/slider'
import { ColorPicker } from '@/components/ui/color-picker'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'

interface PatternParams {
  spacing: number
  rotation: number
  scale: number
  strokeWidth: number
  opacity: number
}

interface BrandConfig {
  primary_color: string
  secondary_color: string
  accent_color?: string
  font_family?: string
}

interface PatternConfiguratorProps {
  params: PatternParams
  brandConfig: BrandConfig
  templateConfig?: any
  onParamsChange: (params: PatternParams) => void
  onBrandChange: (brand: BrandConfig) => void
}

export const PatternConfigurator: React.FC<PatternConfiguratorProps> = ({
  params,
  brandConfig,
  templateConfig,
  onParamsChange,
  onBrandChange
}) => {
  const handleParamChange = (key: keyof PatternParams, value: number) => {
    onParamsChange({
      ...params,
      [key]: value
    })
  }

  const handleColorChange = (key: keyof BrandConfig, value: string) => {
    onBrandChange({
      ...brandConfig,
      [key]: value
    })
  }

  return (
    <div className="pattern-configurator">
      <Tabs defaultValue="brand" className="w-full">
        <TabsList className="grid w-full grid-cols-3">
          <TabsTrigger value="brand">Brand</TabsTrigger>
          <TabsTrigger value="params">Parameters</TabsTrigger>
          <TabsTrigger value="data">Data</TabsTrigger>
        </TabsList>
        
        <TabsContent value="brand" className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-2">Primary Color</label>
            <ColorPicker
              value={brandConfig.primary_color}
              onChange={(color) => handleColorChange('primary_color', color)}
            />
          </div>
          
          <div>
            <label className="block text-sm font-medium mb-2">Secondary Color</label>
            <ColorPicker
              value={brandConfig.secondary_color}
              onChange={(color) => handleColorChange('secondary_color', color)}
            />
          </div>
          
          <div>
            <label className="block text-sm font-medium mb-2">Accent Color</label>
            <ColorPicker
              value={brandConfig.accent_color || '#FF0000'}
              onChange={(color) => handleColorChange('accent_color', color)}
            />
          </div>
          
          <div>
            <label className="block text-sm font-medium mb-2">Font Family</label>
            <select
              value={brandConfig.font_family || 'Arial'}
              onChange={(e) => handleColorChange('font_family', e.target.value)}
              className="w-full px-3 py-2 border rounded-md"
            >
              <option value="Arial">Arial</option>
              <option value="Helvetica">Helvetica</option>
              <option value="Roboto">Roboto</option>
              <option value="Source Sans Pro">Source Sans Pro</option>
            </select>
          </div>
        </TabsContent>
        
        <TabsContent value="params" className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-2">
              Spacing: {params.spacing}
            </label>
            <Slider
              value={[params.spacing]}
              onValueChange={([value]) => handleParamChange('spacing', value)}
              min={5}
              max={50}
              step={1}
            />
          </div>
          
          <div>
            <label className="block text-sm font-medium mb-2">
              Rotation: {params.rotation}°
            </label>
            <Slider
              value={[params.rotation]}
              onValueChange={([value]) => handleParamChange('rotation', value)}
              min={0}
              max={360}
              step={1}
            />
          </div>
          
          <div>
            <label className="block text-sm font-medium mb-2">
              Scale: {params.scale}x
            </label>
            <Slider
              value={[params.scale]}
              onValueChange={([value]) => handleParamChange('scale', value)}
              min={0.5}
              max={3}
              step={0.1}
            />
          </div>
          
          <div>
            <label className="block text-sm font-medium mb-2">
              Stroke Width: {params.strokeWidth}
            </label>
            <Slider
              value={[params.strokeWidth]}
              onValueChange={([value]) => handleParamChange('strokeWidth', value)}
              min={1}
              max={10}
              step={0.5}
            />
          </div>
          
          <div>
            <label className="block text-sm font-medium mb-2">
              Opacity: {(params.opacity * 100).toFixed(0)}%
            </label>
            <Slider
              value={[params.opacity]}
              onValueChange={([value]) => handleParamChange('opacity', value)}
              min={0.1}
              max={1}
              step={0.05}
            />
          </div>
        </TabsContent>
        
        <TabsContent value="data" className="space-y-4">
          <div className="text-center text-gray-500 py-8">
            <p>Data mapping coming soon</p>
            <p className="text-sm mt-2">Upload CSV or connect to data source</p>
          </div>
        </TabsContent>
      </Tabs>
    </div>
  )
}