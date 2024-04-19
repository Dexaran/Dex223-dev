// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import './interfaces/IDex223PoolDeployer.sol';

import './Dex223Pool.sol';

contract UniswapV3PoolDeployer is IDex223PoolDeployer {
    struct Parameters {
        address factory;
        address token0_erc20;
        address token1_erc20;
        address token0_erc223;
        address token1_erc223;
        uint24 fee;
        int24 tickSpacing;
    }

    /// @inheritdoc IDex223PoolDeployer
    Parameters public override parameters;

/*
    /// @dev Deploys a pool with the given parameters by transiently setting the parameters storage slot and then
    /// clearing it after deploying the pool.
    /// @param factory The contract address of the Uniswap V3 factory
    /// @param token0 The first token of the pool by address sort order
    /// @param token1 The second token of the pool by address sort order
    /// @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    /// @param tickSpacing The spacing between usable ticks
*/
    function deploy(
        address factory,
        address token0_erc20,
        address token1_erc20,
        address token0_erc223,
        address token1_erc223,
        uint24 fee,
        int24 tickSpacing
    ) internal returns (address pool) {
        //parameters = Parameters({factory: factory, token0_erc20: token0_erc20, token1_erc20: token1_erc20, token0_erc223: token0_erc223, token1_erc223: token1_erc223, fee: fee, tickSpacing: tickSpacing});
        pool = address(new Dex223Pool{salt: keccak256(abi.encode(token0_erc20, token1_erc20, fee))}());
        //delete parameters;
    }
}
