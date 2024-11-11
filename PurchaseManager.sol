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
    IERC20 public x28Token;
    IERC20 public tlendToken;
    address public comptroller;

    uint256 public maxX28Amount = 300_000_000 * 10**18; // Max X28 amount per swap
    uint256 public lastSwapTime;
    uint256 public constant SWAP_INTERVAL = 180 * 60; // 180 minutes in seconds
    uint24 public feeTier = 3000; // Uniswap V3 fee tier for the pool

    constructor(
      
        address _x28Token,
        address _tlendToken
    ) {
        swapRouter = IV3SwapRouter(0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E);
        factory = IUniswapV3Factory(0x0227628f3F023bb0B980b67D528571c95c6DaC1c);
        x28Token = IERC20(_x28Token);
        tlendToken = IERC20(_tlendToken);
    }

    function setMaxX28Amount(uint256 _maxAmount) external onlyOwner {
        maxX28Amount = _maxAmount;
    }

    function setFeeTier(uint24 _feeTier) external onlyOwner {
        feeTier = _feeTier;
    }

    function setComptroller(address _comptroller) external onlyOwner {
        comptroller = _comptroller;
    }

    function canSwap() public view returns (bool) {
        bool timeCondition = (block.timestamp >= lastSwapTime + SWAP_INTERVAL);
        bool balanceCondition = x28Token.balanceOf(address(this)) >= maxX28Amount;
        return timeCondition && balanceCondition;
    }

    function swapToken1ForMaxToken0() external {
        require(canSwap(), "Cannot swap yet");

        uint256 amountIn = maxX28Amount;

        // Approve swapRouter to spend x28Token if needed
        x28Token.approve(address(swapRouter), amountIn);

        // Check pool existence
        address poolAddress = factory.getPool(address(x28Token), address(tlendToken), feeTier);
        require(poolAddress != address(0), "Pool does not exist");

        // Verify allowance and balance
        uint256 allowance = x28Token.allowance(address(this), address(swapRouter));
        require(allowance >= amountIn, "Insufficient X28 allowance");

        uint256 balance = x28Token.balanceOf(address(this));
        require(balance >= amountIn, "Insufficient X28 balance");

       // Set up parameters for exactInputSingle
        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter.ExactInputSingleParams({
            tokenIn: address(x28Token),
            tokenOut: address(tlendToken),
            fee: feeTier,
            recipient: address(this),
            amountIn: amountIn,
            amountOutMinimum: 1,
            sqrtPriceLimitX96: 0
        });

        uint256 amountOut = swapRouter.exactInputSingle(params);

        // Distribute 20% to comptroller and burn 80%
        uint256 toComptroller = (amountOut * 20) / 100;
        uint256 toBurn = amountOut - toComptroller;

        if (toComptroller > 0) {
            tlendToken.transfer(comptroller, toComptroller);
        }
        if (toBurn > 0) {
            tlendToken.transfer(0x000000000000000000000000000000000000dEaD, toBurn);
        }

        // Update lastSwapTime after a successful swap
        lastSwapTime = block.timestamp;
    }
}
