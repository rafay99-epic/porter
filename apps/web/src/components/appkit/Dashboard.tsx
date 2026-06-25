// Recreation of DashboardView.swift — status hero, watching summary, activity log.
import {
  type ActivityItem,
  type StatusKey,
  STATUS,
  categoryByFolder,
  WATCHED_FOLDERS,
} from '@porter/core'
import { Folder, HardDrive, Pause, Eye, BarChart3, Settings as SettingsIcon } from 'lucide-react'
import { Glyph } from '../Glyph'

interface DashboardProps {
  status?: StatusKey
  activity?: readonly ActivityItem[]
  totalMoved?: number
  lastAt?: string
  className?: string
}

export function Dashboard({
  status = 'idle',
  activity = [],
  totalMoved = 1284,
  lastAt = '2:41 PM',
  className = '',
}: DashboardProps) {
  const meta = STATUS[status]
  return (
    <div className={`sysfont w-[540px] bg-[#f6f6f8] ${className}`}>
      {/* hero */}
      <div className="flex flex-col items-center px-6 pt-7 pb-4">
        <div
          className="flex h-[68px] w-[68px] items-center justify-center rounded-full"
          style={{ backgroundColor: `${meta.color}26`, color: meta.color }}
        >
          <Glyph icon={meta.icon} size={30} className={meta.spin ? 'animate-spin-slow' : ''} />
        </div>
        <div className="mt-2.5 text-[19px] font-bold tracking-tight text-ink">{meta.title}</div>
        <div className="text-[14px] text-ink-2">Last sorted at {lastAt}</div>
      </div>

      {/* watching card */}
      <div className="px-6">
        <div className="rounded-[10px] bg-black/[0.04] py-1">
          <div className="flex items-center gap-3 px-3 py-2.5">
            <Folder size={17} className="w-6 shrink-0 text-ink-3" />
            <div className="min-w-0">
              <div className="text-[11.5px] text-ink-2">Watching</div>
              <div className="truncate text-[13.5px] text-ink">{WATCHED_FOLDERS.join(', ')}</div>
            </div>
          </div>
          <div className="mac-divider ml-10" />
          <div className="flex items-center gap-3 px-3 py-2.5">
            <HardDrive size={17} className="w-6 shrink-0 text-ink-3" />
            <div className="min-w-0">
              <div className="text-[11.5px] text-ink-2">Filing to</div>
              <div className="truncate text-[13.5px] text-ink">/Volumes/NAS/Inbox</div>
            </div>
            <span className="ml-auto flex items-center gap-1.5">
              <span className="h-[7px] w-[7px] rounded-full bg-ok" />
              <span className="text-[12px] text-ink-2">Mounted</span>
            </span>
          </div>
        </div>
      </div>

      <div className="mt-3.5 mac-divider" />
      <div className="flex items-center justify-between px-6 py-2.5">
        <span className="text-[13px] font-semibold text-ink-2">Recent Activity</span>
        <span className="text-[11.5px] text-ink-3">{totalMoved.toLocaleString()} total</span>
      </div>
      <div className="mac-divider" />

      <div className="max-h-[260px] overflow-y-auto">
        {activity.map((e, i) => {
          const cat = categoryByFolder(e.dest)
          return (
            <div key={e.name + i}>
              <div className="flex items-center gap-2.5 px-6 py-2">
                <span className="flex w-[18px] shrink-0 justify-center text-ink-3">
                  <Glyph icon={cat.icon} size={16} />
                </span>
                <div className="min-w-0 flex-1">
                  <div className="truncate text-[13.5px] text-ink">{e.name}</div>
                  <div className="text-[11px] text-ink-2">→ {e.dest}</div>
                </div>
                <span className="text-[11px] tabular-nums text-ink-3">{e.when}</span>
              </div>
              {i < activity.length - 1 && <div className="mac-divider" />}
            </div>
          )
        })}
      </div>

      <div className="mac-divider" />
      <div className="flex items-center gap-2 px-4 py-3">
        <button className="mac-btn-prominent !px-3 !py-1.5">Sort Now</button>
        <button className="mac-btn !py-1.5">
          <Pause size={12} fill="currentColor" /> Pause
        </button>
        <button className="mac-btn !py-1.5">
          <Eye size={13} /> Preview
        </button>
        <button className="mac-btn !py-1.5">
          <BarChart3 size={13} /> Stats
        </button>
        <button className="mac-btn ml-auto !py-1.5">
          <SettingsIcon size={13} /> Settings
        </button>
      </div>
    </div>
  )
}
