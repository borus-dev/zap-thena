# Grizzly Thena Zap

This repository contains the contracts for a simple Thena Zap.

## What you'll find here

- `ZapThena`

```JavaScript
    function zapInETH(
        address grizzlyVault,
        uint256 tokenAmountOutMin,
        bytes32 referral
    ) external payable {
```

```JavaScript
    function zapIn(
        address grizzlyVault,
        uint256 tokenAmountOutMin,
        address tokenIn,
        uint256 tokenInAmount,
        bytes32 referral
    ) external {
```

```JavaScript
    function zapOutAndSwap(
        address grizzlyVault,
        uint256 withdrawAmount,
        address desiredToken,
        uint256 desiredTokenOutMin
    ) external {
```

```JavaScript
    function zapOut(address grizzlyVault, uint256 withdrawAmount) external {
```

## Basic Use

Steps for Common Repo usage

```
cd zap-thena
```

```
yarn
```

## Installation

To install Hardhat, go to an empty folder, initialize an `npm` project (i.e. `npm init`), and run

```
npm install --save-dev hardhat
```

Once it's installed, just run this command and follow its instructions:

```
npx hardhat
```

## Testing

To run the tests:

```
npx hardhat test
```

or for a specific test

```
npx hardhat test tests/<test>.ts
```
