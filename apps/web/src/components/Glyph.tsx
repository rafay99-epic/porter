import type { ComponentType } from 'react'
import type { IconKey } from '@porter/core'
import {
  Image,
  FileText,
  FileType,
  Package,
  Film,
  Music,
  Archive,
  Folder,
  RefreshCw,
  CheckCircle2,
  HardDrive,
  PauseCircle,
  ShieldAlert,
  AlertTriangle,
  type LucideProps,
} from 'lucide-react'
import { TrayArrowDown, Viewfinder } from './brand'

type GlyphComponent = ComponentType<{ size?: number; className?: string; strokeWidth?: number }>

const lucide = (C: ComponentType<LucideProps>): GlyphComponent =>
  function Wrapped({ size = 16, className, strokeWidth = 1.7 }) {
    return <C size={size} className={className} strokeWidth={strokeWidth} />
  }

const REGISTRY: Record<IconKey, GlyphComponent> = {
  viewfinder: Viewfinder,
  image: lucide(Image),
  pdf: lucide(FileText),
  document: lucide(FileType),
  installer: lucide(Package),
  movie: lucide(Film),
  music: lucide(Music),
  archive: lucide(Archive),
  folder: lucide(Folder),
  tray: TrayArrowDown,
  sync: lucide(RefreshCw),
  check: lucide(CheckCircle2),
  drive: lucide(HardDrive),
  pause: lucide(PauseCircle),
  shield: lucide(ShieldAlert),
  warning: lucide(AlertTriangle),
}

interface GlyphProps {
  icon: IconKey
  size?: number
  className?: string
  strokeWidth?: number
}

export function Glyph({ icon, size = 16, className, strokeWidth }: GlyphProps) {
  const C = REGISTRY[icon]
  return <C size={size} className={className} strokeWidth={strokeWidth} />
}
