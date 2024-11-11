// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";


contract TLENDLiquidityManager is Ownable {
    INonfungiblePositionManager public positionManager;
    IUniswapV3Factory public factory;
    IERC20 public x28Token;
    IERC20 public tlendToken;

    IERC20 public token0; // Example ERC20 token
    IERC20 public token1; //  Example ERC20 token

    uint256 public maxX28Amount = 300_000_000 * 10**18; // Max X28 amount per liquidity addition
    uint256 public lastAddLiquidityTime;
    uint256 public constant ADD_LIQUIDITY_INTERVAL = 180 * 60; // 280 minutes in seconds

    address public recipient = address(this);

    constructor() {
        positionManager = INonfungiblePositionManager(0x1238536071E1c677A632429e3655c799b22cDA52);
        factory = IUniswapV3Factory(0x0227628f3F023bb0B980b67D528571c95c6DaC1c);

    }

    function setTokens(address _x28Token, address _tlendToken) external onlyOwner {
        x28Token = IERC20(_x28Token);
        tlendToken = IERC20(_tlendToken);
        _updateTokenOrder();
    }

    function setMaxX28Amount(uint256 _maxAmount) external onlyOwner {
        maxX28Amount = _maxAmount;
    }

    function setRecipient(address _recipient) external onlyOwner {
        recipient = _recipient;
    }

    
     function addSingleSidedLiquidity( ) external {
        require(canAddLiquidity(), "Cannot add liquidity yet");
        uint256 amount = maxX28Amount;
         bool isToken0;
        if(token1 == x28Token){
            isToken0 = false;
        }else{
            isToken0 = true;
        }
       
        // Fetch the current pool address from the Uniswap V3 factory
        address poolAddress = IUniswapV3Factory(positionManager.factory()).getPool(address(token0), address(token1), 3000);
        require(poolAddress != address(0), "Pool not found");

        // Get the current price and tick from the pool
        ( , int24 currentTick, , , , , ) = IUniswapV3Pool(poolAddress).slot0();

        int24 tickSpacing = 60; // Example tick spacing
        int24 tickLower;
        int24 tickUpper;

        // Determine the tick range based on whether it's token0 or token1
        if (isToken0) {
            // Add liquidity with token0, so we want the range to be below the current tick
            tickLower = currentTick - (currentTick % tickSpacing)+ (tickSpacing * 10); 
            tickUpper = currentTick - (currentTick % tickSpacing)+(tickSpacing * 30);
          
        } else {
            // Add liquidity with token1, so we want the range to be above the current tick
            tickLower = currentTick - ((currentTick % tickSpacing + tickSpacing) % tickSpacing) - (tickSpacing * 10);
            tickUpper = currentTick - ((currentTick % tickSpacing + tickSpacing) % tickSpacing);
          
        }
       
        if (isToken0) {
            require(token0.balanceOf(address(this)) >= amount, "Insufficient token0 balance in contract");
            token0.approve(address(positionManager), amount);

            INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
                token0: address(token0),
                token1: address(token1),
                fee: 3000,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount,
                amount1Desired: 0,
                amount0Min: (amount * 9900) / 10000,
                amount1Min: 0,
                recipient: recipient,
                deadline: block.timestamp + 600
            });

            positionManager.mint(params);
        } else {
            require(token1.balanceOf(address(this)) >= amount, "Insufficient token1 balance in contract");
            token1.approve(address(positionManager), amount);

            INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
                token0: address(token0),
                token1: address(token1),
                fee: 3000,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: 0,
                amount1Desired: amount,
                amount0Min: 0,
                amount1Min: amount,
                recipient: recipient,
                deadline: block.timestamp + 600
            });

            positionManager.mint(params);
        }

        // Update lastAddLiquidityTime after successful addition of liquidity
        lastAddLiquidityTime = block.timestamp;
    }

    // Update token order based on addresses
    function _updateTokenOrder() internal {
        if (address(x28Token) < address(tlendToken)) {
            token0 = x28Token;
            token1 = tlendToken;
        } else {
            token0 = tlendToken;
            token1 = x28Token;
        }
    }

    // Function to check if liquidity can be added
    function canAddLiquidity() public view returns (bool) {
        bool timeCondition = (block.timestamp >= lastAddLiquidityTime + ADD_LIQUIDITY_INTERVAL);
        bool balanceCondition = x28Token.balanceOf(address(this)) >= maxX28Amount;
        return timeCondition && balanceCondition;
    }
}
