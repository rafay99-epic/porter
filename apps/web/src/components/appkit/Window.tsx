import type { ReactNode } from 'react'

export function TrafficLights({ className = '' }: { className?: string }) {
  return (
    <div className={`flex items-center gap-2 ${className}`} aria-hidden="true">
      <span className="h-[12px] w-[12px] rounded-full bg-[#ff5f57] shadow-[inset_0_0_0_0.5px_rgba(0,0,0,0.14)]" />
      <span className="h-[12px] w-[12px] rounded-full bg-[#febc2e] shadow-[inset_0_0_0_0.5px_rgba(0,0,0,0.14)]" />
      <span className="h-[12px] w-[12px] rounded-full bg-[#28c840] shadow-[inset_0_0_0_0.5px_rgba(0,0,0,0.14)]" />
    </div>
  )
}

interface MacWindowProps {
  title?: string
  children: ReactNode
  className?: string
  bodyClassName?: string
}

export function MacWindow({ title, children, className = '', bodyClassName = '' }: MacWindowProps) {
  return (
    <div
      className={`sysfont w-fit max-w-full overflow-hidden rounded-[12px] border border-black/10 bg-[#f6f6f8] shadow-window ${className}`}
    >
      <div className="relative flex h-[38px] items-center border-b border-black/[0.07] bg-gradient-to-b from-[#fbfcfd] to-[#eef0f3] px-3.5">
        <TrafficLights />
        {title && (
          <div className="pointer-events-none absolute inset-0 flex items-center justify-center text-[12.5px] font-medium text-ink-2">
            {title}
          </div>
        )}
      </div>
      <div className={bodyClassName}>{children}</div>
    </div>
  )
}
