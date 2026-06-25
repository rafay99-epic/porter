// Porter's brand marks — faithful to the app icon (Scripts/MakeIcon.swift):
// a blue squircle with the white "tray.and.arrow.down" glyph.

interface MarkProps {
  size?: number
  className?: string
}

export function PorterMark({ size = 40, className = '' }: MarkProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" className={className} role="img" aria-label="Porter">
      <defs>
        <linearGradient id="porterTile" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#4089fa" />
          <stop offset="1" stopColor="#1a5cdb" />
        </linearGradient>
        <linearGradient id="porterSheen" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#ffffff" stopOpacity="0.28" />
          <stop offset="0.5" stopColor="#ffffff" stopOpacity="0" />
        </linearGradient>
      </defs>
      <rect x="2" y="2" width="60" height="60" rx="15" fill="url(#porterTile)" />
      <rect x="2" y="2" width="60" height="30" rx="15" fill="url(#porterSheen)" />
      <g fill="none" stroke="#fff" strokeWidth="3.4" strokeLinecap="round" strokeLinejoin="round">
        <path d="M32 16 V31" />
        <path d="M25 26 L32 33 L39 26" />
        <path d="M16 38 V44 a3 3 0 0 0 3 3 H45 a3 3 0 0 0 3 -3 V38" />
        <path d="M16 38 H24 L27 42 H37 L40 38 H48" />
      </g>
    </svg>
  )
}

interface StrokeProps extends MarkProps {
  strokeWidth?: number
}

export function TrayArrowDown({ size = 18, className = '', strokeWidth = 1.7 }: StrokeProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      aria-hidden="true"
    >
      <path d="M12 4 v8.5" />
      <path d="M8.4 9.4 L12 13 L15.6 9.4" />
      <path d="M3.5 14 V18 a2 2 0 0 0 2 2 H18.5 a2 2 0 0 0 2 -2 V14" />
      <path d="M3.5 14 H8 L9.6 16.5 H14.4 L16 14 H20.5" />
    </svg>
  )
}

export function Viewfinder({ size = 16, className = '', strokeWidth = 1.7 }: StrokeProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      aria-hidden="true"
    >
      <path d="M4 8 V6 a2 2 0 0 1 2 -2 h2" />
      <path d="M16 4 h2 a2 2 0 0 1 2 2 v2" />
      <path d="M20 16 v2 a2 2 0 0 1 -2 2 h-2" />
      <path d="M8 20 H6 a2 2 0 0 1 -2 -2 v-2" />
      <circle cx="12" cy="12" r="3" />
    </svg>
  )
}

export function GithubMark({ size = 18, className = '' }: MarkProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" className={className} aria-hidden="true">
      <path d="M12 .5a11.5 11.5 0 0 0-3.64 22.41c.58.1.79-.25.79-.56v-2c-3.2.7-3.88-1.37-3.88-1.37-.53-1.34-1.3-1.7-1.3-1.7-1.06-.72.08-.71.08-.71 1.17.08 1.79 1.2 1.79 1.2 1.04 1.79 2.73 1.27 3.4.97.1-.76.41-1.27.74-1.56-2.55-.29-5.23-1.28-5.23-5.7 0-1.26.45-2.29 1.19-3.1-.12-.29-.52-1.46.11-3.05 0 0 .98-.31 3.2 1.18a11.1 11.1 0 0 1 5.83 0c2.22-1.49 3.2-1.18 3.2-1.18.63 1.59.23 2.76.11 3.05.74.81 1.19 1.84 1.19 3.1 0 4.43-2.69 5.41-5.25 5.69.42.36.79 1.08.79 2.18v3.23c0 .31.21.67.8.56A11.5 11.5 0 0 0 12 .5Z" />
    </svg>
  )
}
