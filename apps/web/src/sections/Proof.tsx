import { STATS, SAMPLE_ACTIVITY } from '@porter/core'
import { MacWindow } from '../components/appkit/Window'
import { Dashboard } from '../components/appkit/Dashboard'
import { StatsWindow } from '../components/appkit/StatsWindow'
import { ScaleToFit } from '../components/ScaleToFit'
import { ChapterHead, Reveal, CountUp } from '../components/editorial'

const FIGURES = [
  { to: STATS.totals.files, format: (v: number) => Math.round(v).toLocaleString(), label: 'files filed' },
  { to: 47.2, format: (v: number) => `${v.toFixed(1)} GB`, label: 'space moved' },
  { to: STATS.totals.categories, format: (v: number) => String(Math.round(v)), label: 'destinations' },
]

export function Proof() {
  return (
    <section id="proof" className="relative overflow-hidden py-28 sm:py-36">
      <div className="wrap">
        <ChapterHead
          index="05"
          kicker="proof, not promises"
          title={
            <>
              It keeps the receipts.
            </>
          }
          lede="Every move is logged, counted, and charted across launches — so you can actually see the chaos it’s quietly absorbing."
        />

        {/* big editorial figures */}
        <div className="mt-14 grid gap-8 border-y border-ink/15 py-10 sm:grid-cols-3">
          {FIGURES.map((f, i) => (
            <Reveal key={f.label} delay={i * 0.08}>
              <div>
                <div className="display text-[clamp(3rem,7vw,5.5rem)] leading-none text-ink">
                  <CountUp to={f.to} format={f.format} />
                </div>
                <div className="readout mt-3">{f.label}</div>
              </div>
            </Reveal>
          ))}
        </div>

        {/* the recreated windows, as evidence */}
        <div className="relative mt-16 lg:mt-20 lg:min-h-[640px]">
          <Reveal className="relative z-10 lg:max-w-[560px]">
            <ScaleToFit baseWidth={542} className="rotate-[-1.2deg]">
              <MacWindow title="Porter">
                <Dashboard activity={SAMPLE_ACTIVITY.slice(0, 5)} status="sorted" />
              </MacWindow>
            </ScaleToFit>
          </Reveal>
          <Reveal
            className="relative z-20 mt-8 lg:absolute lg:right-0 lg:top-24 lg:mt-0 lg:w-[560px]"
            delay={0.12}
          >
            <ScaleToFit baseWidth={542} className="rotate-[1.6deg]">
              <MacWindow title="Statistics">
                <StatsWindow />
              </MacWindow>
            </ScaleToFit>
          </Reveal>
        </div>
      </div>
    </section>
  )
}
