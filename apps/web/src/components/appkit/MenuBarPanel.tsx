// A faithful recreation of MenuContent.swift — the menu-bar dropdown. Purely
// presentational and typed; parents drive any "live" animation around it.
import { type ActivityItem, type StatusKey, STATUS, categoryByFolder } from '@porter/core'
import { MoreHorizontal, Pause, Play, Inbox, ArrowDownCircle } from 'lucide-react'
import { Glyph } from '../Glyph'

function middleTruncate(name: string, max = 30): string {
  if (name.length <= max) return name
  const head = Math.ceil((max - 1) / 2)
  const tail = Math.floor((max - 1) / 2)
  return `${name.slice(0, head)}…${name.slice(name.length - tail)}`
}

export interface MenuBarPanelProps {
  status?: StatusKey
  sortedCount?: number
  totalMoved?: number
  lastAt?: string
  activity?: ReadonlyArray<ActivityItem & { id?: string; undone?: boolean }>
  progress?: { completed: number; total: number } | null
  showUpdate?: boolean
  paused?: boolean
  onUndo?: (entry: ActivityItem) => void
  className?: string
}

export function MenuBarPanel({
  status = 'idle',
  sortedCount = 0,
  totalMoved = 1284,
  lastAt = '2:41 PM',
  activity = [],
  progress = null,
  showUpdate = false,
  paused = false,
  onUndo,
  className = '',
}: MenuBarPanelProps) {
  const meta = STATUS[status]
  const title =
    status === 'sorted' ? `Sorted ${sortedCount} file${sortedCount === 1 ? '' : 's'}` : meta.title
  const subtitle = lastAt
    ? `${totalMoved.toLocaleString()} sorted · last at ${lastAt}`
    : `${totalMoved.toLocaleString()} sorted this session`

  return (
    <div
      className={`sysfont w-[320px] overflow-hidden rounded-[14px] border border-black/10 bg-[#f6f6f8]/95 shadow-popover backdrop-blur-2xl ${className}`}
    >
      {/* status header */}
      <div className="p-3">
        <div className="flex items-center gap-2.5">
          <span className="flex w-6 justify-center" style={{ color: meta.color }}>
            <Glyph icon={meta.icon} size={18} className={meta.spin ? 'animate-spin-slow' : ''} />
          </span>
          <div className="min-w-0">
            <div className="text-[13px] font-semibold leading-tight text-ink">{title}</div>
            <div className="truncate text-[11px] leading-tight text-ink-2">{subtitle}</div>
          </div>
        </div>
        {status === 'syncing' && progress && (
          <div className="mt-2.5 space-y-1">
            <div className="h-[5px] w-full overflow-hidden rounded-full bg-black/[0.08]">
              <div
                className="h-full rounded-full bg-blue-500 transition-[width] duration-500 ease-out"
                style={{ width: `${(progress.completed / progress.total) * 100}%` }}
              />
            </div>
            <div className="text-[10.5px] text-ink-2">
              Sorting {progress.completed} of {progress.total}…
            </div>
          </div>
        )}
      </div>
      <div className="mac-divider" />

      {showUpdate && (
        <div className="flex items-center gap-2.5 bg-blue-500/[0.12] p-3">
          <ArrowDownCircle size={16} className="text-blue-600" />
          <span className="text-[11px] text-ink">Update available: 0.42</span>
          <button className="mac-btn ml-auto !py-[3px] !text-[11px]">Update</button>
        </div>
      )}

      {/* activity log */}
      <div className="max-h-[260px] overflow-y-auto">
        {activity.length === 0 ? (
          <div className="flex h-[150px] flex-col items-center justify-center gap-2 px-6 text-center">
            <Inbox size={26} className="text-ink-3/60" />
            <div className="text-[12.5px] text-ink-2">No files sorted yet</div>
            <div className="text-[10.5px] text-ink-3">
              Drop a file in your watched folder and it'll appear here.
            </div>
          </div>
        ) : (
          activity.map((entry, i) => {
            const cat = categoryByFolder(entry.dest)
            return (
              <div key={entry.id ?? entry.name + i}>
                <div className="group flex items-center gap-2 px-3 py-1.5">
                  <span className="flex w-[18px] justify-center text-ink-3">
                    <Glyph icon={cat.icon} size={15} />
                  </span>
                  <div className="min-w-0 flex-1">
                    <div
                      className={`truncate text-[12.5px] leading-tight ${
                        entry.undone ? 'text-ink-3 line-through' : 'text-ink'
                      }`}
                    >
                      {middleTruncate(entry.name)}
                    </div>
                    <div className="truncate text-[10.5px] leading-tight text-ink-2">
                      {entry.undone ? `moved back from ${entry.dest}` : `→ ${entry.dest}`}
                    </div>
                  </div>
                  {entry.undone ? (
                    <span className="text-[10.5px] text-ink-3">Moved back</span>
                  ) : (
                    onUndo && (
                      <button
                        onClick={() => onUndo(entry)}
                        className="rounded px-1 text-[10.5px] text-blue-600 opacity-0 transition group-hover:opacity-100"
                      >
                        Move Back
                      </button>
                    )
                  )}
                </div>
                {i < activity.length - 1 && <div className="mac-divider ml-3" />}
              </div>
            )
          })
        )}
      </div>

      <div className="mac-divider" />
      {/* footer */}
      <div className="flex items-center gap-2 p-3">
        {paused ? (
          <button className="mac-btn-prominent">
            <Play size={11} fill="currentColor" /> Resume
          </button>
        ) : (
          <>
            <button className="mac-btn">Sort Now</button>
            <button className="mac-btn !px-2" aria-label="Pause sorting">
              <Pause size={11} fill="currentColor" />
            </button>
          </>
        )}
        <div className="ml-auto flex items-center gap-2">
          <button className="mac-btn">Open</button>
          <button className="mac-btn !px-1.5" aria-label="More">
            <MoreHorizontal size={14} />
          </button>
        </div>
      </div>
    </div>
  )
}
