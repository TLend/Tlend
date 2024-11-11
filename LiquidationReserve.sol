// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IComptroller {
    function getAccountLiquidity(address account) external view returns (uint, uint, uint);
    function getAssetsIn(address account) external view returns (address[] memory);
    function liquidateBorrowAllowed(address cTokenBorrowed, address cTokenCollateral, address liquidator, address borrower, uint repayAmount) external view returns (uint);
}

interface ICToken {
    function getAccountSnapshot(address account) external view returns (uint, uint, uint, uint);
    function liquidateBorrow(address borrower, uint repayAmount, address cTokenCollateral) external returns (uint);
}

interface ICErc20 is ICToken {
    function underlying() external view returns (address);
}

interface IERC20 {
    function approve(address spender, uint amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
}

interface IV3SwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
    

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

interface IUniswapV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

interface IQuoterV2 {
    struct QuoteExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint256 amount;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
    }

    function quoteExactOutputSingle(
        QuoteExactOutputSingleParams memory params
    ) external returns (
        uint256 amountIn,
        uint160 sqrtPriceX96After,
        uint32 initializedTicksCrossed,
        uint256 gasEstimate
    );
}

contract CompoundLiquidator {

    IComptroller public comptroller;
    address public cTLENDLP;
    address public X28;
    IV3SwapRouter public swapRouter;
    IUniswapV3Factory public factory;
    IQuoterV2 public quoterV2;
    uint24 public constant FEE_TIER = 3000;

    constructor( ) {
        comptroller = IComptroller(0xb7B397302D86c5764774BaE0676A374EEeDE5F8d);
        cTLENDLP = 0x500F50fc13EAc29c2AB37b037670B79d3b02D9fB;
        X28 = 0x8e5aaBFB44F78bD80A5Db482e3a63281Df66B7C4;
        swapRouter = IV3SwapRouter(0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E);
        factory = IUniswapV3Factory(0x0227628f3F023bb0B980b67D528571c95c6DaC1c);
        quoterV2 = IQuoterV2(0xEd1f6473345F45b75F8179591dd5bA1888cf2FB3);
        
    }

    struct LiquidationParams {
        address borrower;
        address cTokenBorrowed;
        address cTokenCollateral;
        uint repayAmount;
        address underlyingToken;
    }

    function _checkLiquidationParams(address borrower) internal view returns (bool, LiquidationParams memory) {
        (uint error, uint liquidity, uint shortfall) = comptroller.getAccountLiquidity(borrower);
        require(error == 0, "Error checking account liquidity");

        if (shortfall == 0) {
            return (false, LiquidationParams(address(0), address(0), address(0), 0, address(0)));
        }

        address[] memory assetsIn = comptroller.getAssetsIn(borrower);

        for (uint i = 0; i < assetsIn.length; i++) {
            address cTokenAddress = assetsIn[i];
            ICToken cToken = ICToken(cTokenAddress);

            (uint snapshotError, uint cTokenBalance, uint borrowBalance, uint exchangeRateMantissa) = cToken.getAccountSnapshot(borrower);
            require(snapshotError == 0, "Error getting account snapshot");

            if (borrowBalance > 0) {
                uint repayAmount = borrowBalance * 20 / 100;

                uint allowed = comptroller.liquidateBorrowAllowed(
                    cTokenAddress,
                    cTLENDLP,
                    address(this),
                    borrower,
                    repayAmount
                );

                if (allowed == 0) {
                    address underlyingToken = ICErc20(cTokenAddress).underlying();
                    return (true, LiquidationParams(borrower, cTokenAddress, cTLENDLP, repayAmount, underlyingToken));
                }
            }
        }

        return (false, LiquidationParams(address(0), address(0), address(0), 0, address(0)));
    }

    function checkAndLiquidate(address borrower) external view returns (bool, LiquidationParams memory) {
        return _checkLiquidationParams(borrower);
    }

   

    function estimateX28ForRepay(uint256 repayAmount, address underlyingToken) public  returns (uint256 amountIn) {
        IQuoterV2.QuoteExactOutputSingleParams memory params = IQuoterV2.QuoteExactOutputSingleParams({
            tokenIn: X28,
            tokenOut: underlyingToken,
            amount: repayAmount,
            fee: FEE_TIER,
            sqrtPriceLimitX96: 0 
        });

       
        (amountIn, , , ) = quoterV2.quoteExactOutputSingle(params);
    }
    function executeLiquidation(address borrower) external {
       
        (bool canLiquidate, LiquidationParams memory params) = _checkLiquidationParams(borrower);
        require(canLiquidate, "Borrower not eligible for liquidation");

       
        uint256 amountIn = estimateX28ForRepay(params.repayAmount, params.underlyingToken);

       
        IERC20(X28).approve(address(swapRouter), amountIn);

       
        IV3SwapRouter.ExactInputSingleParams memory swapParams = IV3SwapRouter.ExactInputSingleParams({
            tokenIn: X28,
            tokenOut: params.underlyingToken,
            fee: FEE_TIER,
            recipient: address(this),
            amountIn: amountIn,
            amountOutMinimum: params.repayAmount,
            sqrtPriceLimitX96: 0
        });

        
        uint256 amountOut = swapRouter.exactInputSingle(swapParams);
        require(amountOut >= params.repayAmount, "Insufficient underlying token for repayment");

       
        IERC20(params.underlyingToken).approve(params.cTokenBorrowed, params.repayAmount);
        ICToken(params.cTokenBorrowed).liquidateBorrow(params.borrower, params.repayAmount, params.cTokenCollateral);
    }

   

   
}
