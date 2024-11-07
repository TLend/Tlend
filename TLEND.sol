// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./TLENDLP.sol";

contract TLEND is ERC20, AccessControl {
    using SafeERC20 for IERC20;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 public constant BASE_COST = 300_000_000 * 10**18; // Cost of 300 million TITANX tokens
    uint256 public currentTlendMinable = 200_000; // Initially 200,000 TLENDX can be mined daily
    uint256 public blockInterval = 12; // Ethereum block time (seconds)
    uint256 public constant AMPLIFICATION_FACTOR = 1e10;

    uint256 public lastReductionBlock;
    IERC20 public titanxToken;
    TLENDLP public minerCertificate;

    address public liquidityManager;
    address public liquidationReserve;
    address public purchaseManager;
    address public operationsTreasury;
    address public initialLiquidityContract;

    uint256 public constant INITIAL_LIQUIDITY_AMOUNT = 1_000_000_000 * 10**18; 
    uint256 public constant INITIAL_TITANX_THRESHOLD = 30_000_000_000 * 10**18; 
    uint256 public initialTitanxReceived; 

    uint256 public constant LIQUIDITY_PERCENT = 30;
    uint256 public constant LIQUIDATION_PERCENT = 20;
    uint256 public constant PURCHASE_PERCENT = 45;
    uint256 public constant OPERATIONS_PERCENT = 5;

    mapping(address => uint256) public minerCount;
    mapping(address => uint256[]) public userMinerIds;

    struct MinerInfo {
        uint256 startBlock;
        uint256 rewardAmount;
        uint256 endBlock;
        bool claimed;
    }

    mapping(address => mapping(uint256 => MinerInfo)) public miners;

    constructor(address certificateAddress, address _titanxToken, address _initialLiquidityContract) ERC20("TLEND", "TLEND Finance") {
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);

        minerCertificate = TLENDLP(certificateAddress);
        lastReductionBlock = block.number;
        titanxToken = IERC20(_titanxToken); 
        initialLiquidityContract = _initialLiquidityContract;
        _mint(initialLiquidityContract, INITIAL_LIQUIDITY_AMOUNT);
    }

    function startMining(uint256 daysDuration, uint256 miningPower) external {
        require(minerCount[msg.sender] < 100, "Exceeds maximum miner limit");
        require(daysDuration == 1 || daysDuration == 10 || daysDuration == 30 || daysDuration == 88 || daysDuration == 280, "Invalid mining duration");
        require(miningPower >= 1 && miningPower <= 100, "Invalid mining power");

        _reduceMinable();
        _createMiner(msg.sender, block.number,  daysDuration, miningPower);
    }

    function batchAddMiners(uint256[] calldata startTimes, uint256[] calldata daysDurations, uint256[] calldata miningPowers) external {
        require(startTimes.length == daysDurations.length && daysDurations.length == miningPowers.length, "Mismatched input arrays");

        for (uint256 i = 0; i < startTimes.length; i++) {
            require(minerCount[msg.sender] < 100, "Exceeds maximum miner limit");
            require(daysDurations[i] == 1 || daysDurations[i] == 10 || daysDurations[i] == 30 || daysDurations[i] == 88 || daysDurations[i] == 280, "Invalid mining duration");
            require(miningPowers[i] >= 1 && miningPowers[i] <= 100, "Invalid mining power");

            uint256 startBlock = startTimes[i];
            require(block.number <= startBlock, "Start time must be in the future");

            _createMiner(msg.sender, startBlock, daysDurations[i], miningPowers[i]);
        }
    }


    function _createMiner(address to, uint256 startBlock, uint256 daysDuration, uint256 miningPower) internal {
        uint256 blocksForDuration = (daysDuration * 86400) / blockInterval;
        uint256 endBlock = block.number + blocksForDuration;

        uint256 titanxCost = (BASE_COST * miningPower) / 100;
        require(titanxToken.balanceOf(to) >= titanxCost, "Insufficient TITANX balance");

        receiveAndDistributeTITANX(titanxCost);

        uint256 baseExchangeRate = currentTlendMinable / (86400 / blockInterval);
        uint256 adjustedExchangeRate = (baseExchangeRate * miningPower * AMPLIFICATION_FACTOR) / 100;

        uint256 mintAmount = blocksForDuration * adjustedExchangeRate * 10 ** decimals() / AMPLIFICATION_FACTOR;
        minerCertificate.mint(to,endBlock, adjustedExchangeRate);

        uint256 newTokenId = uint256(keccak256(abi.encodePacked(to, block.number, minerCount[to])));
        miners[to][newTokenId] = MinerInfo({
            startBlock:startBlock ,
            rewardAmount: mintAmount,
            endBlock: endBlock,
            claimed: false
        });

        userMinerIds[to].push(newTokenId);
        minerCount[to] += 1;
    }

    function _reduceMinable() internal {
        uint256 blocksPerDay = (86400 / blockInterval);
        if (block.number >= lastReductionBlock + blocksPerDay) {
            uint256 daysPassed = (block.number - lastReductionBlock) / blocksPerDay;
            for (uint256 i = 0; i < daysPassed; i++) {
                currentTlendMinable = (currentTlendMinable * 9965) / 10000;
            }
            lastReductionBlock = block.number;
        }
    }

    function claimReward(uint256 tokenId) external {
        MinerInfo storage miner = miners[msg.sender][tokenId];
        require(!miner.claimed, "Reward already claimed");
        require(block.number >= miner.endBlock, "Mining period not yet finished");

        uint256 reward = miner.rewardAmount;
        uint256 userBalance = minerCertificate.balanceOf(msg.sender);
        require(userBalance >= miner.rewardAmount, "Insufficient TLENDLP balance for this reward");

        uint256 threeDaysInBlocks = (3 * 86400) / blockInterval;
        uint256 graceEndBlock = miner.endBlock + threeDaysInBlocks;
        uint256 penaltyEndBlock = graceEndBlock + threeDaysInBlocks;

        if (block.number > graceEndBlock && block.number <= penaltyEndBlock) {
            uint256 blocksSinceGracePeriod = block.number - graceEndBlock;
            uint256 penaltyPercentage = 100 - ((blocksSinceGracePeriod * 99) / threeDaysInBlocks);
            reward = (reward * penaltyPercentage) / 100;
        } else if (block.number > penaltyEndBlock) {
            reward = (reward * 1) / 100;
        }


        require(reward > 0, "No reward available");

        minerCertificate.transferFrom(msg.sender, 0x000000000000000000000000000000000000dEaD, miner.rewardAmount);
        // minerCertificate.transfer(address(0), miner.rewardAmount);

        miner.claimed = true;
        _mint(msg.sender, reward);
    }

    function getUserMinerIds(address user) external view returns (uint256[] memory) {
        return userMinerIds[user];
    }

    function setLiquidityManager(address _liquidityManager) external onlyRole(ADMIN_ROLE) {
        liquidityManager = _liquidityManager;
    }

    function setLiquidationReserve(address _liquidationReserve) external onlyRole(ADMIN_ROLE) {
        liquidationReserve = _liquidationReserve;
    }

    function setPurchaseManager(address _purchaseManager) external onlyRole(ADMIN_ROLE) {
        purchaseManager = _purchaseManager;
    }

    function setOperationsTreasury(address _operationsTreasury) external onlyRole(ADMIN_ROLE) {
        operationsTreasury = _operationsTreasury;
    }


    function setInitialLiquidityContract(address _initialLiquidityContract) external onlyRole(ADMIN_ROLE) {
        initialLiquidityContract = _initialLiquidityContract;
    }

    function distributeTITANX(uint256 totalAmount) internal {
        if (initialTitanxReceived < INITIAL_TITANX_THRESHOLD) {
            
            uint256 remaining = INITIAL_TITANX_THRESHOLD - initialTitanxReceived;
            uint256 toTransfer = totalAmount > remaining ? remaining : totalAmount;
            titanxToken.safeTransfer(initialLiquidityContract, toTransfer);
            initialTitanxReceived += toTransfer;

            if (totalAmount > toTransfer) {
                _distributeRemainingTITANX(totalAmount - toTransfer);
            }
        } else {
            _distributeRemainingTITANX(totalAmount);
        }
    }

    function _distributeRemainingTITANX(uint256 totalAmount) internal {
        uint256 liquidityAmount = (totalAmount * LIQUIDITY_PERCENT) / 100;
        uint256 liquidationAmount = (totalAmount * LIQUIDATION_PERCENT) / 100;
        uint256 purchaseAmount = (totalAmount * PURCHASE_PERCENT) / 100;
        uint256 operationsAmount = (totalAmount * OPERATIONS_PERCENT) / 100;

        if (liquidityManager != address(0)) {
            titanxToken.safeTransfer(liquidityManager, liquidityAmount);
        }
        if (liquidationReserve != address(0)) {
            titanxToken.safeTransfer(liquidationReserve, liquidationAmount);
        }
        if (purchaseManager != address(0)) {
            titanxToken.safeTransfer(purchaseManager, purchaseAmount);
        }
        if (operationsTreasury != address(0)) {
            titanxToken.safeTransfer(operationsTreasury, operationsAmount);
        }
      
    }

    function receiveAndDistributeTITANX(uint256 amount) internal {
        titanxToken.safeTransferFrom(msg.sender, address(this), amount);
        distributeTITANX(amount);
    }
}
