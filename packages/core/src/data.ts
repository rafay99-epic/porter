import type {
  ActivityItem,
  Author,
  CategoryKey,
  ConflictPolicyMeta,
  DemoFile,
  FileCategory,
  InstallInfo,
  SortRuleSummary,
  Stats,
  StatusKey,
  StatusMeta,
} from './types'

export const REPO = 'https://github.com/rafay99-epic/porter'

export const AUTHOR: Author = {
  org: 'Syntax Lab Technology',
  name: 'Abdul Rafay',
  url: 'https://rafay99.com',
}

export const INSTALL: InstallInfo = {
  repo: REPO,
  brewTap: 'brew install --cask rafay99-epic/tap/porter',
  dmgStable: `${REPO}/releases/latest/download/Porter.dmg`,
  dmgNightly: `${REPO}/releases/latest/download/Porter-Nightly.dmg`,
  releases: `${REPO}/releases`,
  requirement: 'Apple Silicon · macOS 14 Sonoma or later',
}

// The nine destinations, in the app's own order (FileCategory.allCases).
export const CATEGORIES: readonly FileCategory[] = [
  { key: 'screenshots', folder: 'screenshots', label: 'Screenshots', icon: 'viewfinder', tint: '#e8833a', extensions: ['Screenshot…', 'Screen Shot…'] },
  { key: 'pictures', folder: 'Pictures', label: 'Pictures', icon: 'image', tint: '#2fa463', extensions: ['jpg', 'png', 'heic', 'webp', 'svg', 'raw', 'tiff', 'gif'] },
  { key: 'pdfs', folder: 'PDFs', label: 'PDFs', icon: 'pdf', tint: '#d8453a', extensions: ['pdf'] },
  { key: 'documents', folder: 'Documents', label: 'Documents', icon: 'document', tint: '#1f6ef0', extensions: ['docx', 'xlsx', 'pptx', 'md', 'csv', 'txt', 'pages', 'key'] },
  { key: 'installers', folder: 'Installers', label: 'Installers', icon: 'installer', tint: '#5b97fb', extensions: ['dmg', 'pkg', 'iso', 'mpkg'] },
  { key: 'movies', folder: 'Movies', label: 'Movies', icon: 'movie', tint: '#9b51e0', extensions: ['mp4', 'mov', 'mkv', 'webm', 'avi', 'm4v', 'wmv'] },
  { key: 'music', folder: 'Music', label: 'Music', icon: 'music', tint: '#e0457b', extensions: ['mp3', 'm4a', 'wav', 'flac', 'aac', 'ogg', 'aiff'] },
  { key: 'archives', folder: 'Archives', label: 'Archives', icon: 'archive', tint: '#7d8694', extensions: ['zip', 'tar', 'gz', '7z', 'rar', 'xz', 'zst'] },
  { key: 'other', folder: 'Other', label: 'Other', icon: 'folder', tint: '#5b6472', extensions: ['everything else'] },
]

// The catch-all ("Other") — guaranteed present, used as the resolution fallback.
const OTHER: FileCategory = CATEGORIES[CATEGORIES.length - 1]!

const CATEGORY_BY_FOLDER: ReadonlyMap<string, FileCategory> = new Map(
  CATEGORIES.map((c) => [c.folder.toLowerCase(), c]),
)

/** Resolve a destination folder (possibly nested) to a category, case-insensitively. */
export function categoryByFolder(folder: string): FileCategory {
  const top = (folder || '').split('/')[0]?.toLowerCase() ?? ''
  return CATEGORY_BY_FOLDER.get(top) ?? OTHER
}

export function categoryByKey(key: CategoryKey): FileCategory {
  return CATEGORIES.find((c) => c.key === key) ?? OTHER
}

// PorterStatus titles + colors, keyed for the website. `sorted` title is suffixed
// with a count by the UI.
export const STATUS: Readonly<Record<StatusKey, StatusMeta>> = {
  idle: { key: 'idle', title: 'Watching for new files', color: '#34c759', icon: 'tray' },
  syncing: { key: 'syncing', title: 'Sorting…', color: '#0a84ff', icon: 'sync', spin: true },
  sorted: { key: 'sorted', title: 'Sorted', color: '#34c759', icon: 'check' },
  paused: { key: 'paused', title: 'NAS not mounted', color: '#ff9f0a', icon: 'drive' },
  suspended: { key: 'suspended', title: 'Sorting paused', color: '#8e8e93', icon: 'pause' },
  needsPermission: { key: 'needsPermission', title: 'Needs file access', color: '#ff453a', icon: 'shield' },
  error: { key: 'error', title: 'Last sweep had failures', color: '#ff453a', icon: 'warning' },
}

