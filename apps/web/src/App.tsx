import { MenuBar } from './components/MenuBar'
import { useScrollStatus } from './lib/useScrollStatus'
import { Intake } from './sections/Intake'
import { Watch } from './sections/Watch'
import { Destinations } from './sections/Destinations'
import { WhyItWorks } from './sections/WhyItWorks'
import { Control } from './sections/Control'
import { Proof } from './sections/Proof'
import { Install } from './sections/Install'
import { Colophon } from './sections/Colophon'

export default function App() {
  const status = useScrollStatus('idle')
  return (
    <>
      <MenuBar status={status} />
      <main>
        <div data-status="idle"><Intake /></div>
        <div data-status="idle"><Watch /></div>
        <div data-status="syncing"><Destinations /></div>
        <div data-status="idle"><WhyItWorks /></div>
        <div data-status="syncing"><Control /></div>
        <div data-status="sorted"><Proof /></div>
        <div data-status="idle"><Install /></div>
      </main>
      <Colophon />
    </>
  )
}
