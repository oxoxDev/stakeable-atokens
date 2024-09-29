# Staked ATokens

This repo contains the codebase of various variants of aTokens that can be staked across multiple contracts. Use-cases can be

1. Allows the protocol to stake the underlying asset to the staking contract and distribute the rewards accordingly
2. Allows the protocol to stake the underlying asset to a rewarsd contract

---

## Risks

Allowing the lending protocol to use it's underlying asset to deposit into another protocol significantly increases the counter-party risk of each asset and hence the choice of contracts
need to be taken with caution.
