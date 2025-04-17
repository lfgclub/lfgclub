## Hi there 👋

The migrate values in here are set for ethereum sepolia testnet deployments. Also unlock times etc.

# Instructions

Before launching change the Uniswap addresses and WETH9 addresses to the desired chains, then:

1. Launch Factory
2. Launch Native (LFGClubToken) with: "name", "symbol", "metadatahash", "factory_address", "tokenId"
3. Call setNative(nativeAddress) on Factory.
4. Launch Depositor with the factory address as constructor.
5. Call on Factory: setDepositor(depositorAddress).
6. Approve feeOwner Contract for spending on native token
7. Call addLiquidity on feeOwner Contract.
8. Call on feeOwner modifySplitting if you want to split with depositors.

You can skip 2 to 8 if you don't want a native token nor a depositor contract.

# License

By deploying these contracts on any mainnet or production chain you agree
to the LFG Commercial License v1.0 (see LICENSE).
