import { CATEGORIES } from '@porter/core'
import { Glyph } from '../components/Glyph'
import { ChapterHead, Reveal } from '../components/editorial'

const EXTS: Record<string, string> = {
  screenshots: 'Screenshot · Screen Shot',
  pictures: 'jpg png heic webp svg raw tiff gif',
  pdfs: 'pdf',
  documents: 'docx xlsx pptx md csv txt pages key',
  installers: 'dmg pkg iso mpkg',
  movies: 'mp4 mov mkv webm avi m4v wmv',
  music: 'mp3 m4a wav flac aac ogg aiff',
  archives: 'zip tar gz tgz 7z rar xz zst',
  other: 'everything else',
}

export function Destinations() {
  return (
    <section id="destinations" className="relative bg-paper-deep/40 py-28 sm:py-36">
      <div className="pointer-events-none absolute inset-0 bg-dots opacity-40" />
      <div className="wrap relative">
        <div className="flex flex-wrap items-end justify-between gap-6">
          <ChapterHead
            index="02"
            kicker="it knows where things go"
            title={
              <>
                Nine destinations,
                <br />
                resolved on sight.
              </>
            }
          />
          <Reveal>
            <p className="max-w-xs text-[15px] leading-relaxed text-ink-2">
              Classified by name first, then extension. Existing folders match
              case-insensitively, so <span className="font-mono text-[13px]">documents/</span> is
              never duplicated as <span className="font-mono text-[13px]">Documents/</span>.
            </p>
          </Reveal>
        </div>

        {/* the ledger */}
        <div className="mt-14 border-t border-ink/15">
          {CATEGORIES.map((c, i) => (
            <Reveal key={c.key} delay={i * 0.04}>
              <div className="group grid grid-cols-[auto_1fr_auto] items-center gap-4 border-b border-ink-line py-5 transition-colors hover:bg-card sm:grid-cols-[3rem_minmax(0,12rem)_1fr_auto] sm:gap-6 sm:px-3">
                <span className="hidden font-mono text-[13px] tabular-nums text-ink-3 sm:block">
                  {String(i + 1).padStart(2, '0')}
                </span>
                <div className="flex items-center gap-3">
                  <span
                    className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg transition-transform group-hover:scale-110"
                    style={{ backgroundColor: `${c.tint}1f`, color: c.tint }}
                  >
                    <Glyph icon={c.icon} size={18} />
                  </span>
                  <span className="display text-[clamp(1.4rem,2.6vw,2.1rem)] tracking-tight text-ink">
                    {c.folder}
                  </span>
                </div>
                <span className="col-span-2 truncate font-mono text-[12.5px] text-ink-3 sm:col-span-1 sm:text-right md:text-left">
                  {EXTS[c.key]}
                </span>
                <span className="hidden font-mono text-[12px] text-ink-3 sm:block">→ NAS</span>
              </div>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  )
}
