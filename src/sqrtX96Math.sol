// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./FullMath.sol";

library SqrtX96Math {
    // @dev    see https://github.com/Uniswap/v4-core/blob/main/src/libraries/FixedPoint96.sol
    uint256 internal constant Q96 = 0x1000000000000000000000000;

    // @dev    Calculation of the square rote price * 2^96
    function getSqrtPriceX96(uint256 amount0, uint256 amount1) public pure returns (uint160) {
        require(amount0 > 0, "Error: amount0 must be over 0");
        require(amount1 > 0, "Error: amount1 must be over 0");

        // @dev    We normalize the amounts with 1e15 to prevent overflows.
        uint256 amount00 = amount0 / 1e15;
        uint256 amount11 = amount1 / 1e15;

        uint256 ratio = (amount11 << 192) / amount00;
        uint256 sqrtPrice = sqrt(ratio);

        return uint160(sqrtPrice);
    }

    // @dev    Babylonian method for calculation of a square root
    function sqrt(uint256 b) internal pure returns (uint256 c) {
        if (b > 3) {
            uint256 a = b / 2 + 1;
            c = b; 
            while (a < c) {
                c = a;
                a = (b / a + a) / 2;
            }
        } else if (b != 0) {
            c = 1;
        }
    }

    // @dev    see https://github.com/Uniswap/v4-core/blob/main/src/libraries/TickMath.sol
    // @dev    Calculated directly to make it easier for us.
    function getSqrtX96ForMinMaxTicks(uint256 maxTick) internal pure returns (uint160 lowerX96, uint160 upperX96) {
        if (maxTick == 887200) {
            lowerX96 = 4310618291;
            upperX96 = 1456195216239875923660968522684675790921166487552;
        } else if (maxTick == 887220) {
            lowerX96 = 4306310043;
            upperX96 = 1457652066918736003311195112902404148109990952960;
        } else if (maxTick == 887250) {
            lowerX96 = 4299855742;
            upperX96 = 1459840076217215014784942191280287875428834607104;
        } else {
            revert("Error: Invalid tick provided for X96 math.");
        }
    }

    // @note   V4 pools will be activated as standard as soon as
    // @note   dex screeners support them widely, as they are
    // @note   way more gas friendly.

    // @dev    The following 3 functions are for calculation of the liquidity which we will add.
    // @dev    see https://github.com/Uniswap/v4-periphery/blob/main/src/libraries/LiquidityAmounts.sol

    function getLiquidityForAmount0(uint160 sqrtPriceLower, uint160 sqrtPriceUpper, uint256 amount0) internal pure returns (uint128 liquidity) {
        if (sqrtPriceLower > sqrtPriceUpper) (sqrtPriceLower, sqrtPriceUpper) = (sqrtPriceUpper, sqrtPriceLower);
        unchecked {
            if (sqrtPriceLower > sqrtPriceUpper) (sqrtPriceLower, sqrtPriceUpper) = (sqrtPriceUpper, sqrtPriceLower);
            uint256 intermediate = FullMath.mulDiv(sqrtPriceLower, sqrtPriceUpper, Q96);
            liquidity = uint128(FullMath.mulDiv(amount0, intermediate, sqrtPriceUpper - sqrtPriceLower));
        }
    }

    function getLiquidityForAmount1(uint160 sqrtPriceLower, uint160 sqrtPriceUpper, uint256 amount1) internal pure returns (uint128 liquidity) {
       unchecked {
            if (sqrtPriceLower > sqrtPriceUpper) (sqrtPriceLower, sqrtPriceUpper) = (sqrtPriceUpper, sqrtPriceLower);
            liquidity = uint128(FullMath.mulDiv(amount1, Q96, sqrtPriceUpper - sqrtPriceLower));
        }
    }

    function getLiquidityForAmounts(uint160 sqrtPriceX96, uint256 amount0, uint256 amount1, int24 maxTick) internal pure returns (uint128 liquidity) {
        // @dev    we only need to do this for the v4 pools,
        // @dev    loop migration
        // @dev    we in range of [-887272, 887272]
        // @dev    fixed value of SqrtX96 of lower tick on a 5000 pool
        // ticks 2500 pool: 50, 3000: 60, 3500: 70, 4000: 80, 4500: 90, 5000: 100
        // closest values are to min & max are min & max for this tick range
        (uint160 sqrtPriceAX96, uint160 sqrtPriceBX96) = getSqrtX96ForMinMaxTicks(uint256(int256(maxTick)));

        if (sqrtPriceAX96 > sqrtPriceBX96) (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);

        if (sqrtPriceX96 <= sqrtPriceAX96) {
            liquidity = getLiquidityForAmount0(sqrtPriceAX96, sqrtPriceBX96, amount0);
        } else if (sqrtPriceX96 < sqrtPriceBX96) {
            uint128 liquidity0 = getLiquidityForAmount0(sqrtPriceX96, sqrtPriceBX96, amount0);
            uint128 liquidity1 = getLiquidityForAmount1(sqrtPriceAX96, sqrtPriceX96, amount1);

            liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
        } else {
            liquidity = getLiquidityForAmount1(sqrtPriceAX96, sqrtPriceBX96, amount1);
        }
    }
}