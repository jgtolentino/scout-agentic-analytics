"use client";
type Item = { label: string; value: string | number; delta?: number | null; help?: string | null };
type Props = { title?: string; items?: Item[]; columns?: number };

export default function ScorecardList({ title="Scorecards", items = [], columns = 4 }: Props) {
  const grid = `grid grid-cols-1 sm:grid-cols-2 md:grid-cols-${Math.max(2, Math.min(6, columns))} gap-3`;
  return (
    <div className="space-y-3">
      <div className="text-sm font-semibold">{title}</div>
      <div className={grid}>
        {items.map((it, idx) => (
          <div key={idx} className="rounded border p-3">
            <div className="text-xs opacity-70">{it.label}</div>
            <div className="text-xl font-semibold">{it.value}</div>
            {typeof it.delta === "number" && (
              <div className={`text-xs ${it.delta >= 0 ? "text-green-600" : "text-red-600"}`}>
                {it.delta >= 0 ? "▲" : "▼"} {Math.abs(it.delta)}%
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}