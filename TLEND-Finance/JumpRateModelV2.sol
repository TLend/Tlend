// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./BaseJumpRateModelV2.sol";
import "./InterestRateModel.sol";


/**
  * @title JumpRateModel Contract V2 for V2 cTokens
  * @notice Supports only for V2 cTokens
  */
contract JumpRateModelV2 is InterestRateModel, BaseJumpRateModelV2  {

	/**
     * @notice Calculates the current borrow rate per block
     * @param cash The amount of cash in the market
     * @param borrows The amount of borrows in the market
     * @param reserves The amount of reserves in the market
     * @return The borrow rate percentage per block as a mantissa (scaled by 1e18)
     */
    function getBorrowRate(uint cash, uint borrows, uint reserves) override external view returns (uint) {
        return getBorrowRateInternal(cash, borrows, reserves);
    }

    constructor(uint baseRatePerYear, uint multiplierPerYear, uint jumpMultiplierPerYear, uint kink_, address owner_)

    BaseJumpRateModelV2(baseRatePerYear,multiplierPerYear,jumpMultiplierPerYear,kink_,owner_) public {}
}
