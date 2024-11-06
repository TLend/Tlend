// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract TLENDLP is ERC20, AccessControl, Pausable {

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    uint256 public constant AMPLIFICATION_FACTOR = 1e10;
    uint256 public blockInterval = 15; // Ethereum block time (seconds)


    struct MintInfo {
        uint256 startBlock;
        uint256 endBlock;
        uint256 exchangeRate;
        uint256 amount; // Total minted amount for this mint
    }

    mapping(address => MintInfo[]) public userMintInfo; // User's mint information
    mapping(address => uint256) public totalMinted; // Total minted amount per user
    mapping(address => bool) public farmContracts; // Allowed farm contracts
    address public TLEND;

    constructor() ERC20("TLENDLP", "TLENDLP") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    // Admin sets farm contract addresses
    function setFarmContract(address _address, bool _allowed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        farmContracts[_address] = _allowed;
    }

    // Admin sets the TLEND address
    function setTLEND(address _tlend) external onlyRole(DEFAULT_ADMIN_ROLE) {
        TLEND = _tlend;
    }

    // mint tokens
    function mint(
        address to,
        uint256 endBlock,
        uint256 exchangeRate
    ) public onlyRole(MINTER_ROLE) {
        uint256 startBlock = block.number;
        uint256 amplifiedAmount = (endBlock - startBlock) * exchangeRate;
        // uint256 amount = (endBlock - startBlock) * exchangeRate * 10 ** decimals();
        uint256 amount = (amplifiedAmount * 10 ** decimals()) / AMPLIFICATION_FACTOR; 

        _mint(to, amount); // Mint tokens

        // Record user's mint information
        userMintInfo[to].push(MintInfo({
            startBlock: startBlock,
            endBlock: endBlock,
            exchangeRate: exchangeRate,
            amount: amount
        }));

        totalMinted[to] += amount; // Update total minted
    }

    // Override transfer to add custom logic
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();

        // Custom logic before calling the standard transfer
        if (farmContracts[to]) {
            uint256 userTransferBalacne = balanceOfTransfer(msg.sender);
            require(userTransferBalacne>= amount, "Exceeds dynamic transferable limit");
        }else  if (farmContracts[_msgSender()]) {
            // Directly allow the transfer without checking the dynamic transferable amount
          


        } else if (to == TLEND) {
            totalMinted[owner] -= amount; // Decrease totalMinted on TLEND conversion
        } else if (to == address(0)) {
            totalMinted[owner] -= amount; // Decrease totalMinted when burning tokens
        } else {
            require(farmContracts[to], "Transfers only allowed to farm contracts");
        }

        _transfer(owner, to, amount); // Call the standard transfer
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        // If the sender is a farm contract, allow the user to redeem all TLENDLP without checking the dynamic transferable amount
        if (farmContracts[from]) {
            // Directly allow the transfer without checking the dynamic transferable amount
        } 
        else if (_msgSender() == TLEND) {
            totalMinted[from] -= amount; 
        }
        // If the recipient is a farm contract, check the dynamic transferable amount
        else if (farmContracts[to] && farmContracts[_msgSender()]) {
            
            uint256 userTransferBalacne = balanceOfTransfer(from);
            require(userTransferBalacne>= amount, "Exceeds dynamic transferable limit based on blocks.");
        }
        // If the recipient is the TLEND address
        else if (to == TLEND) {
            totalMinted[from] -= amount; // Decrease totalMinted on TLEND conversion
        }
        // If the recipient is the burn address (blackhole)
        else if (to == address(0)) {
            totalMinted[from] -= amount; // Decrease totalMinted when burning tokens
        }
        // Transfers to any other addresses are not allowed
        else {
            revert("Transfers only allowed to farm contracts, TLEND or blackhole address.");
        }

        _transfer(from, to, amount);

        uint256 currentAllowance = allowance(from, _msgSender());
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(from, _msgSender(), currentAllowance - amount);

        return true;
    }


    function _calculateMaxTransferable(address user) internal view returns (uint256) {
        uint256 transferableAmount = 0;
        for (uint256 i = 0; i < userMintInfo[user].length; i++) {
            MintInfo memory info = userMintInfo[user][i];
            
            if (block.number > info.startBlock && block.number <= info.endBlock) {
                uint256 effectiveBlocks = block.number > info.endBlock ? info.endBlock - info.startBlock : block.number - info.startBlock;
                uint256 currentTransferable =( effectiveBlocks * info.exchangeRate ) / AMPLIFICATION_FACTOR ;
                transferableAmount += currentTransferable;
            }

        }
        return (transferableAmount * 2 * 125 * 10 ** decimals()) / 100;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    function _calculateExpiredMintInfo(address user) internal view returns (uint256) {
        uint256 expiredAmount = 0;
        for (uint256 i = 0; i < userMintInfo[user].length; i++) {
            MintInfo memory info = userMintInfo[user][i];
            if (block.number > info.endBlock) {
                expiredAmount += info.amount;
            }
        }
        return expiredAmount;
    }
  

    function balanceOfTransfer(address user) public view returns (uint256) {
        uint256 transferableAmount = _calculateMaxTransferable(user); // Call the existing method to calculate transferable amount

        // Calculate the amount already transferred
        uint256 transferredAlready = totalMinted[user] - balanceOf(user) - _calculateExpiredMintInfo(user);

        // Calculate the max transferable amount, applying the 30% limit and subtracting the already transferred amount
        uint256 maxTransferable = (totalMinted[user] * 30 / 100) - transferredAlready;
        if (transferableAmount > maxTransferable) {
            transferableAmount = maxTransferable; // Limit the transferable amount to 30% of total minted minus already transferred amount
        }

        return transferableAmount;
    }


}
