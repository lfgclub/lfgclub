## Hi there 👋

The migrate values in here are set for ethereum sepolia testnet deployments. Also unlock times etc. For
mainnet deployments you NEED to change them.

# Instructions

Before launching change the Uniswap addresses and WETH9 addresses to the desired chains, then:

1. Launch Factory
2. Launch Pool Contract with factory as constructor argument
3. Call setPoolAddress(poolAddress) on Factory.
4. Launch Native (LFGClubToken) with: "name", "symbol", "metadatahash", "factory_address", "tokenId"
5. Call setNative(nativeAddress) on Factory.
6. Launch Depositor with the factory address as constructor.
7. Call on Factory: setDepositor(depositorAddress).
8. Approve feeOwner Contract for spending on native token
9. Call addLiquidity on feeOwner Contract.
10. Call on feeOwner modifySplitting if you want to split with depositors.

You can skip 4 to 10 if you don't want a native token nor a depositor contract.

Because of bytecode init restriction this needed to be splitted up like that.

Don't forget to install @openzeppelin/contracts -- for example via npm (you need it as v5)

```
npm install @openzeppelin/contracts
```

# License

By deploying these contracts on any mainnet or production chain you agree
to the LFG Commercial License v1.0 (see LICENSE).
