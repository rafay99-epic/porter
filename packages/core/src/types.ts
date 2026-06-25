// Pure, React-free domain types for Porter. Shared across the workspace so the
// website is typed end-to-end from the same definitions the app's behaviour
// mirrors (FileCategory, SortRule, PorterStatus, Channel).

/** A symbolic icon name. The web layer maps each to a concrete SVG. */
export type IconKey =
  // category glyphs
  | 'viewfinder'
  | 'image'
  | 'pdf'
  | 'document'
  | 'installer'
  | 'movie'
  | 'music'
  | 'archive'
  | 'folder'
  // status glyphs
  | 'tray'
  | 'sync'
  | 'check'
  | 'drive'
  | 'pause'
  | 'shield'
  | 'warning'

/** The nine destination categories (PorterCore/Models/FileCategory.swift). */
export type CategoryKey =
  | 'screenshots'
  | 'pictures'
  | 'pdfs'
  | 'documents'
  | 'installers'
  | 'movies'
  | 'music'
  | 'archives'
  | 'other'

export interface FileCategory {
  readonly key: CategoryKey
  /** Folder name created on the NAS (FileCategory.folderName). */
  readonly folder: string
  readonly label: string
  readonly icon: IconKey
  /** Website-only tint for chips; the app renders these monochrome. */
  readonly tint: string
  /** Representative extensions / name patterns this category catches. */
  readonly extensions: readonly string[]
}

/** PorterStatus cases (SortCoordinator.swift) + statusColor (StatusViews.swift). */
export type StatusKey =
  | 'idle'
  | 'syncing'
  | 'sorted'
  | 'paused'
  | 'suspended'
  | 'needsPermission'
  | 'error'

export interface StatusMeta {
  readonly key: StatusKey
  readonly title: string
  readonly color: string
  readonly icon: IconKey
  readonly spin?: boolean
}

/** ConflictPolicy (SortRule.swift). */
export type ConflictPolicyKey = 'rename' | 'skip' | 'overwrite' | 'keepNewer'

export interface ConflictPolicyMeta {
  readonly key: ConflictPolicyKey
  readonly label: string
  readonly hint: string
}

/** A human-readable summary of one built-in SortRule (RuleMatch.summary). */
export interface SortRuleSummary {
  readonly match: string
  readonly dest: string
  readonly kind: 'name' | 'ext' | 'any'
}

export interface ActivityItem {
  readonly name: string
  readonly dest: string
  readonly size?: string
  readonly when?: string
}

export interface DemoFile {
  readonly name: string
  readonly dest: string
  readonly size: string
}

export interface InstallInfo {
  readonly repo: string
  readonly brewTap: string
  readonly dmgStable: string
  readonly dmgNightly: string
  readonly releases: string
  readonly requirement: string
}

export interface CategoryStat {
  readonly folder: string
  readonly count: number
}

export interface Stats {
  readonly totals: {
    readonly files: number
    readonly space: string
    readonly categories: number
  }
  readonly perDay: readonly number[]
  readonly byCategory: readonly CategoryStat[]
}

export interface Author {
  readonly org: string
  readonly name: string
  readonly url: string
}
