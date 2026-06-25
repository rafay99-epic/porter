import { MenuBarPanel } from '../components/appkit/MenuBarPanel'
import { ScaleToFit } from '../components/ScaleToFit'
import { ChapterHead, Reveal } from '../components/editorial'
import { SAMPLE_ACTIVITY } from '@porter/core'

const FACTS = [
  {
    n: '01',
    head: 'In-process — never a daemon',
    body: 'The watcher runs inside the app with FSEvents, backed by a 60-second safety heartbeat. There’s no LaunchAgent to quietly go dead.',
  },
  {
    n: '02',
    head: 'It waits for the write to finish',
    body: 'A configurable settle delay (5–120s) means Porter never grabs a file that’s still downloading. It moves only once the bytes have stopped.',
  },
  {
    n: '03',
    head: 'Mount-aware, always',
    body: 'When the NAS isn’t mounted it pauses and leaves everything in place — then resumes the instant the share is back. One click to mount.',
  },
]

export function Watch() {
  return (
    <section id="watch" className="relative py-28 sm:py-36">
      <div className="wrap">
        <ChapterHead
          index="01"
          kicker="it watches"
          title={
            <>
              Always on. <span className="text-ink-3">Never in the way.</span>
            </>
          }
          lede="Porter lives in your menu bar — a single glyph that tells you, at a glance, exactly what it’s doing. Watching, sorting, paused, or asking for access. No silent failures."
        />

        <div className="mt-16 grid items-center gap-12 lg:grid-cols-[minmax(0,360px)_1fr]">
          <Reveal>
            <div className="relative">
              <div className="absolute -inset-6 -z-10 rounded-[28px] bg-blue-soft/70 blur-2xl" />
              <ScaleToFit baseWidth={322} className="rotate-[-1.4deg]">
                <MenuBarPanel
                  status="idle"
                  activity={SAMPLE_ACTIVITY.slice(0, 5).map((e, i) => ({ ...e, id: `w-${i}` }))}
                  onUndo={() => {}}
                />
              </ScaleToFit>
            </div>
          </Reveal>

          <ol className="space-y-px">
            {FACTS.map((f, i) => (
              <Reveal key={f.n} delay={i * 0.06}>
                <li className="flex gap-5 border-t border-ink-line py-6">
                  <span className="font-mono text-[13px] tabular-nums text-blue">{f.n}</span>
                  <div>
                    <h3 className="text-[20px] font-semibold tracking-tight text-ink">{f.head}</h3>
                    <p className="mt-1.5 max-w-md text-[15px] leading-relaxed text-ink-2">
                      {f.body}
                    </p>
                  </div>
                </li>
              </Reveal>
            ))}
          </ol>
        </div>
      </div>
    </section>
  )
}
