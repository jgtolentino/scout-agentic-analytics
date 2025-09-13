import React, { useState, useEffect } from 'react'
import { supabase } from '@/lib/supabase'

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

interface PatternPreviewProps {
  templateId: string
  params: PatternParams
  brandConfig: BrandConfig
  onUpdate?: (svg: string) => void
}

export const PatternPreview: React.FC<PatternPreviewProps> = ({
  templateId,
  params,
  brandConfig,
  onUpdate
}) => {
  const [svgContent, setSvgContent] = useState<string>('')
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    generatePreview()
  }, [templateId, params, brandConfig])

  const generatePreview = async () => {
    setIsLoading(true)
    setError(null)

    try {
      // Call Edge Function for real-time rendering
      const response = await fetch(
        `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/savage-render`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY}`
          },
          body: JSON.stringify({
            template_id: templateId,
            params,
            brand_config: brandConfig
          })
        }
      )

      if (!response.ok) {
        throw new Error('Failed to generate pattern')
      }

      const svg = await response.text()
      setSvgContent(svg)
      onUpdate?.(svg)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error')
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="pattern-preview">
      <div className="preview-container relative bg-gray-100 rounded-lg overflow-hidden">
        {isLoading && (
          <div className="absolute inset-0 flex items-center justify-center bg-white bg-opacity-75">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
          </div>
        )}
        
        {error && (
          <div className="absolute inset-0 flex items-center justify-center">
            <div className="text-red-500 text-center">
              <p className="font-semibold">Error generating pattern</p>
              <p className="text-sm">{error}</p>
            </div>
          </div>
        )}
        
        {svgContent && !isLoading && (
          <div 
            className="pattern-svg w-full h-full"
            dangerouslySetInnerHTML={{ __html: svgContent }}
          />
        )}
      </div>
      
      <div className="preview-controls mt-4 flex gap-2">
        <button
          onClick={generatePreview}
          disabled={isLoading}
          className="px-4 py-2 bg-primary text-white rounded hover:bg-primary-dark disabled:opacity-50"
        >
          Refresh Preview
        </button>
      </div>
    </div>
  )
}