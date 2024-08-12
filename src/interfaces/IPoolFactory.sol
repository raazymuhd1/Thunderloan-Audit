// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

// Q: why are we using TSWAP ??
interface IPoolFactory {
    function getPool(address tokenAddress) external view returns (address);
}
