// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import "ds-test/test.sol";

import "../lib/Address.sol";
import "../lib/MockToken.sol";

import "../lib/SqrtMath.sol";

import "@uniswap-v3-core/contracts/libraries/TickMath.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";

contract LiquidityProvider_NewTest is DSTest {
    using TickMath for int24;

    INonfungiblePositionManager nfpm =
        INonfungiblePositionManager(Address.UNIV3_POS_MANAGER);
    ISwapRouter v3router = ISwapRouter(Address.UNIV3_ROUTER);
    IUniswapV3Factory v3Factory = IUniswapV3Factory(Address.UNIV3_FACTORY);
    IUniswapV3Pool pool;

    MockToken token0;
    MockToken token1;

    uint24 constant fee = 3000;
    int24 tickSpacing;

    function setUp() public {
        token0 = new MockToken();
        token1 = new MockToken();

        if (address(token0) > address(token1)) {
            address temp = address(token0);
            token0 = token1;
            token1 = MockToken(temp);
        }

        // Creates the new pool
        pool = IUniswapV3Pool(
            v3Factory.createPool(address(token0), address(token1), fee)
        );

        /*
            Calculates the initial price (in sqrtPriceX96 format)

            https://docs.uniswap.org/sdk/guides/fetching-prices

            sqrtPriceX96 = sqrt(price) * 2 ** 96
        */

        // Lets set the price to be 1000 token0 = 1 token1
        uint160 sqrtPriceX96 = encodePriceSqrt(1, 1000);
        pool.initialize(sqrtPriceX96);

        tickSpacing = pool.tickSpacing();
    }

    /// @notice Adds liquidity at current spot price -/+ tickSpacing
    function test_addLiquidity_new() public {
        // Get tick spacing
        (, int24 curTick, , , , , ) = pool.slot0();
        curTick = curTick - (curTick % tickSpacing);

        int24 lowerTick = curTick - (tickSpacing * 2);
        int24 upperTick = curTick + (tickSpacing * 2);

        // We know that we need ~ 1 token0 for every 1000 token1
        token0.mint(address(this), 1000e18);
        token0.approve(address(nfpm), uint256(-1));

        token1.mint(address(this), 1e18);
        token1.approve(address(nfpm), uint256(-1));

        nfpm.mint(
            INonfungiblePositionManager.MintParams({
                token0: pool.token0(),
                token1: pool.token1(),
                fee: fee,
                tickLower: lowerTick,
                tickUpper: upperTick,
                amount0Desired: 1000e18,
                amount1Desired: 1e18,
                amount0Min: 0e18,
                amount1Min: 0e18,
                recipient: address(this),
                deadline: block.timestamp
            })
        );

        assertEq(token0.balanceOf(address(this)), 0);
        assertLt(token1.balanceOf(address(this)), 1e18);
    }
}
