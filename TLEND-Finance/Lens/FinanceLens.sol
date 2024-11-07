// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

// import "../CErc20.sol";
// import "../CToken.sol" ;
// import "../PriceOracle.sol";
// import "../EIP20Interface.sol";
// import "../Governance/GovernorAlpha.sol";
// import "../Governance/Finance.sol";
// import "../PriceOracle.sol";
// import "../Financetroller.sol";



interface FinancetrollerLensInterface {
    function markets(address) external view returns (bool, uint);
    function oracle() external view returns (PriceOracle);
    function getAccountLiquidity(address) external view returns (uint, uint, uint);
    function getAssetsIn(address) external view returns (CToken[] memory);
    function claimFinance(address) external;
    function financeAccrued(address) external view returns (uint);
    function financeSpeeds(address) external view returns (uint);
    function financeSupplySpeeds(address) external view returns (uint);
    function financeBorrowSpeeds(address) external view returns (uint);
    function borrowCaps(address) external view returns (uint);
    function mintGuardianPaused(address) external view returns (bool);
    function closeFactorMantissa() external view returns (uint);
    function liquidationIncentiveMantissa() external view returns (uint);
    function getAllMarkets()  external view returns (CToken[] memory);
    function getTLENDAddress() external view returns (address);
    function financeBorrowState(address) external view returns (uint224, uint32);
    function financeSupplyState(address) external view returns (uint224, uint32);

}
interface EIP20Interface {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function balanceOf(address owner) external view returns (uint256 balance);
    function allowance(address owner, address spender) external view returns (uint256 remaining);
}

interface FinanceInterface {
    function balanceOf(address account) external view returns (uint);
    function getCurrentVotes(address account) external view returns (uint96);
    function delegates(address) external view returns (address);
    function getPriorVotes(address account, uint blockNumber) external view returns (uint96);
}

interface PriceOracle {
    function getUnderlyingPrice(CToken cToken) external view returns (uint);
}

interface CErc20Interface {
  function underlying() external view returns (address);
}

interface CToken {
    function allowance(address owner, address spender) external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function balanceOfUnderlying(address owner) external returns (uint);
    function borrowRatePerBlock() external view returns (uint);
    function supplyRatePerBlock() external view returns (uint);
    function borrowBalanceCurrent(address account) external returns (uint);
    function exchangeRateCurrent() external returns (uint);
    function getCash() external view returns (uint);

    function financetroller() external returns (address);

    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    function reserveFactorMantissa() external view returns (uint);
    function totalBorrows() external view returns (uint);
    function totalReserves() external view returns (uint);
    function totalSupply() external view returns (uint);
}


interface GovernorBravoInterface {
    
    struct Receipt {
        bool hasVoted;
        uint8 support;
        uint96 votes;
    }
    struct Proposal {
        uint id;
        address proposer;
        uint eta;
        uint startBlock;
        uint endBlock;
        uint forVotes;
        uint againstVotes;
        uint abstainVotes;
        bool canceled;
        bool executed;
    }
    function getActions(uint proposalId) external view returns (address[] memory targets, uint[] memory values, string[] memory signatures, bytes[] memory calldatas);
    function proposals(uint proposalId) external view returns (Proposal memory);
    function getReceipt(uint proposalId, address voter) external view returns (Receipt memory);
}

