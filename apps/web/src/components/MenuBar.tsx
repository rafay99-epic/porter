import { useState } from 'react'
import { type StatusKey, STATUS, INSTALL, REPO } from '@porter/core'
import { Wifi, Search, BatteryFull, ChevronDown } from 'lucide-react'
import { PorterMark, GithubMark } from './brand'
import { Glyph } from './Glyph'

const CHAPTERS = [
  { label: 'Watch', href: '#watch' },
  { label: 'Destinations', href: '#destinations' },
  { label: 'Why it works', href: '#why' },
  { label: 'Control', href: '#control' },
  { label: 'Install', href: '#install' },
]

interface MenuBarProps {
  status: StatusKey
}

export function MenuBar({ status }: MenuBarProps) {
  const [open, setOpen] = useState(false)
  const meta = STATUS[status]

  return (
    <header className="fixed inset-x-0 top-0 z-50 border-b border-ink-line bg-paper/80 backdrop-blur-xl backdrop-saturate-150">
      <div className="flex h-[30px] items-center gap-4 px-3 sm:px-5">
        {/* left — app + menus */}
        <a href="#top" className="flex shrink-0 items-center gap-2" onClick={() => setOpen(false)}>
          <PorterMark size={16} />
          <span className="text-[13px] font-bold tracking-tight text-ink">Porter</span>
        </a>
        <nav className="hidden items-center gap-4 md:flex">
          {CHAPTERS.map((c) => (
            <a
              key={c.href}
              href={c.href}
              className="text-[12.5px] text-ink-2 transition hover:text-ink"
            >
              {c.label}
            </a>
          ))}
        </nav>

        {/* right — system tray with the live Porter status item */}
        <div className="ml-auto flex items-center gap-3 text-ink-3">
          <a
            href={REPO}
            target="_blank"
            rel="noreferrer"
            className="hidden transition hover:text-ink sm:block"
            aria-label="Porter on GitHub"
          >
            <GithubMark size={14} />
          </a>
          <span
            className="flex items-center gap-1.5 rounded-[5px] px-1.5 py-0.5"
            title={meta.title}
          >
            <Glyph
              icon={meta.icon}
              size={15}
              strokeWidth={1.8}
              className={meta.spin ? 'animate-spin-slow' : ''}
            />
            <span className="hidden text-[11.5px] font-medium text-ink-2 lg:inline">
              {status === 'sorted' ? 'Sorted' : meta.title.replace('…', '')}
            </span>
          </span>
          <BatteryFull size={17} className="hidden sm:block" />
          <Wifi size={14} className="hidden sm:block" />
          <Search size={13} className="hidden sm:block" />
          <span className="hidden text-[12px] tabular-nums text-ink-2 sm:block">2:41 PM</span>

          {/* mobile chapter toggle */}
          <button
            onClick={() => setOpen((v) => !v)}
            className="flex items-center text-ink-2 md:hidden"
            aria-label="Chapters"
          >
            <ChevronDown size={16} className={`transition ${open ? 'rotate-180' : ''}`} />
          </button>
        </div>
      </div>

      {/* mobile dropdown */}
      {open && (
        <div className="border-t border-ink-line bg-paper/95 px-4 py-2 md:hidden">
          {CHAPTERS.map((c) => (
            <a
              key={c.href}
              href={c.href}
              onClick={() => setOpen(false)}
              className="block py-2 text-[15px] font-medium text-ink"
            >
              {c.label}
            </a>
          ))}
          <a href={INSTALL.dmgStable} className="block py-2 text-[15px] font-semibold text-blue">
            Download Porter ↓
          </a>
        </div>
      )}
    </header>
  )
}
