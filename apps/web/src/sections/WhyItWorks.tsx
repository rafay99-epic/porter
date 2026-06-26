import { WHY_REASONS } from '@porter/core'
import { ChapterHead, Reveal } from '../components/editorial'

export function WhyItWorks() {
  return (
    <section id="why" className="relative overflow-hidden bg-night py-28 text-night-ink sm:py-36">
      <div className="pointer-events-none absolute inset-0 opacity-60">
        <div className="absolute left-1/2 top-[-10%] h-[500px] w-[900px] -translate-x-1/2 rounded-full bg-blue-deep/25 blur-[140px]" />
      </div>
      <div
        className="pointer-events-none absolute inset-0 opacity-[0.07]"
        style={{
          backgroundImage:
            'linear-gradient(rgba(255,255,255,0.6) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.6) 1px, transparent 1px)',
          backgroundSize: '40px 40px',
        }}
      />
      <div className="wrap relative">
        <ChapterHead
          index="03"
          kicker="why it works"
          dark
          title={
            <>
              The obvious fix is
              <br />
              <span className="text-night-2">broken on macOS.</span>
            </>
          }
          lede="A launchd job moving files onto a Finder-mounted SMB share sounds right — and fails three independent ways. Porter is built as a real GUI-session app precisely so it doesn’t."
        />

        <div className="mt-16 space-y-px">
          {WHY_REASONS.map((r, i) => (
            <Reveal key={r.id} delay={i * 0.05}>
              <div className="grid gap-6 border-t border-night-line py-9 md:grid-cols-[auto_1fr_1fr] md:gap-12">
                <div className="flex items-baseline gap-4 md:block">
                  <span className="font-mono text-[14px] tabular-nums text-blue-200">
                    {String(i + 1).padStart(2, '0')}
                  </span>
                  <h3 className="display mt-0 text-[clamp(1.5rem,2.6vw,2rem)] leading-[1.05] text-night-ink md:mt-3 md:max-w-[10ch]">
                    {r.title}
                  </h3>
                </div>

                <div className="border-l border-night-line pl-5">
                  <div className="readout !text-bad/80">The script way</div>
                  <p className="mt-2 text-[15px] leading-relaxed text-night-2 line-through decoration-bad/40 decoration-1">
                    {r.fail}
                  </p>
                </div>

                <div className="border-l border-blue/40 pl-5">
                  <div className="readout !text-blue-200">Porter</div>
                  <p className="mt-2 text-[15px] leading-relaxed text-night-ink">{r.fix}</p>
                </div>
              </div>
            </Reveal>
          ))}
        </div>

        <Reveal className="mt-12">
          <p className="text-[15px] text-night-2">
            <span className="text-night-ink">🟢 watching</span> ·{' '}
            <span className="text-night-ink">🔵 sorting</span> ·{' '}
            <span className="text-night-ink">🟠 NAS offline</span> ·{' '}
            <span className="text-night-ink">🔴 needs access</span> — the menu-bar glyph is the
            whole status surface. No more silent failures.
          </p>
        </Reveal>
      </div>
    </section>
  )
}
