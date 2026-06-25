import { useLayoutEffect, useRef } from 'react'
import { CATEGORIES, INSTALL, type CategoryKey } from '@porter/core'
import { gsap, prefersReducedMotion } from '../lib/gsap'
import { Glyph } from '../components/Glyph'
import { CopyCommand } from '../components/CopyCommand'
import { Download, RotateCcw, ArrowDown } from 'lucide-react'

// The six bins the intake belt sorts into, and the scattered files that land in them.
const BIN_KEYS: CategoryKey[] = ['screenshots', 'pictures', 'pdfs', 'documents', 'installers', 'archives']
const BINS = BIN_KEYS.map((k) => CATEGORIES.find((c) => c.key === k)!)

const FILES: { name: string; bin: CategoryKey; ext: string }[] = [
  { name: 'Screenshot 2026-06-26.png', bin: 'screenshots', ext: 'png' },
  { name: 'holiday-2025.heic', bin: 'pictures', ext: 'heic' },
  { name: 'sunset-4k.jpg', bin: 'pictures', ext: 'jpg' },
  { name: 'Invoice-April-2026.pdf', bin: 'pdfs', ext: 'pdf' },
  { name: 'lease-renewal.pdf', bin: 'pdfs', ext: 'pdf' },
  { name: 'q2-forecast.xlsx', bin: 'documents', ext: 'xlsx' },
  { name: 'notes.md', bin: 'documents', ext: 'md' },
  { name: 'Ableton-Live-12.dmg', bin: 'installers', ext: 'dmg' },
  { name: 'reference-pack.zip', bin: 'archives', ext: 'zip' },
]

function Chip({ name, ext, tint }: { name: string; ext: string; tint: string }) {
  return (
    <div
      data-chip
      className="flex items-center gap-2 rounded-[9px] border border-ink-line bg-card px-2.5 py-2 shadow-tag will-change-transform"
      style={{ borderLeft: `3px solid ${tint}` }}
    >
      <span className="truncate font-mono text-[11px] text-ink">{name}</span>
      <span className="ml-auto rounded bg-paper-deep px-1 py-0.5 font-mono text-[9px] uppercase text-ink-3">
        {ext}
      </span>
    </div>
  )
}

function IntakeBelt() {
  const stageRef = useRef<HTMLDivElement>(null)
  const replayRef = useRef<() => void>(() => {})

  useLayoutEffect(() => {
    const stage = stageRef.current
    if (!stage) return
    const ctx = gsap.context(() => {
      const chips = gsap.utils.toArray<HTMLElement>('[data-chip]')

      const scatter = () =>
        chips.forEach((el) => {
          gsap.set(el, {
            x: gsap.utils.random(-340, 340),
            y: gsap.utils.random(-260, -40),
            rotation: gsap.utils.random(-24, 24),
            scale: 0.94,
            opacity: 0,
          })
        })

      const settle = () =>
        gsap.to(chips, {
          x: 0,
          y: 0,
          rotation: 0,
          scale: 1,
          opacity: 1,
          duration: 0.95,
          ease: 'power3.out',
          stagger: { each: 0.06, from: 'random' },
        })

      if (prefersReducedMotion()) {
        gsap.set(chips, { opacity: 1 })
        return
      }

      replayRef.current = () => {
        gsap.killTweensOf(chips)
        scatter()
        settle()
      }

      scatter()
      gsap.delayedCall(0.25, settle)
    }, stage)
    return () => ctx.revert()
  }, [])

  return (
    <div ref={stageRef} className="relative">
      <div className="mb-3 flex items-center justify-between">
        <span className="readout flex items-center gap-2">
          <ArrowDown size={13} /> intake
        </span>
        <button
          onClick={() => replayRef.current()}
          className="flex items-center gap-1.5 rounded-full border border-ink-line bg-card px-3 py-1.5 text-[12px] font-medium text-ink-2 transition hover:border-blue/40 hover:text-blue"
        >
          <RotateCcw size={12} /> Replay
        </button>
      </div>

      <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-3 md:grid-cols-6">
        {BINS.map((bin) => {
          const files = FILES.filter((f) => f.bin === bin.key)
          return (
            <div
              key={bin.key}
              className="flex flex-col gap-1.5 rounded-2xl border border-ink-line bg-paper-deep/60 p-2.5"
            >
              <div className="flex items-center gap-1.5 px-0.5 pb-0.5">
                <span
                  className="flex h-5 w-5 items-center justify-center rounded-md"
                  style={{ backgroundColor: `${bin.tint}22`, color: bin.tint }}
                >
                  <Glyph icon={bin.icon} size={12} />
                </span>
                <span className="truncate text-[11.5px] font-semibold text-ink">{bin.folder}</span>
                <span className="ml-auto font-mono text-[10px] text-ink-3">{files.length}</span>
              </div>
              {files.map((f) => (
                <Chip key={f.name} name={f.name} ext={f.ext} tint={bin.tint} />
              ))}
            </div>
          )
        })}
      </div>
    </div>
  )
}

export function Intake() {
  return (
    <section id="top" className="relative overflow-hidden pt-[30px]">
      <div className="pointer-events-none absolute inset-0 -z-10 bg-grid opacity-50 mask-fade-y" />

      <div className="wrap pt-16 sm:pt-24">
        <span className="readout">macOS menu bar · files to your NAS</span>
        <h1 className="display mt-5 text-[clamp(2.9rem,9vw,7rem)] text-ink">
          Every download,
          <br />
          <span className="text-blue">filed on arrival.</span>
        </h1>
        <div className="mt-7 grid gap-x-10 gap-y-7 lg:grid-cols-[1.25fr_1fr] lg:items-end">
          <p className="max-w-xl text-pretty text-[18px] leading-relaxed text-ink-2">
            Porter is a menu-bar app that watches your folders and quietly files every finished
            download onto your NAS — Pictures, PDFs, Installers, the lot. It runs in your login
            session, so it works exactly where background scripts fail.
          </p>
          <div className="flex flex-col gap-3">
            <CopyCommand command={INSTALL.brewTap} />
            <div className="flex flex-wrap items-center gap-x-4 gap-y-2">
              <a href={INSTALL.dmgStable} className="btn-ink whitespace-nowrap">
                <Download size={17} /> Download for macOS
              </a>
              <span className="font-mono text-[11.5px] leading-tight text-ink-3">
                Apple Silicon
                <br />
                macOS 14+
              </span>
            </div>
          </div>
        </div>
      </div>

      <div className="wrap mt-14 pb-20 sm:mt-20">
        <IntakeBelt />
      </div>
    </section>
  )
}
