// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OperationsTreasury is Ownable {
    
    /**
     * @notice Allows the owner to withdraw a specified ERC20 token from the contract.
     * @param token The address of the ERC20 token to withdraw.
     * @param to The address where the funds will be sent.
     * @param amount The amount of tokens to withdraw.
     */
    function withdrawERC20(address token, address to, uint256 amount) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(to != address(0), "Invalid recipient address");
        
        IERC20(token).transfer(to, amount);
    }
}
