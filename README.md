## Hi there 👋

The migrate values in here are set for ethereum sepolia testnet deployments. Also unlock times
etc. For mainnet deployments you NEED to change them.

# Deployment & Configuration Guide

Before launching change the Uniswap addresses and WETH9 addresses to the desired chains in
factoryERC20.sol and pool.sol, then follow these steps to deploy and configure the protocol
components:


1. **Deploy the Factory contract**  
   
    ```solidity
    const factory = await Factory.deploy();
    await factory.deployed();
    ```

2. **Deploy the Pool contract** (constructor argument: Factory’s address)  
   
    ```solidity
    const pool = await ThePool.deploy(factory.address);
    await pool.deployed();
    ```

3. **Configure the Factory**  
   
    ```solidity
    await factory.setPoolAddress(pool.address);
    ```

4. *Optional.* **Deploy the Native token (LFGClubToken)** (args: name, symbol, metadataHash, factoryAddress, tokenId)  
   
    ```solidity
    const native = await LFGClubToken.deploy(
      "MyToken",
      "MTK",
      "<METADATA_HASH>",
      factory.address,
      tokenId
    );
    await native.deployed();
    ```

5. *Optional.* **Register the Native token** in the Factory  
   
    ```solidity
    await factory.setNative(native.address);
    ```

6. *Optional.* **Deploy the Depositor contract** (constructor argument: Factory’s address)  
   
    ```solidity
    const depositor = await depositor.deploy(factory.address);
    await depositor.deployed();
    ```

7. *Optional.* **Register the Depositor** in the Factory  
   
    ```solidity
    await factory.setDepositor(depositor.address);
    ```

8. *Optional.* **Approve the FeeOwner contract** to spend your Native token  
   
    ```solidity
    await native.approve(feeOwner.address, ethers.constants.MaxUint256);
    ```

9. *Optional.* **Add liquidity**  
   
    ```solidity
    await feeOwner.addLiquidity(...);
    ```

10. *Optional.* **Adjust fee distribution**  
   
    ```solidity
    await feeOwner.modifySplitting(newSplit);
    ```

Because of bytecode init restriction this needed to be splitted up like that.

Don't forget to install @openzeppelin/contracts (v5 is required) -- for example via npm

```bash
npm install @openzeppelin/contracts
```

# License

By deploying these contracts on any mainnet or production chain you agree
to the LFG Commercial License v1.0 (see LICENSE).
