import { useEffect, useState } from 'react'
import type { StatusKey } from '@porter/core'

/**
 * Drives the menu-bar's Porter status icon from scroll position: whichever
 * `[data-status]` section is nearest the top third of the viewport wins. Makes
 * the site's chrome behave like the real app as you move through the story.
 */
export function useScrollStatus(initial: StatusKey): StatusKey {
  const [status, setStatus] = useState<StatusKey>(initial)

  useEffect(() => {
    let raf = 0
    const update = () => {
      cancelAnimationFrame(raf)
      raf = requestAnimationFrame(() => {
        const els = Array.from(document.querySelectorAll<HTMLElement>('[data-status]'))
        const mark = window.innerHeight * 0.35
        let best: { d: number; s: StatusKey } | null = null
        for (const el of els) {
          const r = el.getBoundingClientRect()
          if (r.bottom < 0 || r.top > window.innerHeight) continue
          const d = Math.abs(r.top - mark)
          const s = el.dataset.status as StatusKey | undefined
          if (s && (!best || d < best.d)) best = { d, s }
        }
        if (best) setStatus(best.s)
      })
    }
    update()
    window.addEventListener('scroll', update, { passive: true })
    window.addEventListener('resize', update)
    return () => {
      cancelAnimationFrame(raf)
      window.removeEventListener('scroll', update)
      window.removeEventListener('resize', update)
    }
  }, [])

  return status
}
