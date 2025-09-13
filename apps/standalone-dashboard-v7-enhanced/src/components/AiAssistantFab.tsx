import React, { useState, useRef, useEffect } from 'react';
import { useFilterBus } from '@/state/filterBus';

export interface QuickSpec {
  schema: 'QuickSpec@1';
  x?: string;
  y?: string;
  series?: string;
  agg: 'sum' | 'count' | 'avg' | 'min' | 'max';
  splitBy?: string;
  chart: 'line' | 'bar' | 'stacked_bar' | 'pie' | 'scatter' | 'heatmap' | 'table';
  filters?: Record<string, any>;
  timeGrain?: 'hour' | 'day' | 'week' | 'month' | 'quarter' | 'year';
  normalize?: 'none' | 'share_category' | 'share_geo' | 'index_100';
  topK?: number;
}

export interface ChartResponse {
  spec: QuickSpec;
  sql: string;
  explain: string;
  sample?: any[];
}

interface Message {
  role: 'user' | 'assistant' | 'system';
  content: string | ChartResponse;
  timestamp: number;
}

export default function AiAssistantFab() {
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [input, setInput] = useState('');
  const [messages, setMessages] = useState<Message[]>([
    {
      role: 'system',
      content: 'Hello! I can help you create custom charts and analyze your Scout data. Try asking for things like:\n\n• "Show brand performance in NCR last 28 days"\n• "Compare Alaska vs Oishi market share"\n• "Top categories by region this month"',
      timestamp: Date.now()
    }
  ]);
  
  const { filters } = useFilterBus();
  const messagesEndRef = useRef<HTMLDivElement>(null);
  
  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };
  
  useEffect(() => {
    scrollToBottom();
  }, [messages]);
  
  // Handle keyboard shortcuts
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === '/' && !open) {
        e.preventDefault();
        setOpen(true);
      } else if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault();
        setOpen(true);
      } else if (e.key === 'Escape' && open) {
        setOpen(false);
      }
    };
    
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [open]);
  
  const askLLM = async (prompt: string) => {
    setLoading(true);
    
    // Add user message
    const userMessage: Message = {
      role: 'user',
      content: prompt,
      timestamp: Date.now()
    };
    setMessages(prev => [...prev, userMessage]);
    
    try {
      const response = await fetch('/api/adhoc/chart', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          prompt, 
          filters,
          context: {
            currentPage: window.location.pathname,
            activeFilters: Object.keys(filters).filter(k => filters[k] != null)
          }
        })
      });
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      
      const chartResponse: ChartResponse = await response.json();
      
      // Add assistant response
      const assistantMessage: Message = {
        role: 'assistant',
        content: chartResponse,
        timestamp: Date.now()
      };
      setMessages(prev => [...prev, assistantMessage]);
      
      // Dispatch event to render chart
      window.dispatchEvent(
        new CustomEvent('adhoc:chart', { 
          detail: { 
            spec: chartResponse.spec,
            sql: chartResponse.sql,
            explain: chartResponse.explain
          }
        })
      );
      
    } catch (error) {
      console.error('AI Assistant error:', error);
      
      const errorMessage: Message = {
        role: 'assistant',
        content: `Sorry, I encountered an error: ${error.message}. Please try rephrasing your question or check your connection.`,
        timestamp: Date.now()
      };
      setMessages(prev => [...prev, errorMessage]);
    } finally {
      setLoading(false);
    }
  };
  
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!input.trim() || loading) return;
    
    const prompt = input.trim();
    setInput('');
    askLLM(prompt);
  };
  
  const renderMessage = (message: Message) => {
    if (typeof message.content === 'string') {
      return (
        <div className="whitespace-pre-wrap text-sm leading-relaxed">
          {message.content}
        </div>
      );
    }
    
    // ChartResponse
    const response = message.content as ChartResponse;
    return (
      <div className="space-y-3">
        <div className="text-sm text-gray-600 bg-gray-50 p-3 rounded">
          {response.explain}
        </div>
        
        <div className="bg-blue-50 p-3 rounded border-l-4 border-blue-400">
          <div className="text-xs font-semibold text-blue-800 mb-2">Generated Chart</div>
          <div className="text-sm text-blue-700">
            <div>Chart: {response.spec.chart}</div>
            {response.spec.x && <div>X-axis: {response.spec.x}</div>}
            {response.spec.y && <div>Y-axis: {response.spec.y}</div>}
            {response.spec.agg && <div>Aggregation: {response.spec.agg}</div>}
            {response.spec.topK && <div>Top K: {response.spec.topK}</div>}
          </div>
        </div>
        
        <details className="text-xs">
          <summary className="cursor-pointer text-gray-500 hover:text-gray-700">
            View SQL Query
          </summary>
          <pre className="mt-2 p-2 bg-gray-100 rounded text-xs overflow-x-auto">
            {response.sql}
          </pre>
        </details>
      </div>
    );
  };
  
  return (
    <>
      {/* Floating Action Button */}
      <button
        onClick={() => setOpen(true)}
        className="fixed bottom-6 right-6 w-14 h-14 bg-blue-600 hover:bg-blue-700 text-white rounded-full shadow-lg transition-all duration-200 flex items-center justify-center z-50 group"
        title="AI Assistant (Press / or Cmd+K)"
      >
        <div className="text-2xl">🤖</div>
        
        {/* Pulse animation when available */}
        <div className="absolute inset-0 bg-blue-400 rounded-full animate-ping opacity-25 group-hover:opacity-0"></div>
      </button>
      
      {/* Chat Panel */}
      {open && (
        <div className="fixed bottom-24 right-6 w-[420px] h-[500px] bg-white shadow-2xl rounded-lg border flex flex-col z-50">
          {/* Header */}
          <div className="flex items-center justify-between p-4 border-b bg-gray-50 rounded-t-lg">
            <div className="flex items-center space-x-2">
              <span className="text-lg">🤖</span>
              <div>
                <h3 className="font-semibold text-gray-800">AI Assistant</h3>
                <p className="text-xs text-gray-500">Ask me about your Scout data</p>
              </div>
            </div>
            <button
              onClick={() => setOpen(false)}
              className="text-gray-400 hover:text-gray-600 text-xl leading-none"
            >
              ✕
            </button>
          </div>
          
          {/* Messages */}
          <div className="flex-1 overflow-y-auto p-4 space-y-4">
            {messages.map((message, i) => (
              <div
                key={i}
                className={`flex ${message.role === 'user' ? 'justify-end' : 'justify-start'}`}
              >
                <div
                  className={`max-w-[85%] p-3 rounded-lg ${
                    message.role === 'user'
                      ? 'bg-blue-600 text-white'
                      : message.role === 'system'
                      ? 'bg-gray-100 text-gray-800'
                      : 'bg-gray-50 text-gray-800'
                  }`}
                >
                  {renderMessage(message)}
                </div>
              </div>
            ))}
            
            {loading && (
              <div className="flex justify-start">
                <div className="bg-gray-100 p-3 rounded-lg">
                  <div className="flex items-center space-x-2">
                    <div className="animate-spin w-4 h-4 border-2 border-blue-500 border-t-transparent rounded-full"></div>
                    <span className="text-sm text-gray-600">Analyzing your request...</span>
                  </div>
                </div>
              </div>
            )}
            
            <div ref={messagesEndRef} />
          </div>
          
          {/* Input Form */}
          <form onSubmit={handleSubmit} className="p-4 border-t bg-gray-50 rounded-b-lg">
            <div className="flex space-x-2">
              <input
                type="text"
                value={input}
                onChange={(e) => setInput(e.target.value)}
                placeholder="Ask for a chart... e.g., 'brand performance in NCR last 28d'"
                className="flex-1 px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                disabled={loading}
              />
              <button
                type="submit"
                disabled={loading || !input.trim()}
                className="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Send
              </button>
            </div>
            
            <div className="mt-2 text-xs text-gray-500">
              Press <kbd className="px-1 bg-gray-200 rounded">Escape</kbd> to close, 
              <kbd className="px-1 bg-gray-200 rounded">/</kbd> or 
              <kbd className="px-1 bg-gray-200 rounded">Cmd+K</kbd> to open
            </div>
          </form>
        </div>
      )}
    </>
  );
}