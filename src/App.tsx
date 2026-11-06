import { ConnectKitButton } from 'connectkit'
import { ExampleCard } from './microcover/components/ExampleCard'
import { NetworkCard } from './microcover/components/NetworkCard'
import { Workspace } from './microcover/components/Workspace'

export default function App() {
  return (
    <div className="min-h-dvh bg-[image:var(--bg-gradient)] text-[var(--ink)]">
      <main className="mx-auto flex w-full max-w-xl flex-col gap-4 px-4 pb-24 pt-8">
        <header className="flex items-center justify-between gap-3">
          <div>
            <h1 className="display text-3xl font-semibold text-balance">MicroCover</h1>
            <p className="text-sm text-[var(--muted)]">Programmable guarantees in USDC. Testnet demo.</p>
          </div>
          <ConnectKitButton label="Connect" />
        </header>

        <ExampleCard />
        <Workspace />
        <NetworkCard />
      </main>
    </div>
  )
}
