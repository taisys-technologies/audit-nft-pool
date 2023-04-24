# Audit NFT Pool

## Description

This contract is part of a bridge system for NFTs. The system comprises several contracts, along with an oracle:

- NFT (ETH chain)
- NFTPool (ETH chain)
- NFT Metadata contract (Home chain)

To use an NFT on our home chain, the user must first "lock" it, which transfers it to NFTPool. Next, the oracle will receive the ERC721 transfer event and update the metadata contract with the NFT's information. When the user "unlocks" the NFT, the oracle will receive an unlock event from the metadata contract and call the `transferERC721` function to transfer the NFT back.

## Test

### Setup

```bash
npm install
```

### Run

```bash
# run all tests
npx hardhat test

# run single test
npx hardhat test ${TEST_FILE_PATH}

# run tests with coverage report
npx hardhat coverage
```

## Static Analysis

- [Slither Github](https://github.com/crytic/slither)

```bash
slither .
```
