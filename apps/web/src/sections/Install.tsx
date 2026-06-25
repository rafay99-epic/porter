import { useState } from 'react'
import { INSTALL } from '@porter/core'
import { Download, ArrowUpRight, TerminalSquare, ShieldCheck, FolderInput } from 'lucide-react'
import { CopyCommand } from '../components/CopyCommand'
import { PorterMark } from '../components/brand'
import { ChapterHead, Reveal } from '../components/editorial'

const STEPS = [
  { Icon: TerminalSquare, head: 'Install it', body: 'One Homebrew command, or drag Porter.app from the DMG into Applications.' },
  { Icon: ShieldCheck, head: 'Grant Full Disk Access', body: 'A one-time grant, tied to the signed app — it survives every update.' },
  { Icon: FolderInput, head: 'Point it at your NAS', body: 'Mount your SMB share, pick the folders to watch, and Porter takes over.' },
]

export function Install() {
  const [tab, setTab] = useState<'brew' | 'dmg'>('brew')
  return (
    <section id="install" className="relative bg-paper-deep/50 py-28 sm:py-36">
      <div className="pointer-events-none absolute inset-0 bg-grid opacity-40 mask-fade-y" />
      <div className="wrap relative">
        <ChapterHead
          index="06"
          kicker="bring it home"
          title={
            <>
              Up and running
              <br />
              <span className="text-blue">in a minute.</span>
            </>
          }
          lede="Apple Silicon · macOS 14 Sonoma or later. Free and open source under GPL-3.0."
        />

        <Reveal className="mt-14">
          <div className="overflow-hidden rounded-3xl border border-ink-line bg-card shadow-window">
            <div className="flex flex-wrap items-center gap-3 border-b border-ink-line bg-paper/60 px-6 py-5">
              <PorterMark size={40} />
              <div>
                <div className="text-[16px] font-semibold text-ink">Get Porter</div>
                <div className="text-[12.5px] text-ink-2">Stable channel · auto-updates</div>
              </div>
              <div className="ml-auto inline-flex gap-1 rounded-xl bg-paper-deep p-1">
                {(['brew', 'dmg'] as const).map((t) => (
                  <button
                    key={t}
                    onClick={() => setTab(t)}
                    className={`rounded-lg px-4 py-1.5 text-[13px] font-semibold transition ${
                      tab === t ? 'bg-card text-ink shadow-sm' : 'text-ink-2 hover:text-ink'
                    }`}
                  >
                    {t === 'brew' ? 'Homebrew' : 'Download'}
                  </button>
                ))}
              </div>
            </div>

            <div className="p-6">
              {tab === 'brew' ? (
                <div className="space-y-3">
                  <CopyCommand command={INSTALL.brewTap} />
                  <p className="text-[13.5px] leading-relaxed text-ink-2">
                    Installs the cask from the{' '}
                    <span className="font-mono text-[12px] text-ink">rafay99-epic/tap</span> tap.
                    Homebrew keeps it updated with the rest of your tooling.
                  </p>
                </div>
              ) : (
                <div className="space-y-3">
                  <a
                    href={INSTALL.dmgStable}
                    className="flex items-center justify-center gap-2 rounded-xl bg-ink px-5 py-3.5 text-[15px] font-semibold text-paper transition hover:bg-black"
                  >
                    <Download size={18} /> Download Porter.dmg
                  </a>
                  <p className="text-[13.5px] leading-relaxed text-ink-2">
                    Signed &amp; notarized. Open it and drag{' '}
                    <span className="font-mono text-[12px] text-ink">Porter.app</span> into
                    Applications.
                  </p>
                </div>
              )}

              <div className="mt-6 grid gap-px border-t border-ink-line pt-6 sm:grid-cols-3">
                {STEPS.map((s, i) => (
                  <div key={s.head} className="flex gap-3 sm:px-3 sm:first:pl-0">
                    <span className="font-mono text-[13px] tabular-nums text-blue">0{i + 1}</span>
                    <div>
                      <div className="flex items-center gap-2">
                        <s.Icon size={15} className="text-ink-2" />
                        <h3 className="text-[14.5px] font-semibold text-ink">{s.head}</h3>
                      </div>
                      <p className="mt-1 text-[13px] leading-relaxed text-ink-2">{s.body}</p>
                    </div>
                  </div>
                ))}
              </div>

              <div className="mt-6 flex flex-wrap items-center gap-x-6 gap-y-2 border-t border-ink-line pt-5 text-[13px]">
                <a
                  href={INSTALL.dmgNightly}
                  className="inline-flex items-center gap-1.5 font-medium text-ink-2 transition hover:text-blue"
                >
                  <span className="h-2 w-2 rounded-full bg-warn" /> Nightly channel <ArrowUpRight size={14} />
                </a>
                <a
                  href={INSTALL.releases}
                  className="inline-flex items-center gap-1 font-medium text-ink-2 transition hover:text-blue"
                >
                  All releases <ArrowUpRight size={14} />
                </a>
              </div>
            </div>
          </div>
        </Reveal>
      </div>
    </section>
  )
}
