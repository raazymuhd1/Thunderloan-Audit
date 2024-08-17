### [H-1] Erroneous `ThunderLoan::updateExchangeRate` in the `deposit` function causes protocol to think it has more fees than it really does, which blocks redemptionp and incorrectly sets the exchange rate.

**Description** In the TunderLoan system, the `exchangeRate` is responsible for calculating the exchange rate between assetTokens and underlying tokens, In a way, it's responsible for keeping track of how many fees to give to liquidity providers.

However, the `deposit` function, updates this rate, without collecting any fees! 

```solidity
     function deposit(IERC20 token, uint256 amount) external revertIfZero(amount) revertIfNotAllowedToken(token) {
        AssetToken assetToken = s_tokenToAssetToken[token];
        uint256 exchangeRate = assetToken.getExchangeRate();
        uint256 mintAmount = (amount * assetToken.EXCHANGE_RATE_PRECISION()) / exchangeRate;
        emit Deposit(msg.sender, token, amount);
        assetToken.mint(msg.sender, mintAmount);
@>        uint256 calculatedFee = getCalculatedFee(token, amount);
@>        assetToken.updateExchangeRate(calculatedFee);
        token.safeTransferFrom(msg.sender, address(assetToken), amount);
    }
```

**Impact** There are several impacts to this bug.
    1. The `redeem` function is blocked, becaues the protocol thinks the owed tokens is more than it has.
    2. Rewards are incorrectly calculated, leading to liquidity providers potentially getting way more or less than deserved.

**Proof Of Concept**
    1. LP deposits
    2. User takes out a flashloan
    3. It is now impossible for LP to redeem.

 <details>
    <summary> Proof Of Code </summary>

    ```solidity
         function testRedeemAfterLoan() public setAllowedToken hasDeposits {
        uint256 amountToBorrow = AMOUNT * 10;
        uint256 calculatedFee = thunderLoan.getCalculatedFee(tokenA, amountToBorrow);
        vm.startPrank(user);
        tokenA.mint(address(mockFlashLoanReceiver), AMOUNT);
        thunderLoan.flashloan(address(mockFlashLoanReceiver), tokenA, amountToBorrow, "");
        vm.stopPrank();

        uint256 amountToRedeem = type(uint256).max;
        vm.startPrank(liquidityProvider);
        thunderLoan.redeem(tokenA, amountToRedeem);
    }
    ```
    
 </details>


**Recommended Mitigation** Removed the incorrectly updated exchange rate lines from `deposit`

```diff
     function deposit(IERC20 token, uint256 amount) external revertIfZero(amount) revertIfNotAllowedToken(token) {
        AssetToken assetToken = s_tokenToAssetToken[token];
        uint256 exchangeRate = assetToken.getExchangeRate();
        uint256 mintAmount = (amount * assetToken.EXCHANGE_RATE_PRECISION()) / exchangeRate;
        emit Deposit(msg.sender, token, amount);
        assetToken.mint(msg.sender, mintAmount);
        uint256 calculatedFee = getCalculatedFee(token, amount);
-        assetToken.updateExchangeRate(calculatedFee);
-        token.safeTransferFrom(msg.sender, address(assetToken), amount);
    }
```


### [M-1] Using TSwap as proce oracle leads to price and oracle manipulation attacks

**Description** The TSwap protocol is a constant product formula based AMM (automated market maker). The price of a token is determined by how many reserves are on either side of the pool. Because of this, it is easy for malicious users to manipulate the price if a token by buying  and selling a large amount of the token in the same transaction, essentially ignoring procotol fees.


**Impact** Liquidity providers will drastically reduced fees for providing liquidity.

**Proof Of Concept**

  The following all happens in 1 transaction.

  1. User takes a flash loan from `ThunderLoan` for 1000 `tokenA`. They are charged the original fee `fee1`. During the flashloan, they do the following:
     1. User sells 1000 `tokenA`, tanking the price.
     2. Instead of repaying right away, the user takes out another flashloan for another 1000 `tokenA`.
        1. Due to the fact that the way `ThunderLoan` calculates price based on the `TSwapPool` this second flashloan is substantially cheaper.

```solidity
    function getPriceInWeth(address token) public view returns(uint256) {
        address swapPoolOfToken = IPoolFactory(s_poolFactory).getPool(token);
@>        return ITSwapPool(swapPoolOfToken).getPriceOfOnePoolTokenInWeth();
    }

```

   3. The user then repays the first flashloan, and then repays the second flashloan.

 I have created a proof of code located in my `test/unit/ThunderLoanTest.t.sol` folder on a `ThunderLoanTest::testOraclePriceManipulation` function. It is too large to include here.

 **Recommended Mitigation** Consider using a different price oracle mechanism, like a chainlink price feed with a uniswap TWAP fallback oracle. 