// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/swap-router-contracts/contracts/interfaces/ISwapRouter02.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract PurchaseManager is Ownable {
    IV3SwapRouter public swapRouter;
    IUniswapV3Factory public factory;
    IERC20 public titanxToken;
    IERC20 public tlendToken;

    uint256 public maxTITANXAmount = 300_000_000 * 10**18; // Max TITANX amount per swap
    uint256 public lastSwapTime;
    uint256 public constant SWAP_INTERVAL = 180 * 60; // 180 minutes in seconds
    uint24 public feeTier = 3000; // Uniswap V3 fee tier for the pool

    constructor(
      
        address _titanxToken,
        address _tlendToken
    ) {
        swapRouter = IV3SwapRouter(0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E);
        factory = IUniswapV3Factory(0x0227628f3F023bb0B980b67D528571c95c6DaC1c);
        titanxToken = IERC20(_titanxToken);
        tlendToken = IERC20(_tlendToken);
    }

    function setMaxTITANXAmount(uint256 _maxAmount) external onlyOwner {
        maxTITANXAmount = _maxAmount;
    }

    function setFeeTier(uint24 _feeTier) external onlyOwner {
        feeTier = _feeTier;
    }

    function canSwap() public view returns (bool) {
        bool timeCondition = (block.timestamp >= lastSwapTime + SWAP_INTERVAL);
        bool balanceCondition = titanxToken.balanceOf(address(this)) >= maxTITANXAmount;
        return timeCondition && balanceCondition;
    }

    function swapToken1ForMaxToken0() external {
        require(canSwap(), "Cannot swap yet");

        uint256 amountIn = maxTITANXAmount;

        // Approve swapRouter to spend titanxToken if needed
        titanxToken.approve(address(swapRouter), amountIn);

        // Check pool existence
        address poolAddress = factory.getPool(address(titanxToken), address(tlendToken), feeTier);
        require(poolAddress != address(0), "Pool does not exist");

        // Verify allowance and balance
        uint256 allowance = titanxToken.allowance(address(this), address(swapRouter));
        require(allowance >= amountIn, "Insufficient TITANX allowance");

        uint256 balance = titanxToken.balanceOf(address(this));
        require(balance >= amountIn, "Insufficient TITANX balance");

       // Set up parameters for exactInputSingle
        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter.ExactInputSingleParams({
            tokenIn: address(titanxToken),
            tokenOut: address(tlendToken),
            fee: feeTier,
            recipient: address(this),
            amountIn: amountIn,
            amountOutMinimum: 1,
            sqrtPriceLimitX96: 0
        });

        uint256 amountOut = swapRouter.exactInputSingle(params);

        // If there is output, transfer TLEND to a burn address or the contract itself, if needed
        if (amountOut > 0) {
            tlendToken.transfer(0x000000000000000000000000000000000000dEaD, amountOut);
        }

        // Update lastSwapTime after a successful swap
        lastSwapTime = block.timestamp;
    }
}