// The built-in rule set, verbatim from SortRule.defaults.
export const DEFAULT_RULES: readonly SortRuleSummary[] = [
  { match: 'name starts with “Screenshot ”', dest: 'screenshots', kind: 'name' },
  { match: 'name starts with “Screen Shot ”', dest: 'screenshots', kind: 'name' },
  { match: '.jpg .jpeg .png .gif .webp .heic .svg .raw', dest: 'Pictures', kind: 'ext' },
  { match: '.pdf', dest: 'PDFs', kind: 'ext' },
  { match: '.docx .xlsx .pptx .md .csv .pages .key', dest: 'Documents', kind: 'ext' },
  { match: '.dmg .pkg .iso .mpkg', dest: 'Installers', kind: 'ext' },
  { match: '.mp4 .mov .mkv .webm .m4v .wmv', dest: 'Movies', kind: 'ext' },
  { match: '.mp3 .m4a .wav .flac .aac .aiff', dest: 'Music', kind: 'ext' },
  { match: '.zip .tar .gz .7z .rar .xz .zst', dest: 'Archives', kind: 'ext' },
  { match: 'anything else', dest: 'Other', kind: 'any' },
]

// The RuleMatch condition kinds the engine supports.
export const RULE_CONDITIONS: readonly string[] = [
  'extensions', 'name starts with', 'name ends with', 'name contains',
  'regex', 'larger than', 'smaller than', 'older than', 'newer than',
  'kind is', 'AND', 'OR',
]

export const CONFLICT_POLICIES: readonly ConflictPolicyMeta[] = [
  { key: 'rename', label: 'Keep both', hint: 'adds a “ (1)” suffix' },
  { key: 'skip', label: 'Skip', hint: 'leave it in place' },
  { key: 'overwrite', label: 'Overwrite', hint: 'replace the destination' },
  { key: 'keepNewer', label: 'Keep newer', hint: 'overwrite only if newer' },
]

export const WATCHED_FOLDERS: readonly string[] = ['Downloads', 'Desktop', 'AirDrop']

// A believable scatter of finished downloads — the "before" state, and the
// activity log's contents.
export const SAMPLE_ACTIVITY: readonly ActivityItem[] = [
  { name: 'Invoice-April-2026.pdf', dest: 'PDFs', size: '184 KB', when: '2:41 PM' },
  { name: 'Screenshot 2026-06-26 at 14.02.11.png', dest: 'screenshots', size: '1.2 MB', when: '2:38 PM' },
  { name: 'Ableton-Live-12.dmg', dest: 'Installers', size: '612 MB', when: '2:31 PM' },
  { name: 'q2-forecast.xlsx', dest: 'Documents', size: '88 KB', when: '2:24 PM' },
  { name: 'drone-cut-final.mov', dest: 'Movies', size: '2.4 GB', when: '1:55 PM' },
  { name: 'reference-pack.zip', dest: 'Archives', size: '341 MB', when: '1:50 PM' },
  { name: 'liner-notes.flac', dest: 'Music', size: '32 MB', when: '1:42 PM' },
  { name: 'holiday-2025.heic', dest: 'Pictures', size: '4.1 MB', when: '1:30 PM' },
]

export const DEMO_FILES: readonly DemoFile[] = [
  { name: 'Screenshot 2026-06-26 at 14.02.11.png', dest: 'screenshots', size: '1.2 MB' },
  { name: 'Invoice-April-2026.pdf', dest: 'PDFs', size: '184 KB' },
  { name: 'Ableton-Live-12.dmg', dest: 'Installers', size: '612 MB' },
  { name: 'q2-forecast.xlsx', dest: 'Documents', size: '88 KB' },
]

export const STATS: Stats = {
  totals: { files: 1284, space: '47.2 GB', categories: 9 },
  perDay: [4, 9, 6, 12, 3, 0, 7, 14, 8, 5, 11, 9, 2, 6, 13, 7, 4, 10, 8, 15, 6, 9, 3, 12, 7, 5, 11, 8, 6, 9],
  byCategory: [
    { folder: 'Documents', count: 312 },
    { folder: 'Pictures', count: 248 },
    { folder: 'PDFs', count: 196 },
    { folder: 'screenshots', count: 174 },
    { folder: 'Archives', count: 121 },
    { folder: 'Installers', count: 98 },
    { folder: 'Movies', count: 67 },
    { folder: 'Music', count: 51 },
    { folder: 'Other', count: 17 },
  ],
}

// The three reasons the naïve launchd approach fails (CLAUDE.md / README).
export interface FailureReason {
  readonly id: string
  readonly title: string
  readonly fail: string
  readonly fix: string
}

export const WHY_REASONS: readonly FailureReason[] = [
  {
    id: 'smb',
    title: 'SMB writes that land',
    fail: 'macOS scopes SMB write access to the GUI session that mounted the share. A launchd-spawned script can read /Volumes — its writes silently fail.',
    fix: 'Porter runs as a real login-item app inside your Aqua session (SMAppService.mainApp), so every write to the NAS succeeds.',
  },
  {
    id: 'watch',
    title: 'A watcher that never sleeps',
    fail: "launchd's WatchPaths quietly goes dead and StartInterval gets throttled for long stretches. Files pile up unnoticed.",
    fix: 'Porter watches in-process with FSEvents plus a 60-second safety heartbeat — no LaunchAgent, no missed triggers.',
  },
  {
    id: 'tcc',
    title: 'Permission that survives updates',
    fail: 'TCC blocks a background script from even reading ~/Downloads, and the grant is bound to /bin/bash + the script’s mtime — so it breaks on every edit.',
    fix: "Full Disk Access attaches to Porter's signed identity. Grant it once; it holds across every update.",
  },
]
