--------------------------------------------------
    --------------------------------------------------
    struct TokenInfo {
        bool registered;
        string name;
        string symbol;
        uint8 decimals;
    }

    struct Channel {
        uint256 id;
        string label;
        address[] tokens;        tokens per block
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

    EVENTS
    --------------------------------------------------
    --------------------------------------------------
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier validPool(uint256 pid) {
        require(pools[pid].exists, "Pool not found");
        _;
    }

    CONSTRUCTOR
    --------------------------------------------------
    --------------------------------------------------
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

    CHANNEL MANAGEMENT
    --------------------------------------------------
    --------------------------------------------------
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external returns (uint256 amountOut) {
        require(tokenRegistry[tokenIn].registered, "TokenIn not registered");
        require(tokenRegistry[tokenOut].registered, "TokenOut not registered");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        tokenOut amount = 99% of tokenIn for demonstration
        amountOut = (amountIn * 9900) / 10000;

        IERC20(tokenOut).transfer(msg.sender, amountOut);

        emit SwapExecuted(tokenIn, tokenOut, amountIn, amountOut);
    }

    STAKING POOL
    STAKE
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

    --------------------------------------------------
    --------------------------------------------------
    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}
// 
Contract End
// 
