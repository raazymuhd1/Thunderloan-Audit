// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.20;

// @audit info unused import
// it's bad practices to edit live code for test/mocks code
import { IThunderLoan } from "./IThunderLoan.sol";

/**
 * @dev Inspired by Aave:
 * https://github.com/aave/aave-v3-core/blob/master/contracts/flashloan/interfaces/IFlashLoanReceiver.sol
 */
interface IFlashLoanReceiver {
    // @audit info it's better to write a natspec here, explaining all of those params
    // q: is token, the token that being borrow??
    // q: what is this fee and where is it come from ??
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address initiator,
        bytes calldata params
    )
        external
        returns (bool);
}
