import { TokenUSDC } from '@web3icons/react'
import { Badge, Card, Dl, Row } from './Card'
import { EXAMPLE, exampleAmounts } from '../example'

const amounts = exampleAmounts(EXAMPLE)

export function ExampleCard() {
  return (
    <Card title="How the guarantee works" aside={<Badge>Synthetic demo</Badge>}>
      <p className="mc-p">{EXAMPLE.scenario}</p>
      <p className="mc-mt-3" style={{ display: 'flex', alignItems: 'center', flexWrap: 'wrap', gap: 8, margin: '12px 0 0' }}>
        <span className="display" style={{ fontSize: 40, fontWeight: 600, lineHeight: 1 }}>
          {amounts.totalLocked}
        </span>
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontWeight: 600 }}>
          <TokenUSDC variant="branded" size={18} /> USDC held when the cohort is full
        </span>
      </p>
      <Dl>
        <Row label="Provider bond">{amounts.bond} USDC</Row>
        <Row label="Escrow from a full cohort">
          {amounts.perEscrow} x {amounts.cohort} = {amounts.totalEscrow} USDC
        </Row>
        <Row label="Fixed compensation on failure">{amounts.perCompensation} USDC each</Row>
        <Row label="Cohort bound">{amounts.cohort} beneficiaries</Row>
      </Dl>
      <p className="mc-hint">
        On failure each beneficiary gets their escrow back plus the compensation, from the provider&apos;s bond. On success the demo operator proposes it, a review window lets beneficiaries dispute, and after it ends the escrow goes to the provider and the provider withdraws the bond. Testnet only; synthetic.
      </p>
    </Card>
  )
}
