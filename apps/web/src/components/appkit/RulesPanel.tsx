// Recreation of the Rules editor (RulesEditor.swift) — ordered rules, first match
// wins, each with a destination and a conflict policy.
import { DEFAULT_RULES, RULE_CONDITIONS, categoryByFolder } from '@porter/core'
import { ArrowRight, GripVertical, Plus } from 'lucide-react'
import { Glyph } from '../Glyph'

const POLICY = [
  'Keep both',
  'Keep both',
  'Keep both',
  'Keep newer',
  'Overwrite',
  'Keep both',
  'Keep both',
  'Keep both',
  'Skip',
  'Keep both',
]

export function RulesPanel({ className = '' }: { className?: string }) {
  return (
    <div className={`sysfont w-[460px] max-w-full bg-[#f6f6f8] ${className}`}>
      <div className="flex items-center gap-2 px-3.5 py-3">
        <span className="text-[13.5px] font-semibold text-ink">Rules</span>
        <span className="text-[11.5px] text-ink-2">· first match wins</span>
        <button className="mac-btn ml-auto !py-1">
          <Plus size={12} /> Add Rule
        </button>
      </div>
      <div className="mac-divider" />

      <div className="max-h-[330px] overflow-y-auto">
        {DEFAULT_RULES.map((r, i) => {
          const cat = categoryByFolder(r.dest)
          return (
            <div key={i}>
              <div className="flex items-center gap-2 px-3 py-2">
                <GripVertical size={13} className="shrink-0 text-ink-3/60" />
                <span className="relative inline-flex h-[16px] w-[26px] shrink-0 items-center rounded-full bg-ok">
                  <span className="absolute left-[12px] h-[12px] w-[12px] rounded-full bg-white shadow-sm" />
                </span>
                <span className="min-w-0 flex-1 truncate font-mono text-[11.5px] text-ink-2">
                  {r.match}
                </span>
                <ArrowRight size={12} className="shrink-0 text-ink-3" />
                <span className="flex shrink-0 items-center gap-1 text-[12px] font-medium text-ink">
                  <Glyph icon={cat.icon} size={13} className="text-ink-3" />
                  {r.dest}
                </span>
                <span className="hidden shrink-0 rounded bg-blue-soft px-1.5 py-0.5 text-[10px] font-medium text-blue-700 sm:inline">
                  {POLICY[i]}
                </span>
              </div>
              {i < DEFAULT_RULES.length - 1 && <div className="mac-divider ml-9" />}
            </div>
          )
        })}
      </div>

      <div className="mac-divider" />
      <div className="flex flex-wrap items-center gap-1.5 px-3 py-3">
        <span className="mr-1 text-[11px] text-ink-3">match by</span>
        {RULE_CONDITIONS.map((c) => (
          <span
            key={c}
            className="rounded-md border border-black/10 bg-white px-1.5 py-0.5 font-mono text-[10.5px] text-ink-2"
          >
            {c}
          </span>
        ))}
      </div>
    </div>
  )
}
