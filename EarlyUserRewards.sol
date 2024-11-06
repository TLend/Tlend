// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract EarlyUserRewards is AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 public constant MAX_WHITELISTED_USERS = 1000;

    IERC20 public titanxToken;
    address[] public whitelistedUsers;
    mapping(address => bool) public isWhitelisted;
    mapping(address => uint256) public claimedRewards;
    uint256 public totalRewards;
    uint256 public lastDistributedRewards;

    event UserWhitelisted(address indexed user);
    event RewardsDistributed(uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);

    constructor(address _titanxToken) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        titanxToken = IERC20(_titanxToken);
    }

    // Admin can add users to the whitelist
    function addWhitelistedUsers(address[] calldata users) external onlyRole(ADMIN_ROLE) {
        require(
            whitelistedUsers.length + users.length <= MAX_WHITELISTED_USERS,
            "Exceeds maximum number of whitelisted users"
        );
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            require(!isWhitelisted[user], "User is already whitelisted");
            isWhitelisted[user] = true;
            whitelistedUsers.push(user);
            emit UserWhitelisted(user);
        }
    }

    // Distribute rewards to the contract (called by TLEND contract)
    function distributeRewards(uint256 amount) external {
        titanxToken.safeTransferFrom(msg.sender, address(this), amount);
        totalRewards += amount;
        emit RewardsDistributed(amount);
    }

    // Users can claim their share of the rewards
    function claim() external {
        require(isWhitelisted[msg.sender], "You are not whitelisted");
        uint256 claimableAmount = getClaimableAmount(msg.sender);
        require(claimableAmount > 0, "No rewards to claim");

        claimedRewards[msg.sender] += claimableAmount;
        titanxToken.safeTransfer(msg.sender, claimableAmount);

        emit RewardClaimed(msg.sender, claimableAmount);
    }

    // Calculate the claimable amount for a user
    function getClaimableAmount(address user) public view returns (uint256) {
        if (!isWhitelisted[user] || whitelistedUsers.length == 0) {
            return 0;
        }

        uint256 sharePerUser = totalRewards / whitelistedUsers.length;
        uint256 claimed = claimedRewards[user];
        return sharePerUser > claimed ? sharePerUser - claimed : 0;
    }

    // View the total number of whitelisted users
    function getWhitelistedUserCount() external view returns (uint256) {
        return whitelistedUsers.length;
    }

    // Admin can remove users from the whitelist (for flexibility)
    function removeWhitelistedUser(address user) external onlyRole(ADMIN_ROLE) {
        require(isWhitelisted[user], "User is not whitelisted");
        isWhitelisted[user] = false;

        // Find and remove the user from the array
        for (uint256 i = 0; i < whitelistedUsers.length; i++) {
            if (whitelistedUsers[i] == user) {
                whitelistedUsers[i] = whitelistedUsers[whitelistedUsers.length - 1];
                whitelistedUsers.pop();
                break;
            }
        }
    }
}
