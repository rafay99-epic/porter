import { REPO, INSTALL, AUTHOR } from '@porter/core'
import { PorterMark, GithubMark } from '../components/brand'

const COLUMNS = [
  {
    title: 'The story',
    links: [
      { label: 'It watches', href: '#watch' },
      { label: 'Destinations', href: '#destinations' },
      { label: 'Why it works', href: '#why' },
      { label: 'Control', href: '#control' },
    ],
  },
  {
    title: 'Get it',
    links: [
      { label: 'Porter for macOS', href: INSTALL.dmgStable },
      { label: 'Nightly channel', href: INSTALL.dmgNightly },
      { label: 'All releases', href: INSTALL.releases, external: true },
    ],
  },
  {
    title: 'Project',
    links: [
      { label: 'Source on GitHub', href: REPO, external: true },
      { label: 'License (GPL-3.0)', href: `${REPO}/blob/main/LICENSE`, external: true },
      { label: AUTHOR.url.replace('https://', ''), href: AUTHOR.url, external: true },
    ],
  },
]

export function Colophon() {
  return (
    <footer className="border-t border-ink/15 bg-paper">
      {/* a final, oversized sign-off */}
      <div className="wrap py-20">
        <p className="display max-w-[14ch] text-[clamp(2.4rem,6vw,4.5rem)] text-ink">
          Stop sorting <span className="text-blue">downloads.</span>
        </p>
        <div className="mt-16 grid gap-10 lg:grid-cols-[1.5fr_1fr_1fr_1fr]">
          <div className="max-w-xs">
            <div className="flex items-center gap-2.5">
              <PorterMark size={26} />
              <span className="text-[18px] font-bold tracking-tight text-ink">Porter</span>
            </div>
            <p className="mt-4 text-[14px] leading-relaxed text-ink-2">
              A menu-bar app that files every finished download onto your NAS — reliably, where
              background scripts can’t.
            </p>
            <a
              href={REPO}
              target="_blank"
              rel="noreferrer"
              className="mt-5 inline-flex h-9 w-9 items-center justify-center rounded-full border border-ink-line bg-card text-ink-2 transition hover:text-ink"
              aria-label="Porter on GitHub"
            >
              <GithubMark size={17} />
            </a>
          </div>

          {COLUMNS.map((col) => (
            <div key={col.title}>
              <h4 className="readout">{col.title}</h4>
              <ul className="mt-4 space-y-2.5">
                {col.links.map((l) => (
                  <li key={l.label}>
                    <a
                      href={l.href}
                      {...('external' in l && l.external ? { target: '_blank', rel: 'noreferrer' } : {})}
                      className="text-[14px] text-ink-2 transition hover:text-blue"
                    >
                      {l.label}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        <div className="mt-14 flex flex-col items-start justify-between gap-3 border-t border-ink-line pt-6 text-[13px] text-ink-3 sm:flex-row sm:items-center">
          <p>
            © {AUTHOR.org} ·{' '}
            <a href={AUTHOR.url} target="_blank" rel="noreferrer" className="hover:text-ink">
              {AUTHOR.name}
            </a>
            . Licensed under GPL-3.0.
          </p>
          <p className="font-mono text-[12px] text-ink-3">macOS 14+ · Apple Silicon</p>
        </div>
      </div>
    </footer>
  )
}
