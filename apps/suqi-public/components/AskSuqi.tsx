'use client';

import { useState, useRef, useEffect } from 'react';
import { Send, Loader2, AlertCircle, CheckCircle, Clock, BarChart3, Map, FileText, Database, Info } from 'lucide-react';

type Message = {
  id: string;
  type: 'user' | 'suqi';
  content: string;
  timestamp: Date;
  data?: any; // Structured response data
};

type AskSuqiProps = {
  filters?: any; // Current dashboard filters
  onFiltersChange?: (filters: any) => void;
  className?: string;
};

export function AskSuqi({ filters, onFiltersChange, className = '' }: AskSuqiProps) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [loading, setLoading] = useState(false);
  const [input, setInput] = useState('');
  const [sessionId] = useState(() => `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const handleSend = async () => {
    if (!input.trim() || loading) return;

    const userMessage: Message = {
      id: `user_${Date.now()}`,
      type: 'user',
      content: input.trim(),
      timestamp: new Date()
    };

    setMessages(prev => [...prev, userMessage]);
    setInput('');
    setLoading(true);

    try {
      const response = await fetch('/api/ask', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          message: userMessage.content,
          filters,
          session_id: sessionId,
          user: 'dashboard_user'
        })
      });

      if (!response.ok) {
        throw new Error(`API error: ${response.status}`);
      }

      const result = await response.json();

      const suqiMessage: Message = {
        id: `suqi_${Date.now()}`,
        type: 'suqi',
        content: formatSuqiResponse(result),
        timestamp: new Date(),
        data: result
      };

      setMessages(prev => [...prev, suqiMessage]);

    } catch (error) {
      console.error('Ask Suqi error:', error);
      const errorMessage: Message = {
        id: `error_${Date.now()}`,
        type: 'suqi',
        content: 'Sorry, I encountered an error processing your request. Please try again.',
        timestamp: new Date()
      };
      setMessages(prev => [...prev, errorMessage]);
    } finally {
      setLoading(false);
      inputRef.current?.focus();
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  const formatSuqiResponse = (result: any): string => {
    if (result.error) {
      return `Error: ${result.message || result.error}`;
    }

    if (result.reply?.summary) {
      return result.reply.summary;
    }

    if (result.reply?.answer) {
      return result.reply.answer;
    }

    return `I've completed your request. ${result.intent || 'Operation completed successfully.'}`;
  };

  return (
    <div className={`flex flex-col h-96 bg-white border border-gray-200 rounded-lg shadow-sm ${className}`}>
      {/* Header */}
      <div className="flex items-center gap-2 p-3 border-b border-gray-200 bg-gray-50 rounded-t-lg">
        <div className="w-2 h-2 bg-green-500 rounded-full"></div>
        <span className="font-medium text-sm text-gray-800">Ask Suqi</span>
        <span className="text-xs text-gray-500">AI Analytics Assistant</span>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-3 space-y-3">
        {messages.length === 0 && (
          <div className="text-center text-gray-500 text-sm mt-8">
            <Info className="w-8 h-8 mx-auto mb-2 text-gray-400" />
            <p>Ask me anything about your Scout v7 data!</p>
            <p className="text-xs mt-1">Try: "Show revenue by category" or "Map sales in NCR"</p>
          </div>
        )}

        {messages.map((message) => (
          <div key={message.id} className={`flex ${message.type === 'user' ? 'justify-end' : 'justify-start'}`}>
            <div className={`max-w-[80%] rounded-lg p-3 ${
              message.type === 'user'
                ? 'bg-blue-500 text-white'
                : 'bg-gray-100 text-gray-800'
            }`}>
              <div className="text-sm">{message.content}</div>
              {message.data && <SuqiResponseRenderer data={message.data} />}
              <div className={`text-xs mt-1 ${
                message.type === 'user' ? 'text-blue-100' : 'text-gray-500'
              }`}>
                {message.timestamp.toLocaleTimeString()}
              </div>
            </div>
          </div>
        ))}

        {loading && (
          <div className="flex justify-start">
            <div className="bg-gray-100 rounded-lg p-3 flex items-center gap-2">
              <Loader2 className="w-4 h-4 animate-spin" />
              <span className="text-sm text-gray-600">Thinking...</span>
            </div>
          </div>
        )}

        <div ref={messagesEndRef} />
      </div>

      {/* Input */}
      <div className="p-3 border-t border-gray-200">
        <div className="flex gap-2">
          <input
            ref={inputRef}
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder="Ask about your data..."
            className="flex-1 p-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            disabled={loading}
          />
          <button
            onClick={handleSend}
            disabled={loading || !input.trim()}
            className="p-2 bg-blue-500 text-white rounded-md hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
          </button>
        </div>
      </div>
    </div>
  );
}