contract FinanceLens {
    uint public constant BLOCKS_PER_DAY = 86400 / 12;
 
    struct PendingReward {
        address cTokenAddress;
        uint256 amount;
    }
    struct RewardSummary {
        address distributorAddress;
        address rewardTokenAddress;
        uint256 totalRewards;
        PendingReward[] pendingRewards;
    }
    struct CTokenAllData {
        address cToken;
        uint exchangeRateCurrent;
        uint supplyRatePerBlock;
        uint borrowRatePerBlock;
        uint reserveFactorMantissa;
        uint totalBorrows;
        uint totalReserves;
        uint totalSupply;
        uint totalCash;
        bool isListed;
        uint collateralFactorMantissa;
        address underlyingAssetAddress;
        uint cTokenDecimals;
        uint underlyingDecimals;
        uint financeSupplySpeed;
        uint financeBorrowSpeed;
        uint borrowCap;
        bool mintGuardianPaused;
        uint underlyingPrice;
        uint dailySupplyFinance;
        uint dailyBorrowFinance;
        string symbol;
    }

    struct CTokenAllDataWithAccount {
        address cToken;
        uint exchangeRateCurrent;
        uint supplyRatePerBlock;
        uint borrowRatePerBlock;
        uint reserveFactorMantissa;
        uint totalBorrows;
        uint totalReserves;
        uint totalSupply;
        uint totalCash;
        bool isListed;
        uint collateralFactorMantissa;
        address underlyingAssetAddress;
        uint cTokenDecimals;
        uint underlyingDecimals;
        uint financeSupplySpeed;
        uint financeBorrowSpeed;
        uint borrowCap;
        bool mintGuardianPaused;
        uint underlyingPrice;
        uint balanceOf;
        uint borrowBalanceCurrent;
        uint balanceOfUnderlying;
        uint tokenBalance;
        uint tokenAllowance;
        uint dailySupplyFinance;
        uint dailyBorrowFinance;
         string symbol;
    }
    struct AccountAllData {
        uint closeFactorMantissa;
        uint liquidationIncentiveMantissa;
        CToken[] marketsIn;
        uint liquidity;
        uint shortfall;
        FinanceBalanceMetadataExt financeMetadata;
        uint capFactoryAllowance;
        CTokenAllDataWithAccount[] cTokens;
    }
    struct ClaimVenusLocalVariables {
        uint totalRewards;
        uint224 borrowIndex;
        uint32 borrowBlock;
        uint224 supplyIndex;
        uint32 supplyBlock;
    }
    struct CTokenMetadata {
        address cToken;
        uint exchangeRateCurrent;
        uint supplyRatePerBlock;
        uint borrowRatePerBlock;
        uint reserveFactorMantissa;
        uint totalBorrows;
        uint totalReserves;
        uint totalSupply;
        uint totalCash;
        bool isListed;
        uint collateralFactorMantissa;
        address underlyingAssetAddress;
        uint cTokenDecimals;
        uint underlyingDecimals;
        uint financeSupplySpeed;
        uint financeBorrowSpeed;
        uint borrowCap;
        uint dailySupplyFinance;
        uint dailyBorrowFinance;
        
    }
    struct NoAccountAllData {
        uint closeFactorMantissa;
        uint liquidationIncentiveMantissa;
        CTokenAllData[] cTokens;
    }


    function getFinanceSpeeds(FinancetrollerLensInterface financetroller, CToken cToken) internal returns (uint, uint) {
        // Getting finance speeds is gnarly due to not every network having the
        // split finance speeds from Proposal 62 and other networks don't even
        // have finance speeds.
        uint financeSupplySpeed = 0;
        (bool financeSupplySpeedSuccess, bytes memory financeSupplySpeedReturnData) =
            address(financetroller).call(
                abi.encodePacked(
                    financetroller.financeSupplySpeeds.selector,
                    abi.encode(address(cToken))
                )
            );
        if (financeSupplySpeedSuccess) {
            financeSupplySpeed = abi.decode(financeSupplySpeedReturnData, (uint));
        }

        uint financeBorrowSpeed = 0;
        (bool financeBorrowSpeedSuccess, bytes memory financeBorrowSpeedReturnData) =
            address(financetroller).call(
                abi.encodePacked(
                    financetroller.financeBorrowSpeeds.selector,
                    abi.encode(address(cToken))
                )
            );
        if (financeBorrowSpeedSuccess) {
            financeBorrowSpeed = abi.decode(financeBorrowSpeedReturnData, (uint));
        }

        // If the split finance speeds call doesn't work, try the  oldest non-spit version.
        if (!financeSupplySpeedSuccess || !financeBorrowSpeedSuccess) {
            (bool financeSpeedSuccess, bytes memory financeSpeedReturnData) =
            address(financetroller).call(
                abi.encodePacked(
                    financetroller.financeSpeeds.selector,
                    abi.encode(address(cToken))
                )
            );
            if (financeSpeedSuccess) {
                financeSupplySpeed = financeBorrowSpeed = abi.decode(financeSpeedReturnData, (uint));
            }
        }
        return (financeSupplySpeed, financeBorrowSpeed);
    }
    struct FinanceMarketState {
        uint224 index;
        uint32 block;
    }


    function cTokenMetadata(CToken cToken) public returns (CTokenMetadata memory) {
        uint exchangeRateCurrent = cToken.exchangeRateCurrent();
        FinancetrollerLensInterface financetroller = FinancetrollerLensInterface(address(cToken.financetroller()));
        (bool isListed, uint collateralFactorMantissa) = financetroller.markets(address(cToken));
        address underlyingAssetAddress;
        uint underlyingDecimals;

        if (compareStrings(cToken.symbol(), "tETH")) {
            underlyingAssetAddress = address(0);
            underlyingDecimals = 18;
        } else {
            CErc20Interface cErc20 = CErc20Interface(address(cToken));
            underlyingAssetAddress = cErc20.underlying();
            underlyingDecimals = EIP20Interface(cErc20.underlying()).decimals();
        }

        (uint financeSupplySpeed, uint financeBorrowSpeed) = getFinanceSpeeds(financetroller, cToken);

        uint borrowCap = 0;
        (bool borrowCapSuccess, bytes memory borrowCapReturnData) =
            address(financetroller).call(
                abi.encodePacked(
                    financetroller.borrowCaps.selector,
                    abi.encode(address(cToken))
                )
            );
        if (borrowCapSuccess) {
            borrowCap = abi.decode(borrowCapReturnData, (uint));
        }
        uint financeSupplySpeedPerBlock = financetroller.financeSupplySpeeds(address(cToken));
        uint financeBorrowSpeedPerBlock = financetroller.financeBorrowSpeeds(address(cToken));
        return CTokenMetadata({
            cToken: address(cToken),
            exchangeRateCurrent: exchangeRateCurrent,
            supplyRatePerBlock: cToken.supplyRatePerBlock(),
            borrowRatePerBlock: cToken.borrowRatePerBlock(),
            reserveFactorMantissa: cToken.reserveFactorMantissa(),
            totalBorrows: cToken.totalBorrows(),
            totalReserves: cToken.totalReserves(),
            totalSupply: cToken.totalSupply(),
            totalCash: cToken.getCash(),
            isListed: isListed,
            collateralFactorMantissa: collateralFactorMantissa,
            underlyingAssetAddress: underlyingAssetAddress,
            cTokenDecimals: cToken.decimals(),
            underlyingDecimals: underlyingDecimals,
            financeSupplySpeed: financeSupplySpeed,
            financeBorrowSpeed: financeBorrowSpeed,
            borrowCap: borrowCap,
            dailySupplyFinance:financeSupplySpeedPerBlock * BLOCKS_PER_DAY,
            dailyBorrowFinance: financeBorrowSpeedPerBlock * BLOCKS_PER_DAY
        });
    }

    function cTokenMetadataAll(CToken[] calldata cTokens) external returns (CTokenMetadata[] memory) {
        uint cTokenCount = cTokens.length;
        CTokenMetadata[] memory res = new CTokenMetadata[](cTokenCount);
        for (uint i = 0; i < cTokenCount; i++) {
            res[i] = cTokenMetadata(cTokens[i]);
        }
        return res;
    }

    struct CTokenBalances {
        address cToken;
        uint balanceOf;
        uint borrowBalanceCurrent;
        uint balanceOfUnderlying;
        uint tokenBalance;
        uint tokenAllowance;
    }

    function cTokenBalances(CToken cToken, address payable account) public returns (CTokenBalances memory) {
        uint balanceOf = cToken.balanceOf(account);
        uint borrowBalanceCurrent = cToken.borrowBalanceCurrent(account);
        uint balanceOfUnderlying = cToken.balanceOfUnderlying(account);
        uint tokenBalance;
        uint tokenAllowance;

        if (compareStrings(cToken.symbol(), "tETH")) {
            tokenBalance = account.balance;
            tokenAllowance = account.balance;
        } else {
            CErc20Interface cErc20 = CErc20Interface(address(cToken));
            EIP20Interface underlying = EIP20Interface(cErc20.underlying());
            tokenBalance = underlying.balanceOf(account);
            tokenAllowance = underlying.allowance(account, address(cToken));
        }

        return CTokenBalances({
            cToken: address(cToken),
            balanceOf: balanceOf,
            borrowBalanceCurrent: borrowBalanceCurrent,
            balanceOfUnderlying: balanceOfUnderlying,
            tokenBalance: tokenBalance,
            tokenAllowance: tokenAllowance
        });
    }

    function buildCTokenAllData(CToken cToken) public returns (CTokenAllData memory) {
        uint exchangeRateCurrent = cToken.exchangeRateCurrent();
        FinancetrollerLensInterface financetroller = FinancetrollerLensInterface(address(cToken.financetroller()));
        (bool isListed, uint collateralFactorMantissa) = financetroller.markets(address(cToken));
        address underlyingAssetAddress;
        uint underlyingDecimals;

        if (compareStrings(cToken.symbol(), "tETH")) {
            underlyingAssetAddress = address(0);
            underlyingDecimals = 18;
        } else {
            CErc20Interface cErc20 = CErc20Interface(address(cToken));
            underlyingAssetAddress = cErc20.underlying();
            underlyingDecimals = EIP20Interface(cErc20.underlying()).decimals();
        }

        (uint financeSupplySpeed, uint financeBorrowSpeed) = getFinanceSpeeds(financetroller, cToken);

        uint borrowCap = 0;
        (bool borrowCapSuccess, bytes memory borrowCapReturnData) =
            address(financetroller).call(
                abi.encodePacked(
                    financetroller.borrowCaps.selector,
                    abi.encode(address(cToken))
                )
            );
        if (borrowCapSuccess) {
            borrowCap = abi.decode(borrowCapReturnData, (uint));
        }

        PriceOracle priceOracle = financetroller.oracle();
        uint financeSupplySpeedPerBlock = financetroller.financeSupplySpeeds(address(cToken));
        uint financeBorrowSpeedPerBlock = financetroller.financeBorrowSpeeds(address(cToken));

        return CTokenAllData({
            cToken: address(cToken),
            exchangeRateCurrent: exchangeRateCurrent,
            supplyRatePerBlock: cToken.supplyRatePerBlock(),
            borrowRatePerBlock: cToken.borrowRatePerBlock(),
            reserveFactorMantissa: cToken.reserveFactorMantissa(),
            totalBorrows: cToken.totalBorrows(),
            totalReserves: cToken.totalReserves(),
            totalSupply: cToken.totalSupply(),
            totalCash: cToken.getCash(),
            isListed: isListed,
            collateralFactorMantissa: collateralFactorMantissa,
            underlyingAssetAddress: underlyingAssetAddress,
            cTokenDecimals: cToken.decimals(),
            underlyingDecimals: underlyingDecimals,
            financeSupplySpeed: financeSupplySpeed,
            financeBorrowSpeed: financeBorrowSpeed,
            borrowCap: borrowCap,
            mintGuardianPaused: financetroller.mintGuardianPaused(address(cToken)),
            underlyingPrice: priceOracle.getUnderlyingPrice(cToken),
            dailySupplyFinance:financeSupplySpeedPerBlock * BLOCKS_PER_DAY,
            dailyBorrowFinance: financeBorrowSpeedPerBlock * BLOCKS_PER_DAY,
            symbol:cToken.symbol()
        });
    }

    function cTokenBalancesAll(CToken[] calldata cTokens, address payable account) external returns (CTokenBalances[] memory) {
        uint cTokenCount = cTokens.length;
        CTokenBalances[] memory res = new CTokenBalances[](cTokenCount);
        for (uint i = 0; i < cTokenCount; i++) {
            res[i] = cTokenBalances(cTokens[i], account);
        }
        return res;
    }

    struct CTokenUnderlyingPrice {
        address cToken;
        uint underlyingPrice;
    }

    function queryAllNoAccount(CToken[] calldata cTokens) external returns (NoAccountAllData memory) {
        uint cTokenCount = cTokens.length;
        CTokenAllData[] memory cTokensRes = new CTokenAllData[](cTokenCount);
        for (uint i = 0; i < cTokenCount; i++) {
            cTokensRes[i] = buildCTokenAllData(cTokens[i]);
        }

        uint liquidationIncentive = 0;
        uint closeFactor = 0;
        if(cTokenCount > 0) {
            FinancetrollerLensInterface financetroller = FinancetrollerLensInterface(address(cTokens[0].financetroller()));
            liquidationIncentive = financetroller.liquidationIncentiveMantissa();
            closeFactor = financetroller.closeFactorMantissa();
        }

        return NoAccountAllData({
            closeFactorMantissa: closeFactor,
            liquidationIncentiveMantissa: liquidationIncentive,
            cTokens: cTokensRes
        });
    }

    function cTokenUnderlyingPrice(CToken cToken) public returns (CTokenUnderlyingPrice memory) {
        FinancetrollerLensInterface financetroller = FinancetrollerLensInterface(address(cToken.financetroller()));
        PriceOracle priceOracle = financetroller.oracle();

        return CTokenUnderlyingPrice({
            cToken: address(cToken),
            underlyingPrice: priceOracle.getUnderlyingPrice(cToken)
        });
    }

    function cTokenUnderlyingPriceAll(CToken[] calldata cTokens) external returns (CTokenUnderlyingPrice[] memory) {
        uint cTokenCount = cTokens.length;
        CTokenUnderlyingPrice[] memory res = new CTokenUnderlyingPrice[](cTokenCount);
        for (uint i = 0; i < cTokenCount; i++) {
            res[i] = cTokenUnderlyingPrice(cTokens[i]);
        }
        return res;
    }

    struct AccountLimits {
        CToken[] markets;
        uint liquidity;
        uint shortfall;
    }


    function getAccountLimits(FinancetrollerLensInterface financetroller, address account) public returns (AccountLimits memory) {
        (uint errorCode, uint liquidity, uint shortfall) = financetroller.getAccountLiquidity(account);
        require(errorCode == 0);

        return AccountLimits({
            markets: financetroller.getAssetsIn(account),
            liquidity: liquidity,
            shortfall: shortfall
        });
    }

    struct GovReceipt {
        uint proposalId;
        bool hasVoted;
        bool support;
        uint96 votes;
    }

  

    struct GovBravoReceipt {
        uint proposalId;
        bool hasVoted;
        uint8 support;
        uint96 votes;
    }

    function getGovBravoReceipts(GovernorBravoInterface governor, address voter, uint[] memory proposalIds) public view returns (GovBravoReceipt[] memory) {
        uint proposalCount = proposalIds.length;
        GovBravoReceipt[] memory res = new GovBravoReceipt[](proposalCount);
        for (uint i = 0; i < proposalCount; i++) {
            GovernorBravoInterface.Receipt memory receipt = governor.getReceipt(proposalIds[i], voter);
            res[i] = GovBravoReceipt({
                proposalId: proposalIds[i],
                hasVoted: receipt.hasVoted,
                support: receipt.support,
                votes: receipt.votes
            });
        }
        return res;
    }

    struct GovProposal {
        uint proposalId;
        address proposer;
        uint eta;
        address[] targets;
        uint[] values;
        string[] signatures;
        bytes[] calldatas;
        uint startBlock;
        uint endBlock;
        uint forVotes;
        uint againstVotes;
        bool canceled;
        bool executed;
    }

    

    struct GovBravoProposal {
        uint proposalId;
        address proposer;
        uint eta;
        address[] targets;
        uint[] values;
        string[] signatures;
        bytes[] calldatas;
        uint startBlock;
        uint endBlock;
        uint forVotes;
        uint againstVotes;
        uint abstainVotes;
        bool canceled;
        bool executed;
    }

    function setBravoProposal(GovBravoProposal memory res, GovernorBravoInterface governor, uint proposalId) internal view {
        GovernorBravoInterface.Proposal memory p = governor.proposals(proposalId);

        res.proposalId = proposalId;
        res.proposer = p.proposer;
        res.eta = p.eta;
        res.startBlock = p.startBlock;
        res.endBlock = p.endBlock;
        res.forVotes = p.forVotes;
        res.againstVotes = p.againstVotes;
        res.abstainVotes = p.abstainVotes;
        res.canceled = p.canceled;
        res.executed = p.executed;
    }

    function getGovBravoProposals(GovernorBravoInterface governor, uint[] calldata proposalIds) external view returns (GovBravoProposal[] memory) {
        GovBravoProposal[] memory res = new GovBravoProposal[](proposalIds.length);
        for (uint i = 0; i < proposalIds.length; i++) {
            (
                address[] memory targets,
                uint[] memory values,
                string[] memory signatures,
                bytes[] memory calldatas
            ) = governor.getActions(proposalIds[i]);
            res[i] = GovBravoProposal({
                proposalId: 0,
                proposer: address(0),
                eta: 0,
                targets: targets,
                values: values,
                signatures: signatures,
                calldatas: calldatas,
                startBlock: 0,
                endBlock: 0,
                forVotes: 0,
                againstVotes: 0,
                abstainVotes: 0,
                canceled: false,
                executed: false
            });
            setBravoProposal(res[i], governor, proposalIds[i]);
        }
        return res;
    }

    struct FinanceBalanceMetadata {
        uint balance;
        uint votes;
        address delegate;
    }

    function getFinanceBalanceMetadata(FinanceInterface finance, address account) external view returns (FinanceBalanceMetadata memory) {
        return FinanceBalanceMetadata({
            balance: finance.balanceOf(account),
            votes: uint256(finance.getCurrentVotes(account)),
            delegate: finance.delegates(account)
        });
    }

    struct FinanceBalanceMetadataExt {
        uint balance;
        uint votes;
        address delegate;
        uint allocated;
    }

    function getFinanceBalanceMetadataExt(FinanceInterface finance, FinancetrollerLensInterface financetroller, address account) external returns (FinanceBalanceMetadataExt memory) {
        uint balance = finance.balanceOf(account);
        financetroller.claimFinance(account);
        uint newBalance = finance.balanceOf(account);
        uint accrued = financetroller.financeAccrued(account);
        uint total = add(accrued, newBalance, "sum finance total");
        uint allocated = sub(total, balance, "sub allocated");

        return FinanceBalanceMetadataExt({
            balance: balance,
            votes: uint256(finance.getCurrentVotes(account)),
            delegate: finance.delegates(account),
            allocated: allocated
        });
    }

    struct FinanceVotes {
        uint blockNumber;
        uint votes;
    }

    function getFinanceVotes(FinanceInterface finance, address account, uint32[] calldata blockNumbers) external view returns (FinanceVotes[] memory) {
        FinanceVotes[] memory res = new FinanceVotes[](blockNumbers.length);
        for (uint i = 0; i < blockNumbers.length; i++) {
            res[i] = FinanceVotes({
                blockNumber: uint256(blockNumbers[i]),
                votes: uint256(finance.getPriorVotes(account, blockNumbers[i]))
            });
        }
        return res;
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function add(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        uint c = a + b;
        require(c >= a, errorMessage);
        return c;
    }

    function sub(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        require(b <= a, errorMessage);
        uint c = a - b;
        return c;
    }

    function queryAllWithAccount(CToken[] calldata cTokens, address payable account, FinanceInterface finance, address capFactory) external returns (AccountAllData memory) {
        uint cTokenCount = cTokens.length;
        CTokenAllDataWithAccount[] memory cTokensRes = new CTokenAllDataWithAccount[](cTokenCount);
        for (uint i = 0; i < cTokenCount; i++) {
            CTokenAllData memory cTokenAllData = buildCTokenAllData(cTokens[i]);
            CTokenBalances memory cTokenBalance = cTokenBalances(cTokens[i], account);
            
            cTokensRes[i] = CTokenAllDataWithAccount({
                cToken: cTokenAllData.cToken,
                exchangeRateCurrent: cTokenAllData.exchangeRateCurrent,
                supplyRatePerBlock: cTokenAllData.supplyRatePerBlock,
                borrowRatePerBlock: cTokenAllData.borrowRatePerBlock,
                reserveFactorMantissa: cTokenAllData.reserveFactorMantissa,
                totalBorrows: cTokenAllData.totalBorrows,
                totalReserves: cTokenAllData.totalReserves,
                totalSupply: cTokenAllData.totalSupply,
                totalCash: cTokenAllData.totalCash,
                isListed: cTokenAllData.isListed,
                collateralFactorMantissa: cTokenAllData.collateralFactorMantissa,
                underlyingAssetAddress: cTokenAllData.underlyingAssetAddress,
                cTokenDecimals: cTokenAllData.cTokenDecimals,
                underlyingDecimals: cTokenAllData.underlyingDecimals,
                financeSupplySpeed: cTokenAllData.financeSupplySpeed,
                financeBorrowSpeed: cTokenAllData.financeBorrowSpeed,
                borrowCap: cTokenAllData.borrowCap,
                mintGuardianPaused: cTokenAllData.mintGuardianPaused,
                underlyingPrice: cTokenAllData.underlyingPrice,
                balanceOf: cTokenBalance.balanceOf,
                borrowBalanceCurrent: cTokenBalance.borrowBalanceCurrent,
                balanceOfUnderlying: cTokenBalance.balanceOfUnderlying,
                tokenBalance: cTokenBalance.tokenBalance,
                tokenAllowance: cTokenBalance.tokenAllowance,
                dailySupplyFinance: cTokenAllData.dailySupplyFinance,
                dailyBorrowFinance: cTokenAllData.dailyBorrowFinance,
                symbol:cTokenAllData.symbol
            });
        }

        uint liquidationIncentive = 0;
        uint closeFactor = 0;

        CToken[] memory accountMarketsIn;
        uint liquidity = 0;
        uint shortfall = 0;

        uint financeBalance = 0;
        uint financeVotes = 0;
        address financeDelegate;
        uint financeAllocated = 0;

        uint capFactoryAllowance = 0;
        if(cTokenCount > 0) {
            FinancetrollerLensInterface financetroller = FinancetrollerLensInterface(address(cTokens[0].financetroller()));
            liquidationIncentive = financetroller.liquidationIncentiveMantissa();
            closeFactor = financetroller.closeFactorMantissa();

            AccountLimits memory accountLimits = getAccountLimits(financetroller, account);
            accountMarketsIn = accountLimits.markets;
            liquidity = accountLimits.liquidity;
            shortfall = accountLimits.shortfall;

            // FinanceBalanceMetadataExt memory financeMetadata = this.getFinanceBalanceMetadataExt(finance, financetroller, account);
            FinanceBalanceMetadataExt memory financeMetadata = this.getFinanceBalanceMetadataExt(FinanceInterface(address(finance)), financetroller, account);
            financeBalance = financeMetadata.balance;
            financeVotes = financeMetadata.votes;
            financeDelegate = financeMetadata.delegate;
            financeAllocated = financeMetadata.allocated;

            EIP20Interface financeEIP20 = EIP20Interface(address(finance));
            capFactoryAllowance = financeEIP20.allowance(account, capFactory);
        }

        return AccountAllData({
            closeFactorMantissa: closeFactor,
            liquidationIncentiveMantissa: liquidationIncentive,
            marketsIn: accountMarketsIn,
            liquidity: liquidity,
            shortfall: shortfall,
            financeMetadata: FinanceBalanceMetadataExt({
                balance: financeBalance,
                votes: financeVotes,
                delegate: financeDelegate,
                allocated: financeAllocated
            }),
            capFactoryAllowance: capFactoryAllowance,
            cTokens: cTokensRes
        });
    }
  
    // mapping(address => FinanceMarketState) public financeSupplyState;
    // mapping(address => mapping(address => uint)) public financeSupplierIndex;
     
    // uint224 public constant financeInitialIndex = 1e36;
    
    function pendingRewards(
        address holder,
        FinancetrollerLensInterface financetroller
    ) external  returns (RewardSummary memory) {
        CToken[] memory cTokens = financetroller.getAllMarkets();
        // ClaimVenusLocalVariables memory vars;
        RewardSummary memory rewardSummary;
        rewardSummary.distributorAddress = address(financetroller);
        rewardSummary.rewardTokenAddress = financetroller.getTLENDAddress();
       
        FinanceBalanceMetadataExt memory financeMetadata = this.getFinanceBalanceMetadataExt(FinanceInterface(address(financetroller.getTLENDAddress())), financetroller, holder);
        rewardSummary.totalRewards = financeMetadata.allocated;
        rewardSummary.pendingRewards = new PendingReward[](cTokens.length);
        
        return rewardSummary;
    }
}