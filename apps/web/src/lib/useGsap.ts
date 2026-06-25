import { useLayoutEffect, useRef, type DependencyList, type RefObject } from 'react'
import { gsap } from './gsap'

/**
 * Runs `setup` inside a `gsap.context()` scoped to the returned element ref, so
 * every tween/ScrollTrigger created in it is reverted automatically on unmount
 * or when `deps` change. The standard, leak-free way to use GSAP in React.
 */
export function useGsap<T extends HTMLElement = HTMLDivElement>(
  setup: (self: T) => void,
  deps: DependencyList = [],
): RefObject<T | null> {
  const ref = useRef<T>(null)
  useLayoutEffect(() => {
    const el = ref.current
    if (!el) return
    const ctx = gsap.context(() => setup(el), el)
    return () => ctx.revert()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps)
  return ref
}
