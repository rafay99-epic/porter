// Recreation of SettingsView.swift (General tab) — macOS grouped Form.
import type { ReactNode } from 'react'
import { Settings as Gear, Folder, ListChecks, Info } from 'lucide-react'

function Toggle({ on }: { on: boolean }) {
  return (
    <span
      className={`relative inline-flex h-[20px] w-[34px] items-center rounded-full transition ${
        on ? 'bg-ok' : 'bg-black/20'
      }`}
    >
      <span
        className={`absolute h-[16px] w-[16px] rounded-full bg-white shadow-sm transition-all ${
          on ? 'left-[16px]' : 'left-[2px]'
        }`}
      />
    </span>
  )
}

function Row({
  label,
  children,
  last = false,
}: {
  label: string
  children: ReactNode
  last?: boolean
}) {
  return (
    <>
      <div className="flex items-center justify-between px-3.5 py-2.5">
        <span className="text-[13px] text-ink">{label}</span>
        {children}
      </div>
      {!last && <div className="mac-divider ml-3.5" />}
    </>
  )
}

function Group({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div>
      <div className="px-1 pb-1 text-[11px] font-semibold uppercase tracking-wide text-ink-3">
        {title}
      </div>
      <div className="overflow-hidden rounded-[10px] border border-black/10 bg-white">
        {children}
      </div>
    </div>
  )
}

const TABS = [
  { label: 'General', Icon: Gear, active: true },
  { label: 'Folders', Icon: Folder, active: false },
  { label: 'Rules', Icon: ListChecks, active: false },
  { label: 'About', Icon: Info, active: false },
]

export function SettingsWindow({ className = '' }: { className?: string }) {
  return (
    <div className={`sysfont w-[520px] bg-[#f1f1f3] ${className}`}>
      <div className="flex items-center justify-center gap-1 px-3 pt-3 pb-2">
        {TABS.map((t) => (
          <span
            key={t.label}
            className={`flex flex-col items-center gap-1 rounded-md px-4 py-1.5 text-[11px] font-medium ${
              t.active ? 'bg-blue-500/15 text-blue-700' : 'text-ink-2'
            }`}
          >
            <t.Icon size={17} />
            {t.label}
          </span>
        ))}
      </div>
      <div className="mac-divider" />

      <div className="space-y-4 p-4">
        <Group title="Startup">
          <Row label="Launch Porter at login" last>
            <Toggle on />
          </Row>
        </Group>

        <Group title="Display">
          <Row label="Show icon in the menu bar">
            <Toggle on />
          </Row>
          <Row label="Notify me when files are sorted" last>
            <Toggle on />
          </Row>
        </Group>

        <Group title="NAS">
          <Row label="File to">
            <span className="font-mono text-[12px] text-ink-2">/Volumes/NAS/Inbox</span>
          </Row>
          <Row label="SMB URL" last>
            <span className="font-mono text-[12px] text-ink-3">smb://nas.local/Inbox</span>
          </Row>
        </Group>

        <Group title="Timing">
          <div className="px-3.5 py-3">
            <div className="text-[13px] text-ink">Wait 30s before moving a new file</div>
            <div className="relative mt-2.5 h-1 rounded-full bg-black/10">
              <div className="absolute inset-y-0 left-0 w-[22%] rounded-full bg-blue-500" />
              <div className="absolute -top-[5px] left-[22%] h-[14px] w-[14px] -translate-x-1/2 rounded-full bg-white shadow ring-1 ring-black/10" />
            </div>
            <div className="mt-2 text-[11px] text-ink-2">
              Protects against grabbing a download that's still being written.
            </div>
          </div>
        </Group>

        <Group title="Integrity">
          <Row label="Skip duplicates already on the NAS">
            <Toggle on />
          </Row>
          <Row label="Verify each copy before deleting the original" last>
            <Toggle on />
          </Row>
        </Group>
      </div>
    </div>
  )
}