function SuqiResponseRenderer({ data }: { data: any }) {
  if (!data || !data.reply) return null;

  const { reply, execution } = data;

  return (
    <div className="mt-3 space-y-2">
      {/* Execution Status */}
      <div className="flex items-center gap-2 text-xs">
        {execution?.success ? (
          <CheckCircle className="w-3 h-3 text-green-500" />
        ) : (
          <AlertCircle className="w-3 h-3 text-red-500" />
        )}
        <span className="text-gray-600">
          {execution?.total_time_ms}ms • {data.confidence ? `${Math.round(data.confidence * 100)}% confident` : ''}
        </span>
      </div>

      {/* Type-specific Rendering */}
      {reply.type === 'table' && <TableRenderer data={reply} />}
      {reply.type === 'map' && <MapRenderer data={reply} />}
      {reply.type === 'report' && <ReportRenderer data={reply} />}
      {reply.type === 'status' && <StatusRenderer data={reply} />}
      {reply.type === 'answer' && <AnswerRenderer data={reply} />}

      {/* Warnings */}
      {reply.warnings && reply.warnings.length > 0 && (
        <div className="text-xs text-amber-600 bg-amber-50 p-2 rounded">
          <AlertCircle className="w-3 h-3 inline mr-1" />
          {reply.warnings.join(', ')}
        </div>
      )}
    </div>
  );
}

function TableRenderer({ data }: { data: any }) {
  if (!data.data || !Array.isArray(data.data)) return null;

  const rows = data.data.slice(0, 5); // Show first 5 rows
  if (rows.length === 0) return <div className="text-xs text-gray-500">No data returned</div>;

  const columns = Object.keys(rows[0]).filter(col => !col.startsWith('__'));

  return (
    <div className="bg-white border rounded text-xs">
      <div className="flex items-center gap-1 p-2 bg-gray-50 border-b">
        <BarChart3 className="w-3 h-3" />
        <span className="font-medium">Data ({data.row_count} rows)</span>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead className="bg-gray-50">
            <tr>
              {columns.map(col => (
                <th key={col} className="p-1 text-left font-medium text-gray-700 border-b">
                  {col}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((row, i) => (
              <tr key={i} className="border-b">
                {columns.map(col => (
                  <td key={col} className="p-1 text-gray-600">
                    {formatCellValue(row[col])}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {data.row_count > 5 && (
        <div className="p-2 text-center text-gray-500 bg-gray-50 border-t">
          Showing 5 of {data.row_count} rows
        </div>
      )}
    </div>
  );
}

function MapRenderer({ data }: { data: any }) {
  return (
    <div className="bg-white border rounded text-xs">
      <div className="flex items-center gap-1 p-2 bg-gray-50 border-b">
        <Map className="w-3 h-3" />
        <span className="font-medium">Geographic Data</span>
      </div>
      <div className="p-2">
        <div className="text-gray-600">
          {data.feature_count} features • Level: {data.export_params?.level}
        </div>
        {data.bounds && (
          <div className="text-gray-500 mt-1">
            Bounds: {data.bounds.southwest?.[0]?.toFixed(3)}, {data.bounds.southwest?.[1]?.toFixed(3)} to{' '}
            {data.bounds.northeast?.[0]?.toFixed(3)}, {data.bounds.northeast?.[1]?.toFixed(3)}
          </div>
        )}
      </div>
    </div>
  );
}

function ReportRenderer({ data }: { data: any }) {
  return (
    <div className="bg-white border rounded text-xs">
      <div className="flex items-center gap-1 p-2 bg-gray-50 border-b">
        <FileText className="w-3 h-3" />
        <span className="font-medium">Report</span>
      </div>
      <div className="p-2 space-y-1">
        <div>Status: <span className="font-medium">{data.status}</span></div>
        {data.details && Object.entries(data.details).map(([key, value]: [string, any]) => (
          <div key={key}>
            {key.replace(/_/g, ' ')}: <span className="font-medium">{formatCellValue(value)}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

function StatusRenderer({ data }: { data: any }) {
  return (
    <div className="bg-white border rounded text-xs">
      <div className="flex items-center gap-1 p-2 bg-gray-50 border-b">
        <Database className="w-3 h-3" />
        <span className="font-medium">Operation Status</span>
      </div>
      <div className="p-2">
        <div>Operation: {data.operation}</div>
        <div>Status: <span className="font-medium">{data.status}</span></div>
        {data.run_id && <div>Run ID: {data.run_id}</div>}
        {data.records_processed && <div>Records: {data.records_processed}</div>}
      </div>
    </div>
  );
}

function AnswerRenderer({ data }: { data: any }) {
  return (
    <div className="bg-white border rounded text-xs">
      <div className="flex items-center gap-1 p-2 bg-gray-50 border-b">
        <Info className="w-3 h-3" />
        <span className="font-medium">Knowledge Base</span>
      </div>
      <div className="p-2">
        {data.citations && data.citations.length > 0 && (
          <div className="text-gray-500 mb-2">
            Sources: {data.citations.join(', ')}
          </div>
        )}
        {data.confidence && (
          <div className="text-gray-500">
            Confidence: {Math.round(data.confidence * 100)}%
          </div>
        )}
      </div>
    </div>
  );
}

function formatCellValue(value: any): string {
  if (value === null || value === undefined) return '';
  if (typeof value === 'number') {
    if (Number.isInteger(value)) return value.toLocaleString();
    return value.toLocaleString(undefined, { maximumFractionDigits: 2 });
  }
  return String(value);
}