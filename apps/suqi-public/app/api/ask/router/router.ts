import { CAPABILITIES } from "./capabilities";

export type AgentScore = {
  code: string;
  score: number;
  signals_matched: string[];
  confidence: number;
};

export function scoreAgents(query: string): AgentScore[] {
  const q = query.toLowerCase();
  const words = q.split(/\s+/);

  return CAPABILITIES.map(c => {
    const matched_signals: string[] = [];
    let score = 0;

    // Exact phrase matching (higher weight)
    for (const signal of c.signals) {
      if (q.includes(signal.toLowerCase())) {
        matched_signals.push(signal);
        score += signal.split(' ').length * 2; // Multi-word signals get bonus
      }
    }

    // Word-level matching (lower weight)
    for (const word of words) {
      if (word.length > 2) { // Skip short words
        for (const signal of c.signals) {
          if (signal.toLowerCase().includes(word) && !matched_signals.includes(signal)) {
            matched_signals.push(signal);
            score += 1;
          }
        }
      }
    }

    // Apply cost penalty and risk adjustment
    const adjusted_score = score - c.cost;
    const risk_penalty = c.risk === "high" ? 0.5 : c.risk === "medium" ? 0.8 : 1.0;
    const final_score = adjusted_score * risk_penalty;

    // Calculate confidence based on signal density
    const confidence = Math.min(1.0, (matched_signals.length / Math.max(1, c.signals.length * 0.3)));

    return {
      code: c.code,
      score: Math.max(0, final_score),
      signals_matched: matched_signals,
      confidence
    };
  }).sort((a, b) => b.score - a.score);
}

export function getTopAgents(query: string, limit: number = 3): AgentScore[] {
  return scoreAgents(query).slice(0, limit).filter(a => a.score > 0);
}

export function hasHighConfidenceMatch(query: string, threshold: number = 0.7): boolean {
  const top = scoreAgents(query)[0];
  return top ? top.confidence >= threshold : false;
}