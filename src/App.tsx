import { useEffect, useState } from 'react'
import { ConcertPage } from './microcover/components/ConcertPage'
import { ConnectKitButton } from 'connectkit'
import { Workspace } from './microcover/components/Workspace'
import './microcover/microcover.css'

export default function App() {
  const [concert,setConcert]=useState(()=>window.location.hash==='#concert')
  useEffect(()=>{const sync=()=>setConcert(window.location.hash==='#concert');window.addEventListener('hashchange',sync);window.addEventListener('popstate',sync);return()=>{window.removeEventListener('hashchange',sync);window.removeEventListener('popstate',sync)}},[])
  return (
    <div style={{ minHeight: '100dvh', backgroundImage: 'var(--bg-gradient)' }}>
      <main className="mc-root">
        <div className="mc-stack">
          <header className="mc-header">
            <div>
              <div className="mc-brand"><span className="mc-brand-mark">m</span><h1 className="mc-title">MicroCover</h1></div>
              <p className="mc-subtitle">Promises backed. Payments protected.</p>
            </div>
            <ConnectKitButton label="Connect wallet" />
          </header>
          {concert?<ConcertPage/>:<><a className="mc-concert-entry" href="#concert">Explore the concert demo →</a><Workspace/></>}
        </div>
      </main>
    </div>
  )
}
