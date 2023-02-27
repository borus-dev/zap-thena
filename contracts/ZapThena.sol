// SPDX-License-Identifier: AGPL-3.0

import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router01.sol";

import "./libraries/LowGasSafeMath.sol";
import "./libraries/Babylonian.sol";
import "./libraries/SafeERC20.sol";

pragma solidity >=0.7.0;

interface IERC20Extended {
    function decimals() external view returns (uint256);
}

interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 wad) external;
}

interface IVault is IERC20 {
    function deposit(uint256) external;

    function deposit(uint256 amount, address recipient) external returns (uint256);

    function deposit(
        uint256 amount,
        address recipient,
        bytes32 referral
    ) external returns (uint256);

    function withdraw(uint256) external;

    function withdraw(uint256 maxShares, address recipient) external returns (uint256);

    function withdraw(
        uint256 maxShares,
        address recipient,
        uint256 maxLoss,
        address endRecipient
    ) external returns (uint256);

    function getPricePerFullShare() external view returns (uint256);

    function token() external view returns (address);

    function decimals() external view returns (uint256);

    // V2
    function pricePerShare() external view returns (uint256);
}

contract ZapThena {
    using LowGasSafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IVault;

    IUniswapRouterSolidly public immutable router;
    address public immutable WETH = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    uint256 public constant minimumAmount = 1000;

    constructor() {
        router = IUniswapRouterSolidly(0x20a304a7d126758dfe6B243D0fc515F83bCA8431);
    }

    receive() external payable {
        assert(msg.sender == WETH);
    }

    function zapInETH(
        address grizzlyVault,
        uint256 tokenAmountOutMin,
        bytes32 referral
    ) external payable {
        require(msg.value >= minimumAmount, "Insignificant input amount");

        IWETH(WETH).deposit{value: msg.value}();

        _swapAndStake(grizzlyVault, tokenAmountOutMin, WETH, referral);
    }

    function zapIn(
        address grizzlyVault,
        uint256 tokenAmountOutMin,
        address tokenIn,
        uint256 tokenInAmount,
        bytes32 referral
    ) external {
        require(tokenInAmount >= minimumAmount, "Insignificant input amount");
        require(
            IERC20(tokenIn).allowance(msg.sender, address(this)) >= tokenInAmount,
            "Input token is not approved"
        );

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), tokenInAmount);

        _swapAndStake(grizzlyVault, tokenAmountOutMin, tokenIn, referral);
    }

    function zapOut(address grizzlyVault, uint256 withdrawAmount) external {
        (IVault vault, IUniswapV2Pair pair) = _getVaultPair(grizzlyVault);

        IERC20(grizzlyVault).safeTransferFrom(msg.sender, address(this), withdrawAmount);
        vault.withdraw(withdrawAmount);

        if (pair.token0() != WETH && pair.token1() != WETH) {
            return _removeLiquidity(address(pair), msg.sender);
        }

        _removeLiquidity(address(pair), address(this));

        address[] memory tokens = new address[](2);
        tokens[0] = pair.token0();
        tokens[1] = pair.token1();

        _returnAssets(tokens);
    }

    function zapOutAndSwap(
        address grizzlyVault,
        uint256 withdrawAmount,
        address desiredToken,
        uint256 desiredTokenOutMin
    ) external {
        (IVault vault, IUniswapV2Pair pair) = _getVaultPair(grizzlyVault);
        address token0 = pair.token0();
        address token1 = pair.token1();
        require(
            token0 == desiredToken || token1 == desiredToken,
            "desired token not present in liquidity pair"
        );

        vault.safeTransferFrom(msg.sender, address(this), withdrawAmount);
        vault.withdraw(withdrawAmount);
        _removeLiquidity(address(pair), address(this));

        address swapToken = token1 == desiredToken ? token0 : token1;
        address[] memory path = new address[](2);
        path[0] = swapToken;
        path[1] = desiredToken;

        _approveTokenIfNeeded(path[0], address(router));
        router.swapExactTokensForTokensSimple(
            IERC20(swapToken).balanceOf(address(this)),
            desiredTokenOutMin,
            path[0],
            path[1],
            pair.stable(),
            address(this),
            block.timestamp
        );

        _returnAssets(path);
    }

    function _removeLiquidity(address pair, address to) private {
        IERC20(pair).safeTransfer(pair, IERC20(pair).balanceOf(address(this)));
        (uint256 amount0, uint256 amount1) = IUniswapV2Pair(pair).burn(to);

        require(amount0 >= minimumAmount, "UniswapV2Router: INSUFFICIENT_A_AMOUNT");
        require(amount1 >= minimumAmount, "UniswapV2Router: INSUFFICIENT_B_AMOUNT");
    }

    function _getVaultPair(address grizzlyVault) private view returns (IVault vault, IUniswapV2Pair pair) {
        vault = IVault(grizzlyVault);
        pair = IUniswapV2Pair(vault.token());
    }

    function _swapAndStake(
        address grizzlyVault,
        uint256 tokenAmountOutMin,
        address tokenIn,
        bytes32 referral
    ) private {
        (IVault vault, IUniswapV2Pair pair) = _getVaultPair(grizzlyVault);

        (uint256 reserveA, uint256 reserveB, ) = pair.getReserves();
        require(reserveA > minimumAmount && reserveB > minimumAmount, "Liquidity pair reserves too low");

        bool isInputA = pair.token0() == tokenIn;
        require(isInputA || pair.token1() == tokenIn, "Input token not present in liquidity pair");

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = isInputA ? pair.token1() : pair.token0();

        uint256 fullInvestment = IERC20(tokenIn).balanceOf(address(this));
        uint256 swapAmountIn;
        if (isInputA) {
            swapAmountIn = _getSwapAmount(pair, fullInvestment, reserveA, reserveB, path[0], path[1]);
        } else {
            swapAmountIn = _getSwapAmount(pair, fullInvestment, reserveB, reserveA, path[0], path[1]);
        }

        _approveTokenIfNeeded(path[0], address(router));
        uint256[] memory swapedAmounts = router.swapExactTokensForTokensSimple(
            swapAmountIn,
            tokenAmountOutMin,
            path[0],
            path[1],
            pair.stable(),
            address(this),
            block.timestamp
        );

        _approveTokenIfNeeded(path[1], address(router));
        (, , uint256 amountLiquidity) = router.addLiquidity(
            path[0],
            path[1],
            pair.stable(),
            fullInvestment.sub(swapedAmounts[0]),
            swapedAmounts[1],
            1,
            1,
            address(this),
            block.timestamp
        );

        _approveTokenIfNeeded(address(pair), address(vault));
        vault.deposit(amountLiquidity, address(this), referral);

        vault.safeTransfer(msg.sender, vault.balanceOf(address(this)));
        _returnAssets(path);
    }

    function _returnAssets(address[] memory tokens) private {
        uint256 balance;
        for (uint256 i; i < tokens.length; i++) {
            balance = IERC20(tokens[i]).balanceOf(address(this));
            if (balance > 0) {
                if (tokens[i] == WETH) {
                    IWETH(WETH).withdraw(balance);
                    (bool success, ) = msg.sender.call{value: balance}(new bytes(0));
                    require(success, "ETH transfer failed");
                } else {
                    IERC20(tokens[i]).safeTransfer(msg.sender, balance);
                }
            }
        }
    }

    function _getSwapAmount(
        IUniswapV2Pair pair,
        uint256 investmentA,
        uint256 reserveA,
        uint256 reserveB,
        address tokenA,
        address tokenB
    ) private view returns (uint256 swapAmount) {
        uint256 halfInvestment = investmentA / 2;

        if (pair.stable()) {
            swapAmount = _getStableSwap(pair, investmentA, halfInvestment, tokenA, tokenB);
        } else {
            uint256 nominator = pair.getAmountOut(halfInvestment, tokenA);
            uint256 denominator = (halfInvestment * reserveB.sub(nominator)) / reserveA.add(halfInvestment);
            swapAmount = investmentA.sub(
                Babylonian.sqrt((halfInvestment * halfInvestment * nominator) / denominator)
            );
        }
    }

    function _getStableSwap(
        IUniswapV2Pair pair,
        uint256 investmentA,
        uint256 halfInvestment,
        address tokenA,
        address tokenB
    ) private view returns (uint256 swapAmount) {
        uint out = pair.getAmountOut(halfInvestment, tokenA);
        (uint amountA, uint amountB, ) = router.quoteAddLiquidity(
            tokenA,
            tokenB,
            pair.stable(),
            halfInvestment,
            out
        );

        amountA = (amountA * 1e18) / 10**IERC20Extended(tokenA).decimals();
        amountB = (amountB * 1e18) / 10**IERC20Extended(tokenB).decimals();
        out = (out * 1e18) / 10**IERC20Extended(tokenB).decimals();
        halfInvestment = (halfInvestment * 1e18) / 10**IERC20Extended(tokenA).decimals();

        uint ratio = (((out * 1e18) / halfInvestment) * amountA) / amountB;

        return (investmentA * 1e18) / (ratio + 1e18);
    }

    function estimateSwap(
        address grizzlyVault,
        address tokenIn,
        uint256 fullInvestmentIn
    )
        public
        view
        returns (
            uint256 swapAmountIn,
            uint256 swapAmountOut,
            address swapTokenOut
        )
    {
        checkWETH();
        (, IUniswapV2Pair pair) = _getVaultPair(grizzlyVault);

        bool isInputA = pair.token0() == tokenIn;
        require(isInputA || pair.token1() == tokenIn, "Input token not present in liquidity pair");

        (uint256 reserveA, uint256 reserveB, ) = pair.getReserves();
        (reserveA, reserveB) = isInputA ? (reserveA, reserveB) : (reserveB, reserveA);

        swapTokenOut = isInputA ? pair.token1() : pair.token0();
        swapAmountIn = _getSwapAmount(pair, fullInvestmentIn, reserveA, reserveB, tokenIn, swapTokenOut);
        swapAmountOut = pair.getAmountOut(swapAmountIn, tokenIn);
    }

    function checkWETH() public view returns (bool isValid) {
        isValid = WETH == router.weth();
        require(isValid, "WETH address not matching Router.weth()");
    }

    function _approveTokenIfNeeded(address token, address spender) private {
        if (IERC20(token).allowance(address(this), spender) == 0) {
            IERC20(token).safeApprove(spender, type(uint256).max);
        }
    }
}
