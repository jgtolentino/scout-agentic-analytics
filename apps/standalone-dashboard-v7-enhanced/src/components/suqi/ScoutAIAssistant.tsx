/**
 * Scout AI Business Intelligence Assistant
 * Provides conversational interface for retail analytics using Scout intelligent router
 */
import React, { useState, useRef, useEffect } from 'react';
import { Send, Bot, User, Loader2, TrendingUp, BarChart3, PieChart, Map, Settings, Clock, Filter } from 'lucide-react';
import { useScoutAI } from '../../hooks/useScoutAI';
import type { AIContext, DateRange } from '../../lib/scout-ai-api';

export interface ScoutAIAssistantProps {
  className?: string;
  context?: AIContext;
  initialPrompts?: string[];
}

const contextConfig = {
  executive: {
    label: 'Executive',
    icon: TrendingUp,
    color: 'bg-blue-100 text-blue-800',
    description: 'KPIs, revenue trends, and performance metrics',
    quickActions: [
      'Show revenue trends',
      'What are our KPIs?',
      'Monthly growth analysis',
      'Performance summary'
    ]
  },
  consumer: {
    label: 'Consumer',
    icon: User,
    color: 'bg-green-100 text-green-800',
    description: 'Customer behavior, personas, and shopping patterns',
    quickActions: [
      'Show customer segments',
      'Shopping behavior analysis',
      'Peak hours',
      'Customer personas'
    ]
  },
  competition: {
    label: 'Competition',
    icon: BarChart3,
    color: 'bg-orange-100 text-orange-800',
    description: 'Market share, brand analysis, and competitive positioning',
    quickActions: [
      'Market share analysis',
      'Brand comparison',
      'Competitor insights',
      'Substitution patterns'
    ]
  },
  geographic: {
    label: 'Geographic',
    icon: Map,
    color: 'bg-purple-100 text-purple-800',
    description: 'Regional performance, location trends, and geographic analysis',
    quickActions: [
      'Regional performance',
      'Store density map',
      'Geographic trends',
      'Location analysis'
    ]
  }
};

const regions = ['ALL', 'NCR', 'Region I', 'Region II', 'Region III', 'Region IV-A', 'MIMAROPA', 'Region V', 'Region VI', 'Region VII', 'Region VIII', 'Region IX', 'Region X', 'Region XI', 'Region XII', 'CAR', 'BARMM', 'CARAGA'];

