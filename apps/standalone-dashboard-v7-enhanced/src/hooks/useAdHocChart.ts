import { useEffect, useState } from 'react';
import { QuickSpec, ChartResponse } from '@/components/AiAssistantFab';

export interface AdHocPanel {
  id: string;
  spec: QuickSpec;
  sql: string;
  explain: string;
  data?: any[];
  timestamp: number;
  pinned: boolean;
}

export function useAdHocChart() {
  const [panels, setPanels] = useState<AdHocPanel[]>([]);
  const [loading, setLoading] = useState<Record<string, boolean>>({});
  
  // Listen for chart requests from AI assistant
  useEffect(() => {
    function handleAdHocChart(e: CustomEvent<ChartResponse>) {
      const { spec, sql, explain } = e.detail;
      
      const panel: AdHocPanel = {
        id: `adhoc_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        spec,
        sql,
        explain,
        timestamp: Date.now(),
        pinned: false
      };
      
      setPanels(prev => [...prev, panel]);
      
      // Fetch data for the new panel
      fetchPanelData(panel);
    }
    
    window.addEventListener('adhoc:chart', handleAdHocChart as EventListener);
    return () => window.removeEventListener('adhoc:chart', handleAdHocChart as EventListener);
  }, []);
  
  // Auto-cleanup expired panels (30 minutes TTL)
  useEffect(() => {
    const interval = setInterval(() => {
      const now = Date.now();
      const TTL = 30 * 60 * 1000; // 30 minutes
      
      setPanels(prev => prev.filter(panel => 
        panel.pinned || (now - panel.timestamp) < TTL
      ));
    }, 60000); // Check every minute
    
    return () => clearInterval(interval);
  }, []);
  
  async function fetchPanelData(panel: AdHocPanel) {
    setLoading(prev => ({ ...prev, [panel.id]: true }));
    
    try {
      const response = await fetch('/api/adhoc/data', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          sql: panel.sql,
          spec: panel.spec
        })
      });
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      
      const data = await response.json();
      
      setPanels(prev => prev.map(p => 
        p.id === panel.id ? { ...p, data: data.rows } : p
      ));
      
    } catch (error) {
      console.error(`Failed to fetch data for panel ${panel.id}:`, error);
      
      setPanels(prev => prev.map(p => 
        p.id === panel.id 
          ? { ...p, data: [], explain: `${p.explain}\n\nError: ${error.message}` }
          : p
      ));
    } finally {
      setLoading(prev => ({ ...prev, [panel.id]: false }));
    }
  }
  
  function pinPanel(panelId: string) {
    setPanels(prev => prev.map(p => 
      p.id === panelId ? { ...p, pinned: !p.pinned } : p
    ));
  }
  
  function removePanel(panelId: string) {
    setPanels(prev => prev.filter(p => p.id !== panelId));
    setLoading(prev => {
      const { [panelId]: removed, ...rest } = prev;
      return rest;
    });
  }
  
  function refreshPanel(panelId: string) {
    const panel = panels.find(p => p.id === panelId);
    if (panel) {
      fetchPanelData(panel);
    }
  }
  
  return {
    panels,
    loading,
    pinPanel,
    removePanel,
    refreshPanel
  };
}