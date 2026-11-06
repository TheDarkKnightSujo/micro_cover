/**
 * Arc Testnet is the only chain MicroCover supports, so it is the only chain defined here.
 *
 * This replaces `getChain` from `@circlefin/compass-chains`, which is not published to the
 * public npm registry. Values follow Arc's official network reference
 * (https://docs.arc.io/arc/references/connect-to-arc.md): chain id 5042002, native gas token
 * USDC, explorer https://explorer.testnet.arc.io.
 *
 * Any other chain is rejected explicitly by `assertArcTestnetOnly` and `getChain`.
 */
export interface LocalChainDefinition {
  name: string;
  chainId: number;
  explorerUrl: string;
  nativeCurrency: { symbol: string };
}

export const ARC_TESTNET_CIRCLE_BLOCKCHAIN = 'ARC-TESTNET';
export const ARC_TESTNET_COMPASS_CHAIN = 'Arc_Testnet';

const ARC_TESTNET: LocalChainDefinition = {
  name: 'Arc Testnet',
  chainId: 5042002,
  explorerUrl: 'https://explorer.testnet.arc.io',
  nativeCurrency: { symbol: 'USDC' },
};

export function getChain(id: string): LocalChainDefinition {
  if (id !== ARC_TESTNET_COMPASS_CHAIN) {
    throw new Error(
      `Unsupported --compass-chain "${id}". MicroCover deploys to Arc Testnet only (--compass-chain ${ARC_TESTNET_COMPASS_CHAIN}).`,
    );
  }
  return ARC_TESTNET;
}

/** Throws unless both flags name Arc Testnet. Call before any RPC resolution or signing. */
export function assertArcTestnetOnly(blockchain: string, compassChain: string): void {
  if (blockchain !== ARC_TESTNET_CIRCLE_BLOCKCHAIN) {
    throw new Error(
      `Unsupported --blockchain "${blockchain}". MicroCover deploys to Arc Testnet only (--blockchain ${ARC_TESTNET_CIRCLE_BLOCKCHAIN}).`,
    );
  }
  getChain(compassChain);
}
