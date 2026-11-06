import { ConnectKitButton } from 'connectkit'
import { Workspace } from './microcover/components/Workspace'
import './microcover/microcover.css'

export default function App() {
  return (
    <div style={{ minHeight: '100dvh', backgroundImage: 'var(--bg-gradient)' }}>
      <main className="mc-root">
        <div className="mc-stack">
          <header className="mc-header">
            <div>
              <h1 className="mc-title">MicroCover</h1>
              <p className="mc-subtitle">Programmable guarantees in USDC. Synthetic testnet demo on Arc Testnet.</p>
            </div>
            <ConnectKitButton label="Connect" />
          </header>
          <Workspace />
        </div>
      </main>
    </div>
  )
}
