'use client';

import React, { useState, useEffect } from 'react';
import { ENV } from '@/lib/env';

export default function FloatingAssistant() {
  const [isOpen, setIsOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [response, setResponse] = useState('');

  // Keyboard shortcut (Cmd/Ctrl + K)
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault();
        setIsOpen(true);
      }
      if (e.key === 'Escape') {
        setIsOpen(false);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!query.trim()) return;

    setIsLoading(true);
    setResponse('');

    try {
      // Mock AI response for now - replace with actual Edge Function call
      if (ENV.ENABLE_SCOUT_AI) {
        // await callEdgeFunction('agents-orchestrator', { query, context: getCurrentPageContext() });
        // For now, mock response
        await new Promise(resolve => setTimeout(resolve, 1500));
        setResponse(`Based on your current filters and the ${window.location.pathname} page, here's what I found:\n\n• Revenue is up 12% vs last month\n• Top category is ${query.includes('beverage') ? 'Beverages' : 'showing strong performance'}\n• Consider drilling into regional data for deeper insights\n\nWould you like me to generate a specific chart or analysis?`);
      } else {
        setResponse('AI Assistant is not configured. Please check your environment settings.');
      }
    } catch (error) {
      console.error('AI query failed:', error);
      setResponse('Sorry, I encountered an error processing your request. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  if (!ENV.AI_ASSISTANT) return null;

  return (
    <>
      {/* FAB Button */}
      <button
        onClick={() => setIsOpen(true)}
        className="fixed bottom-6 right-6 w-14 h-14 bg-orange-500 hover:bg-orange-600 text-white rounded-full shadow-lg hover:shadow-xl transition-all duration-200 flex items-center justify-center z-50"
        title="AI Assistant (⌘K)"
      >
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z" />
        </svg>
      </button>

      {/* Modal */}
      {isOpen && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg shadow-xl max-w-2xl w-full max-h-[80vh] flex flex-col">
            {/* Header */}
            <div className="flex items-center justify-between p-4 border-b border-gray-200">
              <div>
                <h2 className="text-lg font-semibold text-gray-900">AI Assistant</h2>
                <p className="text-sm text-gray-500">Ask questions about your data</p>
              </div>
              <button
                onClick={() => setIsOpen(false)}
                className="text-gray-400 hover:text-gray-600"
              >
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            {/* Content */}
            <div className="flex-1 overflow-auto p-4">
              {response && (
                <div className="mb-4 p-3 bg-gray-50 rounded-lg">
                  <pre className="whitespace-pre-wrap text-sm text-gray-700 font-sans">
                    {response}
                  </pre>
                </div>
              )}
              
              {isLoading && (
                <div className="flex items-center gap-2 mb-4 text-orange-600">
                  <div className="w-4 h-4 border-2 border-orange-200 border-t-orange-600 rounded-full animate-spin"></div>
                  <span className="text-sm">Analyzing your data...</span>
                </div>
              )}
            </div>

            {/* Footer */}
            <form onSubmit={handleSubmit} className="border-t border-gray-200 p-4">
              <div className="flex gap-2">
                <input
                  type="text"
                  value={query}
                  onChange={(e) => setQuery(e.target.value)}
                  placeholder="Ask about trends, comparisons, insights..."
                  className="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500"
                  disabled={isLoading}
                  autoFocus
                />
                <button
                  type="submit"
                  disabled={isLoading || !query.trim()}
                  className="px-4 py-2 bg-orange-500 text-white rounded-md hover:bg-orange-600 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                  Ask
                </button>
              </div>
              <div className="mt-2 text-xs text-gray-500">
                Try: "Show me beverage trends" or "Compare regions" or "What's driving growth?"
              </div>
            </form>
          </div>
        </div>
      )}
    </>
  );
}