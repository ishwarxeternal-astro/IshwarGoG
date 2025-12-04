// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title TokenVerse Hub
 * @notice A decentralized multi-token hub that allows registration of ERC-20 tokens,
 *         token-to-token swapping, and liquidity pooling inside a unified protocol.
 */

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address user) external view returns (uint256);
}

contract TokenVerseHub {
    address public owner;
    uint256 public constant SWAP_FEE = 2; // 2% fee on swaps

    struct LiquidityPool {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        bool exists;
    }

    // poolId => LiquidityPool
    mapping(uint256 => LiquidityPool) public pools;
    uint256 public poolCount;

    event PoolCreated(uint256 indexed poolId, address tokenA, address tokenB);
    event LiquidityAdded(uint256 indexed poolId, uint256 amountA, uint256 amountB);
    event LiquidityRemoved(uint256 indexed poolId, uint256 amountA, uint256 amountB);
    event TokenSwapped(
        uint256 indexed poolId,
        address indexed user,
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Owner restricted");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice Create a liquidity pool between two tokens
     */
    function createPool(address tokenA, address tokenB) external onlyOwner returns (uint256) {
        require(tokenA != tokenB, "Same token not allowed");

        poolCount++;
        pools[poolCount] = LiquidityPool(tokenA, tokenB, 0, 0, true);

        emit PoolCreated(poolCount, tokenA, tokenB);
        return poolCount;
    }

    /**
     * @notice Add liquidity to a pool
     */
    function addLiquidity(uint256 poolId, uint256 amountA, uint256 amountB) external {
        LiquidityPool storage pool = pools[poolId];
        require(pool.exists, "Pool not found");

        IERC20(pool.tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(pool.tokenB).transferFrom(msg.sender, address(this), amountB);

        pool.reserveA += amountA;
        pool.reserveB += amountB;

        emit LiquidityAdded(poolId, amountA, amountB);
    }

    /**
     * @notice Remove liquidity from a pool
     */
    function removeLiquidity(uint256 poolId, uint256 amountA, uint256 amountB) external onlyOwner {
        LiquidityPool storage pool = pools[poolId];
        require(pool.exists, "Pool not found");
        require(pool.reserveA >= amountA && pool.reserveB >= amountB, "Insufficient reserves");

        pool.reserveA -= amountA;
        pool.reserveB -= amountB;

        IERC20(pool.tokenA).transfer(msg.sender, amountA);
        IERC20(pool.tokenB).transfer(msg.sender, amountB);

        emit LiquidityRemoved(poolId, amountA, amountB);
    }

    /**
     * @notice Swap tokenA for tokenB or vice-versa
     */
    function swap(uint256 poolId, address tokenIn, uint256 amountIn) external {
        LiquidityPool storage pool = pools[poolId];
        require(pool.exists, "Pool not found");
        require(amountIn > 0, "Zero input");

        bool isAToB = tokenIn == pool.tokenA;
        require(isAToB || tokenIn == pool.tokenB, "Invalid token input");

        address tokenOut = isAToB ? pool.tokenB : pool.tokenA;
        uint256 reserveIn = isAToB ? pool.reserveA : pool.reserveB;
        uint256 reserveOut = isAToB ? pool.reserveB : pool.reserveA;

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        reserveIn += amountIn;

        // Apply 2% fee
        uint256 amountAfterFee = amountIn - (amountIn * SWAP_FEE / 100);

        // XYK formula: output = (reserveOut * amountAfterFee) / (reserveIn + amountAfterFee)
        uint256 amountOut = (reserveOut * amountAfterFee) / (reserveIn + amountAfterFee);
        require(amountOut > 0, "Insufficient output");

        // Update reserves
        reserveOut -= amountOut;

        if (isAToB) {
            pool.reserveA = reserveIn;
            pool.reserveB = reserveOut;
        } else {
            pool.reserveB = reserveIn;
            pool.reserveA = reserveOut;
        }

        IERC20(tokenOut).transfer(msg.sender, amountOut);

        emit TokenSwapped(poolId, msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    function getPool(uint256 poolId) external view returns (LiquidityPool memory) {
        return pools[poolId];
    }
}
