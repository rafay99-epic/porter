import type { ReactNode } from 'react'
import { gsap, prefersReducedMotion } from '../lib/gsap'
import { useGsap } from '../lib/useGsap'

/** Fade-and-rise into view on scroll. The page's one consistent reveal. */
export function Reveal({
  children,
  className = '',
  y = 26,
  delay = 0,
}: {
  children: ReactNode
  className?: string
  y?: number
  delay?: number
}) {
  const ref = useGsap<HTMLDivElement>((el) => {
    if (prefersReducedMotion()) {
      gsap.set(el, { opacity: 1 })
      return
    }
    gsap.from(el, {
      y,
      opacity: 0,
      duration: 0.85,
      ease: 'power3.out',
      delay,
      scrollTrigger: { trigger: el, start: 'top 86%' },
    })
  })
  return (
    <div ref={ref} className={className}>
      {children}
    </div>
  )
}

/** Counts a number up from zero when it scrolls into view. */
export function CountUp({
  to,
  format,
  className = '',
}: {
  to: number
  format: (v: number) => string
  className?: string
}) {
  const ref = useGsap<HTMLSpanElement>((el) => {
    if (prefersReducedMotion()) {
      el.textContent = format(to)
      return
    }
    const obj = { v: 0 }
    el.textContent = format(0)
    gsap.to(obj, {
      v: to,
      duration: 1.5,
      ease: 'power2.out',
      scrollTrigger: { trigger: el, start: 'top 92%' },
      onUpdate() {
        el.textContent = format(obj.v)
      },
    })
  })
  return <span ref={ref} className={className} />
}

/** A monospace chapter index + kicker — the editorial system's section marker. */
export function Kicker({ index, children }: { index: string; children: ReactNode }) {
  return (
    <div className="flex items-center gap-3">
      <span className="font-mono text-[12px] font-medium tabular-nums text-blue">{index}</span>
      <span className="h-px w-8 bg-ink-line" />
      <span className="readout">{children}</span>
    </div>
  )
}

interface ChapterHeadProps {
  index: string
  kicker: string
  title: ReactNode
  lede?: ReactNode
  dark?: boolean
  className?: string
}

export function ChapterHead({
  index,
  kicker,
  title,
  lede,
  dark = false,
  className = '',
}: ChapterHeadProps) {
  return (
    <Reveal className={className}>
      <Kicker index={index}>{kicker}</Kicker>
      <h2
        className={`display mt-5 max-w-[15ch] text-[clamp(2.2rem,5.2vw,4.2rem)] ${
          dark ? 'text-night-ink' : 'text-ink'
        }`}
      >
        {title}
      </h2>
      {lede && (
        <p
          className={`mt-5 max-w-2xl text-pretty text-[18px] leading-relaxed ${
            dark ? 'text-night-2' : 'text-ink-2'
          }`}
        >
          {lede}
        </p>
      )}
    </Reveal>
  )
}
