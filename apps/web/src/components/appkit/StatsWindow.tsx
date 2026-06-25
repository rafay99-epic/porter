// Recreation of StatsView.swift — summary cards + 30-day bar chart + by-category bars.
import { STATS, categoryByFolder } from '@porter/core'
import { FileStack, HardDrive, FolderOpen, BarChart3 } from 'lucide-react'
import { Glyph } from '../Glyph'

export function StatsWindow({ className = '' }: { className?: string }) {
  const maxDay = Math.max(...STATS.perDay)
  const maxCat = Math.max(...STATS.byCategory.map((c) => c.count))

  return (
    <div className={`sysfont w-[540px] bg-[#f6f6f8] ${className}`}>
      <div className="flex items-center gap-2.5 px-4 py-3.5">
        <BarChart3 size={18} className="text-blue-600" />
        <span className="text-[14px] font-semibold text-ink">Statistics</span>
      </div>
      <div className="mac-divider" />

      <div className="space-y-5 p-4">
        {/* summary cards */}
        <div className="flex gap-3">
          {[
            { Icon: FileStack, value: STATS.totals.files.toLocaleString(), label: 'files sorted' },
            { Icon: HardDrive, value: STATS.totals.space, label: 'space moved' },
            { Icon: FolderOpen, value: String(STATS.totals.categories), label: 'categories' },
          ].map((c) => (
            <div key={c.label} className="flex-1 rounded-[10px] bg-black/[0.04] p-3">
              <c.Icon size={16} className="text-blue-500" />
              <div className="mt-1.5 text-[22px] font-bold leading-none tracking-tight text-ink">
                {c.value}
              </div>
              <div className="mt-1 text-[11.5px] text-ink-2">{c.label}</div>
            </div>
          ))}
        </div>

        {/* per-day */}
        <div>
          <div className="mb-2 text-[13px] font-semibold text-ink">Files sorted — last 30 days</div>
          <div className="flex h-[150px] items-end gap-[3px] rounded-[10px] bg-white p-3 shadow-[inset_0_0_0_1px_rgba(20,22,28,0.05)]">
            {STATS.perDay.map((v, i) => (
              <div
                key={i}
                className="flex-1 rounded-[2px] bg-blue-500"
                style={{ height: `${Math.max(2, (v / maxDay) * 100)}%`, opacity: 0.5 + (v / maxDay) * 0.5 }}
              />
            ))}
          </div>
        </div>

        {/* by category */}
        <div>
          <div className="mb-2 text-[13px] font-semibold text-ink">By category</div>
          <div className="space-y-1.5">
            {STATS.byCategory.map((c) => {
              const cat = categoryByFolder(c.folder)
              return (
                <div key={c.folder} className="flex items-center gap-2.5">
                  <span className="flex w-[92px] shrink-0 items-center gap-1.5 text-[11.5px] text-ink-2">
                    <Glyph icon={cat.icon} size={13} className="text-ink-3" />
                    <span className="truncate">{c.folder}</span>
                  </span>
                  <div className="h-[14px] flex-1 overflow-hidden rounded-[3px] bg-black/[0.04]">
                    <div
                      className="h-full rounded-[3px] bg-blue-500"
                      style={{ width: `${(c.count / maxCat) * 100}%` }}
                    />
                  </div>
                  <span className="w-7 shrink-0 text-right text-[11px] tabular-nums text-ink-3">
                    {c.count}
                  </span>
                </div>
              )
            })}
          </div>
        </div>
      </div>
    </div>
  )
}