export const ScoutAIAssistant: React.FC<ScoutAIAssistantProps> = ({
  className = '',
  context: initialContext = 'executive',
  initialPrompts = []
}) => {
  const [input, setInput] = useState('');
  const [currentContext, setCurrentContext] = useState<AIContext>(initialContext);
  const [selectedRegion, setSelectedRegion] = useState<string>('ALL');
  const [dateRange, setDateRange] = useState<string>('last_30_days');
  const [showFilters, setShowFilters] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  
  const {
    messages,
    isLoading,
    error,
    sendMessage,
    clearMessages,
    askPrompt
  } = useScoutAI(currentContext);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const handleSend = async () => {
    if (!input.trim() || isLoading) return;
    
    const message = input.trim();
    setInput('');
    
    const filters = {
      region: selectedRegion === 'ALL' ? undefined : selectedRegion,
      dateRange: dateRange
    };
    
    await sendMessage(message, filters);
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  const handleQuickAction = (action: string) => {
    setInput(action);
    setTimeout(() => handleSend(), 100);
  };

  const handleContextChange = (newContext: AIContext) => {
    setCurrentContext(newContext);
    clearMessages();
  };

  const formatTimestamp = (timestamp: Date) => {
    return new Intl.DateTimeFormat('en-US', {
      hour: '2-digit',
      minute: '2-digit'
    }).format(timestamp);
  };

  const currentConfig = contextConfig[currentContext];
  const CurrentIcon = currentConfig.icon;

  return (
    <div className={`flex flex-col h-full bg-white border rounded-lg shadow-sm ${className}`}>
      {/* Header with Context Tabs */}
      <div className="flex-shrink-0 border-b bg-gray-50">
        <div className="flex items-center justify-between p-3">
          <div className="flex items-center space-x-2">
            <Bot className="w-5 h-5 text-gray-600" />
            <span className="font-medium text-gray-900">Scout AI Assistant</span>
          </div>
          <button
            onClick={() => setShowFilters(!showFilters)}
            className="p-1 rounded hover:bg-gray-200"
            title="Filters"
          >
            <Settings className="w-4 h-4 text-gray-600" />
          </button>
        </div>
        
        {/* Context Tabs */}
        <div className="flex border-b">
          {(Object.keys(contextConfig) as AIContext[]).map((contextKey) => {
            const config = contextConfig[contextKey];
            const Icon = config.icon;
            const isActive = contextKey === currentContext;
            
            return (
              <button
                key={contextKey}
                onClick={() => handleContextChange(contextKey)}
                className={`flex items-center space-x-2 px-4 py-2 text-sm font-medium border-b-2 transition-colors ${
                  isActive
                    ? 'border-blue-500 text-blue-600 bg-blue-50'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-100'
                }`}
              >
                <Icon className="w-4 h-4" />
                <span>{config.label}</span>
              </button>
            );
          })}
        </div>

        {/* Filters Panel */}
        {showFilters && (
          <div className="p-3 bg-gray-50 border-b space-y-3">
            <div className="flex items-center space-x-4">
              <div className="flex items-center space-x-2">
                <Filter className="w-4 h-4 text-gray-600" />
                <select
                  value={selectedRegion}
                  onChange={(e) => setSelectedRegion(e.target.value)}
                  className="text-sm border rounded px-2 py-1"
                >
                  {regions.map(region => (
                    <option key={region} value={region}>{region}</option>
                  ))}
                </select>
              </div>
              
              <div className="flex items-center space-x-2">
                <Clock className="w-4 h-4 text-gray-600" />
                <select
                  value={dateRange}
                  onChange={(e) => setDateRange(e.target.value)}
                  className="text-sm border rounded px-2 py-1"
                >
                  <option value="today">Today</option>
                  <option value="this_week">This Week</option>
                  <option value="this_month">This Month</option>
                  <option value="last_30_days">Last 30 Days</option>
                </select>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Messages Area */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.length === 0 && (
          <div className="text-center py-8">
            <div className="mb-4">
              <CurrentIcon className="w-12 h-12 mx-auto text-gray-400" />
            </div>
            <h3 className="text-lg font-medium text-gray-900 mb-2">
              {currentConfig.label} Intelligence
            </h3>
            <p className="text-gray-600 mb-6 max-w-sm mx-auto">
              {currentConfig.description}
            </p>
            
            {/* Quick Actions */}
            <div className="grid grid-cols-2 gap-2 max-w-md mx-auto">
              {currentConfig.quickActions.map((action, index) => (
                <button
                  key={index}
                  onClick={() => handleQuickAction(action)}
                  disabled={isLoading}
                  className="text-sm px-3 py-2 bg-gray-100 hover:bg-gray-200 rounded-lg text-gray-700 transition-colors disabled:opacity-50"
                >
                  {action}
                </button>
              ))}
            </div>
          </div>
        )}

        {messages.map((message, index) => (
          <div key={index} className={`flex ${message.role === 'user' ? 'justify-end' : 'justify-start'}`}>
            <div className={`max-w-[80%] ${message.role === 'user' ? 'bg-blue-500 text-white' : 'bg-gray-100 text-gray-900'} rounded-lg px-4 py-2`}>
              <div className="whitespace-pre-wrap text-sm">{message.content}</div>
              
              {/* Message metadata */}
              <div className={`flex items-center justify-between mt-2 text-xs ${message.role === 'user' ? 'text-blue-100' : 'text-gray-500'}`}>
                <span>{formatTimestamp(message.timestamp)}</span>
                {message.role === 'assistant' && message.latency && (
                  <span>{message.latency}ms</span>
                )}
              </div>

              {/* Assistant message with data visualization */}
              {message.role === 'assistant' && message.data && (
                <div className="mt-3 p-3 bg-white rounded border">
                  <div className="text-xs text-gray-500 mb-2">
                    Intent: <span className={`px-2 py-1 rounded ${contextConfig[message.intent || 'executive'].color}`}>
                      {message.intent}
                    </span>
                    {message.route && <span className="ml-2">via {message.route}</span>}
                  </div>
                  
                  <details className="text-sm">
                    <summary className="cursor-pointer text-gray-600 hover:text-gray-800">
                      View raw data
                    </summary>
                    <pre className="mt-2 text-xs bg-gray-50 p-2 rounded overflow-x-auto">
                      {JSON.stringify(message.data, null, 2)}
                    </pre>
                  </details>
                </div>
              )}

              {/* Recommendations */}
              {message.role === 'assistant' && message.recommendations && message.recommendations.length > 0 && (
                <div className="mt-3 p-3 bg-yellow-50 rounded border border-yellow-200">
                  <h4 className="text-sm font-medium text-yellow-800 mb-2">💡 Recommendations</h4>
                  <ul className="text-xs space-y-1">
                    {message.recommendations.slice(0, 3).map((rec, idx) => (
                      <li key={idx} className="text-yellow-700">• {rec}</li>
                    ))}
                  </ul>
                </div>
              )}
            </div>
          </div>
        ))}

        {/* Loading indicator */}
        {isLoading && (
          <div className="flex justify-start">
            <div className="bg-gray-100 rounded-lg px-4 py-2 flex items-center space-x-2">
              <Loader2 className="w-4 h-4 animate-spin text-gray-600" />
              <span className="text-sm text-gray-600">Analyzing...</span>
            </div>
          </div>
        )}

        {/* Error display */}
        {error && (
          <div className="flex justify-center">
            <div className="bg-red-50 border border-red-200 rounded-lg px-4 py-2">
              <p className="text-sm text-red-800">{error}</p>
              <button
                onClick={() => window.location.reload()}
                className="text-xs text-red-600 hover:text-red-800 mt-1"
              >
                Retry
              </button>
            </div>
          </div>
        )}
        
        <div ref={messagesEndRef} />
      </div>

      {/* Input Area */}
      <div className="flex-shrink-0 border-t p-4">
        <div className="flex space-x-2">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder={`Ask about ${currentConfig.label.toLowerCase()} insights...`}
            disabled={isLoading}
            className="flex-1 border rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent disabled:opacity-50"
          />
          <button
            onClick={handleSend}
            disabled={!input.trim() || isLoading}
            className="px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-1"
          >
            {isLoading ? (
              <Loader2 className="w-4 h-4 animate-spin" />
            ) : (
              <Send className="w-4 h-4" />
            )}
          </button>
        </div>
        
        {messages.length > 0 && (
          <div className="flex justify-between items-center mt-2">
            <button
              onClick={clearMessages}
              className="text-xs text-gray-500 hover:text-gray-700"
            >
              Clear conversation
            </button>
            <div className="text-xs text-gray-500">
              {selectedRegion !== 'ALL' && <span>Region: {selectedRegion} • </span>}
              Period: {dateRange.replace('_', ' ')}
            </div>
          </div>
        )}
      </div>
    </div>
  );
};