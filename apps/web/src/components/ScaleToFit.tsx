import { useLayoutEffect, useRef, useState, type ReactNode } from 'react'

/**
 * Scales a fixed-width child (a recreated macOS window) down to fit the available
 * width, and collapses the wrapper to the scaled height so nothing overflows on
 * mobile. At >= baseWidth it renders 1:1. Pure layout — no animation.
 */
export function ScaleToFit({
  baseWidth,
  children,
  className = '',
  padY = 14,
}: {
  baseWidth: number
  children: ReactNode
  className?: string
  padY?: number
}) {
  const wrapRef = useRef<HTMLDivElement>(null)
  const innerRef = useRef<HTMLDivElement>(null)
  const [scale, setScale] = useState(1)
  const [height, setHeight] = useState<number>()

  useLayoutEffect(() => {
    const wrap = wrapRef.current
    const inner = innerRef.current
    if (!wrap || !inner) return
    const measure = () => {
      const avail = wrap.clientWidth
      const s = Math.min(1, avail / baseWidth)
      setScale(s)
      setHeight(inner.offsetHeight * s + padY)
    }
    measure()
    const ro = new ResizeObserver(measure)
    ro.observe(wrap)
    ro.observe(inner)
    return () => ro.disconnect()
  }, [baseWidth, padY])

  return (
    <div ref={wrapRef} className={className} style={{ height }}>
      <div
        ref={innerRef}
        style={{ width: baseWidth, transform: `scale(${scale})`, transformOrigin: 'top left' }}
      >
        {children}
      </div>
    </div>
  )
}
