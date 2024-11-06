// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./CToken.sol";
import "./PriceOracle.sol";

contract UnitrollerAdminStorage {
    /**
    * @notice Administrator for this contract
    */
    address public admin;

    /**
    * @notice Pending administrator for this contract
    */
    address public pendingAdmin;

    /**
    * @notice Active brains of Unitroller
    */
    address public financetrollerImplementation;

    /**
    * @notice Pending brains of Unitroller
    */
    address public pendingFinancetrollerImplementation;
}

contract FinancetrollerV1Storage is UnitrollerAdminStorage {

    /**
     * @notice Oracle which gives the price of any given asset
     */
    PriceOracle public oracle;

    /**
     * @notice Multiplier used to calculate the maximum repayAmount when liquidating a borrow
     */
    uint public closeFactorMantissa;

    /**
     * @notice Multiplier representing the discount on collateral that a liquidator receives
     */
    uint public liquidationIncentiveMantissa;

    /**
     * @notice Max number of assets a single account can participate in (borrow or use as collateral)
     */
    uint public maxAssets;

    /**
     * @notice Per-account mapping of "assets you are in", capped by maxAssets
     */
    mapping(address => CToken[]) public accountAssets;

}

contract FinancetrollerV2Storage is FinancetrollerV1Storage {
    struct Market {
        // Whether or not this market is listed
        bool isListed;

        //  Multiplier representing the most one can borrow against their collateral in this market.
        //  For instance, 0.9 to allow borrowing 90% of collateral value.
        //  Must be between 0 and 1, and stored as a mantissa.
        uint collateralFactorMantissa;

        // Per-market mapping of "accounts in this asset"
        mapping(address => bool) accountMembership;

        // Whether or not this market receives TLEND
        bool isFinanceed;
    }

    /**
     * @notice Official mapping of cTokens -> Market metadata
     * @dev Used e.g. to determine if a market is supported
     */
    mapping(address => Market) public markets;


    /**
     * @notice The Pause Guardian can pause certain actions as a safety mechanism.
     *  Actions which allow users to remove their own assets cannot be paused.
     *  Liquidation / seizing / transfer can only be paused globally, not by market.
     */
    address public pauseGuardian;
    bool public _mintGuardianPaused;
    bool public _borrowGuardianPaused;
    bool public transferGuardianPaused;
    bool public seizeGuardianPaused;
    mapping(address => bool) public mintGuardianPaused;
    mapping(address => bool) public borrowGuardianPaused;
}

contract FinancetrollerV3Storage is FinancetrollerV2Storage {
    struct FinanceMarketState {
        // The market's last updated financeBorrowIndex or financeSupplyIndex
        uint224 index;

        // The block number the index was last updated at
        uint32 block;
    }

    /// @notice A list of all markets
    CToken[] public allMarkets;

    /// @notice The rate at which the flywheel distributes TLEND, per block
    uint public financeRate;

    /// @notice The portion of financeRate that each market currently receives
    mapping(address => uint) public financeSpeeds;

    /// @notice The TLEND market supply state for each market
    mapping(address => FinanceMarketState) public financeSupplyState;

    /// @notice The TLEND market borrow state for each market
    mapping(address => FinanceMarketState) public financeBorrowState;

    /// @notice The TLEND borrow index for each market for each supplier as of the last time they accrued TLEND
    mapping(address => mapping(address => uint)) public financeSupplierIndex;

    /// @notice The TLEND borrow index for each market for each borrower as of the last time they accrued TLEND
    mapping(address => mapping(address => uint)) public financeBorrowerIndex;

    /// @notice The TLEND accrued but not yet transferred to each user
    mapping(address => uint) public financeAccrued;
}

contract FinancetrollerV4Storage is FinancetrollerV3Storage {
    // @notice The borrowCapGuardian can set borrowCaps to any number for any market. Lowering the borrow cap could disable borrowing on the given market.
    address public borrowCapGuardian;

    // @notice Borrow caps enforced by borrowAllowed for each cToken address. Defaults to zero which corresponds to unlimited borrowing.
    mapping(address => uint) public borrowCaps;
}

contract FinancetrollerV5Storage is FinancetrollerV4Storage {
    /// @notice The portion of TLEND that each contributor receives per block
    mapping(address => uint) public financeContributorSpeeds;

    /// @notice Last block at which a contributor's TLEND rewards have been allocated
    mapping(address => uint) public lastContributorBlock;
}

contract FinancetrollerV6Storage is FinancetrollerV5Storage {
    /// @notice The rate at which finance is distributed to the corresponding borrow market (per block)
    mapping(address => uint) public financeBorrowSpeeds;

    /// @notice The rate at which finance is distributed to the corresponding supply market (per block)
    mapping(address => uint) public financeSupplySpeeds;
}

contract FinancetrollerV7Storage is FinancetrollerV6Storage {
    /// @notice Flag indicating whether the function to fix TLEND accruals has been executed (RE: proposal 62 bug)
    bool public proposal65FixExecuted;

    /// @notice Accounting storage mapping account addresses to how much TLEND they owe the protocol.
    mapping(address => uint) public financeReceivable;
}
