import { useState } from 'react'
import { Copy, Check } from 'lucide-react'

interface CopyCommandProps {
  command: string
  className?: string
  tone?: 'paper' | 'dark'
}

export function CopyCommand({ command, className = '', tone = 'paper' }: CopyCommandProps) {
  const [copied, setCopied] = useState(false)

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(command)
      setCopied(true)
      window.setTimeout(() => setCopied(false), 1600)
    } catch {
      /* clipboard blocked */
    }
  }

  const dark = tone === 'dark'
  return (
    <button
      onClick={copy}
      className={`group flex w-full items-center gap-3 rounded-xl border px-4 py-3 text-left font-mono text-[13.5px] transition ${
        dark
          ? 'border-night-line bg-white/[0.05] text-night-ink hover:bg-white/[0.09]'
          : 'border-ink-line bg-card text-ink shadow-lift hover:border-blue/40'
      } ${className}`}
      aria-label={`Copy command: ${command}`}
    >
      <span className={dark ? 'text-blue-200' : 'text-blue'}>$</span>
      <span className="min-w-0 flex-1 truncate">{command}</span>
      <span
        className={`flex items-center gap-1.5 font-sans text-[12px] font-medium ${
          copied ? 'text-ok' : dark ? 'text-night-2' : 'text-ink-3'
        }`}
      >
        {copied ? <Check size={15} /> : <Copy size={15} />}
        <span className="hidden sm:inline">{copied ? 'Copied' : 'Copy'}</span>
      </span>
    </button>
  )
}
