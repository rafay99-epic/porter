// Recreation of PreviewSheet.swift — a dry run, grouped by destination.
import { categoryByFolder } from '@porter/core'
import { Eye, RotateCw, ArrowRight } from 'lucide-react'
import { Glyph } from '../Glyph'

const GROUPS: { folder: string; files: string[] }[] = [
  { folder: 'PDFs', files: ['Invoice-April-2026.pdf', 'lease-renewal.pdf'] },
  { folder: 'screenshots', files: ['Screenshot 2026-06-26 at 14.02.11.png'] },
  { folder: 'Installers', files: ['Ableton-Live-12.dmg'] },
  { folder: 'Documents', files: ['q2-forecast.xlsx', 'notes.md'] },
]

export function PreviewWindow({ className = '' }: { className?: string }) {
  const total = GROUPS.reduce((n, g) => n + g.files.length, 0)
  return (
    <div className={`sysfont w-[460px] bg-[#f6f6f8] ${className}`}>
      <div className="flex items-center gap-2.5 px-3.5 py-3">
        <Eye size={18} className="text-blue-600" />
        <div>
          <div className="text-[14px] font-semibold leading-tight text-ink">Preview</div>
          <div className="text-[11px] leading-tight text-ink-2">
            {total} files would move — nothing has been touched
          </div>
        </div>
        <RotateCw size={14} className="ml-auto text-ink-3" />
      </div>
      <div className="mac-divider" />

      <div className="max-h-[300px] overflow-y-auto py-1">
        {GROUPS.map((g) => {
          const cat = categoryByFolder(g.folder)
          return (
            <div key={g.folder}>
              <div className="flex items-center gap-2 px-3.5 pt-2.5 pb-1">
                <Glyph icon={cat.icon} size={14} className="text-ink-3" />
                <span className="text-[12.5px] font-semibold text-ink">{g.folder}</span>
                <span className="text-[11px] text-ink-3">{g.files.length}</span>
              </div>
              {g.files.map((f) => (
                <div key={f} className="flex items-center gap-2 px-3.5 py-1">
                  <ArrowRight size={12} className="w-4 text-ink-3/70" />
                  <span className="truncate text-[12.5px] text-ink-2">{f}</span>
                </div>
              ))}
              <div className="mac-divider mt-1" />
            </div>
          )
        })}
      </div>

      <div className="flex items-center px-3.5 py-3">
        <button className="mac-btn-prominent">Sort These Now</button>
        <button className="mac-btn ml-auto">Close</button>
      </div>
    </div>
  )
}
