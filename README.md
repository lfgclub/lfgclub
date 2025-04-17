## Hi there 👋

# Instructions


     0x3bdffc6186a60e7f32745b18531b4bd1646c28ce067781ecc948b7d4b9723ba5
    0, ["LFG Club", "LFG", "LFG Club Token", "https://ipfs.io/ipfs/bafkreicyc52rkzxuumzk3tgjjvnhs7ykfsp4wgvx6x6s5user6bcsfp3cq", "https://lfg.club", "https://x.com/LFGClubOfficial", "https://t.me/LFGClubPortal"]

* I N S T R U C T I O N S   F O R   L A U N C H
*
* (I) Launch Factory
* (II) Launch Native: "test.test token", "test", bytes 32: metahash, bytes32: ipfshash, factory address, tokenid: 0 // or via wormhole:
* "test.test token", "test", 0x206578616d706c00247765627369740040742e6d652f67002874776974746500, 0x9b325d8778b7a78e97adbdec5769b1a038e06500ce6353c4a1d16509f6bc0030, 0x66e19AfDAa1Bf405A15AD21816805A5D08E00666, 0
* (III) call setNative(address _address) on Factory {on mainnet this checks if factory in native is same as in this contract!}
* (III) Launch Staker: <factory address>
* (IV) we get staking address from factory -> call on factory: setStaker(address _address) [this checks if native address and factory address on staker are the same as in factory!]
* (V) native token on feeContract is set when we add liqudity

# License

By deploying these contracts on any mainnet or production chain you agree
to the LFG Commercial License v1.0 (see LICENSE).

<!--
**lfgclub/lfgclub** is a ✨ _special_ ✨ repository because its `README.md` (this file) appears on your GitHub profile.

Here are some ideas to get you started:

- 🔭 I’m currently working on ...
- 🌱 I’m currently learning ...
- 👯 I’m looking to collaborate on ...
- 🤔 I’m looking for help with ...
- 💬 Ask me about ...
- 📫 How to reach me: ...
- 😄 Pronouns: ...
- ⚡ Fun fact: ...
-->
