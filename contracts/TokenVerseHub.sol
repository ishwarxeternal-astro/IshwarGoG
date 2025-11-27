// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @title TokenVerse Hub
 * @notice A universal multi-token hub for:
 *         - Token registry
 *         - Internal token swaps
 *         - Staking + rewards
 *         - Token channels (collections)
 * @dev This is a template. Add access control, audits, routers, oracles, etc.
 */

interface IERC20 {
    function balanceOf(address user) external view returns (uint256);
    function transfer(address to, uint256 val) external returns (bool);
    function transferFrom(address from, address to, uint256 val) external returns (bool);
}

/* ------------------------------------------------------
   TokenVerse Hub
------------------------------------------------------*/
contract TokenVerseHub {
    // --------------------------------------------------
    // DATA STRUCTURES
    // --------------------------------------------------
    struct TokenInfo {
        bool registered;
        string name;
        string symbol;
        uint8 decimals;
    }

    struct Channel {
        uint256 id;
        string label;
        address[] tokens;        // token list
        bool exists;
    }

    struct StakingPool {
        uint256 id;
        address token;
        uint256 totalStaked;
        uint256 rewardRate;      // tokens per block
        mapping(address => uint256) balance;
        mapping(address => uint256) rewardDebt;
        uint256 accRewardPerShare;
        uint256 lastRewardBlock;
        bool exists;
    }

    address public owner;

    uint256 public channelCount;
    uint256 public poolCount;

    mapping(address => TokenInfo) public tokenRegistry;
    mapping(uint256 => Channel) public channels;
    mapping(uint256 => StakingPool) public pools;

    // --------------------------------------------------
    // EVENTS
    // --------------------------------------------------
    event TokenRegistered(address indexed token, string name, string symbol);
    event ChannelCreated(uint256 indexed id, string label);
    event PoolCreated(uint256 indexed id, address token, uint256 rewardRate);
    event Staked(uint256 indexed pid, address indexed user, uint256 amount);
    event Unstaked(uint256 indexed pid, address indexed user, uint256 amount);
    event RewardClaimed(uint256 indexed pid, address indexed user, uint256 amount);
    event SwapExecuted(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    // --------------------------------------------------
    // MODIFIER
    // --------------------------------------------------
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier validPool(uint256 pid) {
        require(pools[pid].exists, "Pool not found");
        _;
    }

    // --------------------------------------------------
    // CONSTRUCTOR
    // --------------------------------------------------
    constructor() {
        owner = msg.sender;
    }

    // --------------------------------------------------
    // TOKEN REGISTRY
    // --------------------------------------------------
    function registerToken(
        address token,
        string memory name,
        string memory symbol,
        uint8 decimals
    ) external onlyOwner {
        tokenRegistry[token] = TokenInfo(true, name, symbol, decimals);
        emit TokenRegistered(token, name, symbol);
    }

    function isTokenRegistered(address token) external view returns (bool) {
        return tokenRegistry[token].registered;
    }

    // --------------------------------------------------
    // CHANNEL MANAGEMENT
    // --------------------------------------------------
    function createChannel(
        string memory label,
        address[] memory tokens
    ) external onlyOwner returns (uint256) {
        channelCount++;

        channels[channelCount].id = channelCount;
        channels[channelCount].label = label;
        channels[channelCount].exists = true;

        for (uint256 i = 0; i < tokens.length; i++) {
            require(tokenRegistry[tokens[i]].registered, "Token not registered");
            channels[channelCount].tokens.push(tokens[i]);
        }

        emit ChannelCreated(channelCount, label);

        return channelCount;
    }

    // --------------------------------------------------
    // INTERNAL SWAP ENGINE (simple proportional swap)
    // --------------------------------------------------
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external returns (uint256 amountOut) {
        require(tokenRegistry[tokenIn].registered, "TokenIn not registered");
        require(tokenRegistry[tokenOut].registered, "TokenOut not registered");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // Simplified swap logic:
        // tokenOut amount = 99% of tokenIn for demonstration
        amountOut = (amountIn * 9900) / 10000;

        IERC20(tokenOut).transfer(msg.sender, amountOut);

        emit SwapExecuted(tokenIn, tokenOut, amountIn, amountOut);
    }

    // --------------------------------------------------
    // STAKING POOL
    // --------------------------------------------------
    function createStakingPool(
        address token,
        uint256 rewardRate
    ) external onlyOwner returns (uint256) {
        require(tokenRegistry[token].registered, "Token not registered");

        poolCount++;

        StakingPool storage p = pools[poolCount];
        p.id = poolCount;
        p.token = token;
        p.rewardRate = rewardRate;
        p.lastRewardBlock = block.number;
        p.exists = true;

        emit PoolCreated(poolCount, token, rewardRate);
        return poolCount;
    }

    function _updatePool(StakingPool storage p) internal {
        if (block.number <= p.lastRewardBlock) return;

        if (p.totalStaked > 0) {
            uint256 blocks = block.number - p.lastRewardBlock;
            uint256 reward = blocks * p.rewardRate;
            p.accRewardPerShare += reward * 1e12 / p.totalStaked;
        }

        p.lastRewardBlock = block.number;
    }

    // STAKE
    function stake(uint256 pid, uint256 amount) external validPool(pid) {
        StakingPool storage p = pools[pid];
        _updatePool(p);

        if (p.balance[msg.sender] > 0) {
            uint256 pending =
                (p.balance[msg.sender] * p.accRewardPerShare / 1e12)
                - p.rewardDebt[msg.sender];
            IERC20(p.token).transfer(msg.sender, pending);
            emit RewardClaimed(pid, msg.sender, pending);
        }

        IERC20(p.token).transferFrom(msg.sender, address(this), amount);

        p.balance[msg.sender] += amount;
        p.totalStaked += amount;
        p.rewardDebt[msg.sender] =
            p.balance[msg.sender] * p.accRewardPerShare / 1e12;

        emit Staked(pid, msg.sender, amount);
    }

    // UNSTAKE
    function unstake(uint256 pid, uint256 amount) external validPool(pid) {
        StakingPool storage p = pools[pid];
        require(p.balance[msg.sender] >= amount, "Not enough staked");

        _updatePool(p);

        uint256 pending =
            (p.balance[msg.sender] * p.accRewardPerShare / 1e12)
            - p.rewardDebt[msg.sender];

        IERC20(p.token).transfer(msg.sender, pending);
        emit RewardClaimed(pid, msg.sender, pending);

        p.balance[msg.sender] -= amount;
        p.totalStaked -= amount;

        IERC20(p.token).transfer(msg.sender, amount);

        p.rewardDebt[msg.sender] =
            p.balance[msg.sender] * p.accRewardPerShare / 1e12;

        emit Unstaked(pid, msg.sender, amount);
    }

    // --------------------------------------------------
    // ADMIN
    // --------------------------------------------------
    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}
