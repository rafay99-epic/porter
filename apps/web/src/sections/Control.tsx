import { Fingerprint, MoonStar, Undo2, Hourglass } from 'lucide-react'
import { MacWindow } from '../components/appkit/Window'
import { RulesPanel } from '../components/appkit/RulesPanel'
import { PreviewWindow } from '../components/appkit/PreviewWindow'
import { ScaleToFit } from '../components/ScaleToFit'
import { ChapterHead, Reveal } from '../components/editorial'

const ALSO = [
  {
    Icon: Undo2,
    label: 'Undo',
    body: 'Hover any move in the log and send it straight back where it came from.',
  },
  {
    Icon: Fingerprint,
    label: 'Integrity',
    body: 'Per-copy checksum verification and duplicate skipping — nothing corrupted or filed twice.',
  },
  {
    Icon: MoonStar,
    label: 'Quiet hours',
    body: 'Pause sorting on a daily window — overnight, say — and it resumes by itself. Midnight-crossing is fine.',
  },
  {
    Icon: Hourglass,
    label: 'Settle delay',
    body: 'A 5–120s wait so a file still being written is never moved mid-download.',
  },
]

export function Control() {
  return (
    <section id="control" className="relative py-28 sm:py-36">
      <div className="wrap">
        <ChapterHead
          index="04"
          kicker="you stay in control"
          title={
            <>
              Tidy by default.
              <br />
              <span className="text-ink-3">Exact when you want it.</span>
            </>
          }
          lede="Out of the box Porter mirrors a battle-tested sort script. Underneath sits a real rules engine and a dry-run preview — so no move is ever a surprise."
        />

        {/* two product spotlights, deliberately offset — not a grid */}
        <div className="mt-16 grid gap-12 lg:grid-cols-12 lg:gap-8">
          <Reveal className="lg:col-span-7">
            <div className="readout mb-4">A real rules engine</div>
            <ScaleToFit baseWidth={462} className="rotate-[-1deg]">
              <MacWindow title="Settings — Rules">
                <RulesPanel />
              </MacWindow>
            </ScaleToFit>
            <p className="mt-8 max-w-md text-[15px] leading-relaxed text-ink-2">
              Match by extension, name, regex, size, age, or file kind — combine with{' '}
              <span className="font-medium text-ink">AND</span> /{' '}
              <span className="font-medium text-ink">OR</span>, and choose how a name clash resolves,
              per rule. Rules run in order; the first match wins.
            </p>
          </Reveal>

          <Reveal className="lg:col-span-5 lg:pt-24" delay={0.1}>
            <div className="readout mb-4">Dry-run preview</div>
            <ScaleToFit baseWidth={462} className="rotate-[1.4deg]">
              <MacWindow title="Preview">
                <PreviewWindow />
              </MacWindow>
            </ScaleToFit>
            <p className="mt-8 max-w-md text-[15px] leading-relaxed text-ink-2">
              See exactly what the next sweep would move, grouped by destination, before a single
              byte is touched.
            </p>
          </Reveal>
        </div>

        {/* the "and also" spec row — editorial, not cards */}
        <div className="mt-20 grid gap-px border-t border-ink/15 sm:grid-cols-2 lg:grid-cols-4">
          {ALSO.map((a, i) => (
            <Reveal key={a.label} delay={i * 0.05}>
              <div className="border-b border-ink-line py-7 sm:pr-6">
                <a.Icon size={20} className="text-blue" />
                <h3 className="mt-4 text-[16px] font-semibold text-ink">{a.label}</h3>
                <p className="mt-1.5 text-[14px] leading-relaxed text-ink-2">{a.body}</p>
              </div>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  )
}
