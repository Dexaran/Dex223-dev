
// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

contract DataHelper
{
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function MintParamsCall( 
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        address recipient,
        uint256 deadline) public pure returns (MintParams memory _ret)
    {
        _ret.token0 = token0;
        _ret.token1 = token1;
        _ret.fee = fee;
        _ret.tickLower = tickLower;
        _ret.tickUpper = tickUpper;
        _ret.amount0Desired = amount0Desired;
        _ret.amount1Desired = amount1Desired;
        _ret.amount0Min = amount0Min;
        _ret.amount1Min = amount1Min;
        _ret.recipient = recipient;
        _ret.deadline = deadline;
    }
}
