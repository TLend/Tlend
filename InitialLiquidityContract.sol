// SPDX-License-Identifier: MIT
pragma solidity ^0.7.5;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract InitialLiquidityContract is AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    IERC20 public x28Token;
    IERC20 public tlendToken;

    uint256 public constant X28_TARGET_BALANCE = 30_000_000_000 * 10**18; 
    uint256 public constant TLEND_TARGET_BALANCE = 1_000_000_000 * 10**18;   

    constructor() {
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Allows the owner to withdraw a specified ERC20 token from the contract.
     * @param token The address of the ERC20 token to withdraw.
     * @param to The address where the funds will be sent.
     * @param amount The amount of tokens to withdraw.
     */
    function withdrawERC20(address token, address to, uint256 amount) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(token != address(0), "Invalid token address");
        require(to != address(0), "Invalid recipient address");

        IERC20(token).safeTransfer(to, amount);
    }

    /**
     * @notice Sets the address of the X28 token.
     * @param _x28Token The address of the X28 token contract.
     */
    function setx28Token(address _x28Token) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        
        require(_x28Token != address(0), "Invalid X28 token address");
        x28Token = IERC20(_x28Token);
    }

    /**
     * @notice Sets the address of the TLEND token.
     * @param _tlendToken The address of the TLEND token contract.
     */
    function setTlendToken(address _tlendToken) external  {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(_tlendToken != address(0), "Invalid TLEND token address");
        tlendToken = IERC20(_tlendToken);
    }
}
