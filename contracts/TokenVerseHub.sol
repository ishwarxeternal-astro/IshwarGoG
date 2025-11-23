// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title TokenVerse Hub
 * @dev A comprehensive hub for managing multiple tokens, staking, and rewards
 */
contract TokenVerseHub {
    
    // Structs
    struct Token {
        string name;
        string symbol;
        uint256 totalSupply;
        address creator;
        bool isActive;
    }
    
    struct StakeInfo {
        uint256 amount;
        uint256 timestamp;
        uint256 rewardDebt;
    }
    
    // State variables
    address public owner;
    uint256 public tokenCount;
    uint256 public rewardRate = 100; // Rewards per second per token staked
    
    mapping(uint256 => Token) public tokens;
    mapping(uint256 => mapping(address => uint256)) public balances;
    mapping(uint256 => mapping(address => StakeInfo)) public stakes;
    mapping(address => bool) public verifiedCreators;
    
    // Events
    event TokenCreated(uint256 indexed tokenId, string name, string symbol, address creator);
    event TokenTransferred(uint256 indexed tokenId, address from, address to, uint256 amount);
    event TokenStaked(uint256 indexed tokenId, address user, uint256 amount);
    event TokenUnstaked(uint256 indexed tokenId, address user, uint256 amount);
    event RewardsClaimed(uint256 indexed tokenId, address user, uint256 reward);
    event CreatorVerified(address creator);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }
    
    modifier tokenExists(uint256 _tokenId) {
        require(_tokenId < tokenCount, "Token does not exist");
        require(tokens[_tokenId].isActive, "Token is not active");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        verifiedCreators[msg.sender] = true;
    }
    
    /**
     * @dev Function 1: Create a new token
     */
    function createToken(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply
    ) public returns (uint256) {
        uint256 tokenId = tokenCount;
        
        tokens[tokenId] = Token({
            name: _name,
            symbol: _symbol,
            totalSupply: _initialSupply,
            creator: msg.sender,
            isActive: true
        });
        
        balances[tokenId][msg.sender] = _initialSupply;
        tokenCount++;
        
        emit TokenCreated(tokenId, _name, _symbol, msg.sender);
        return tokenId;
    }
    
    /**
     * @dev Function 2: Transfer tokens
     */
    function transferToken(
        uint256 _tokenId,
        address _to,
        uint256 _amount
    ) public tokenExists(_tokenId) {
        require(_to != address(0), "Invalid recipient");
        require(balances[_tokenId][msg.sender] >= _amount, "Insufficient balance");
        
        balances[_tokenId][msg.sender] -= _amount;
        balances[_tokenId][_to] += _amount;
        
        emit TokenTransferred(_tokenId, msg.sender, _to, _amount);
    }
    
    /**
     * @dev Function 3: Stake tokens
     */
    function stakeTokens(uint256 _tokenId, uint256 _amount) public tokenExists(_tokenId) {
        require(_amount > 0, "Amount must be greater than 0");
        require(balances[_tokenId][msg.sender] >= _amount, "Insufficient balance");
        
        // Claim pending rewards first
        if (stakes[_tokenId][msg.sender].amount > 0) {
            claimRewards(_tokenId);
        }
        
        balances[_tokenId][msg.sender] -= _amount;
        stakes[_tokenId][msg.sender].amount += _amount;
        stakes[_tokenId][msg.sender].timestamp = block.timestamp;
        
        emit TokenStaked(_tokenId, msg.sender, _amount);
    }
    
    /**
     * @dev Function 4: Unstake tokens
     */
    function unstakeTokens(uint256 _tokenId, uint256 _amount) public tokenExists(_tokenId) {
        require(stakes[_tokenId][msg.sender].amount >= _amount, "Insufficient staked amount");
        
        // Claim pending rewards first
        claimRewards(_tokenId);
        
        stakes[_tokenId][msg.sender].amount -= _amount;
        balances[_tokenId][msg.sender] += _amount;
        
        emit TokenUnstaked(_tokenId, msg.sender, _amount);
    }
    
    /**
     * @dev Function 5: Claim staking rewards
     */
    function claimRewards(uint256 _tokenId) public tokenExists(_tokenId) {
        StakeInfo storage stake = stakes[_tokenId][msg.sender];
        require(stake.amount > 0, "No tokens staked");
        
        uint256 reward = calculateRewards(_tokenId, msg.sender);
        
        if (reward > 0) {
            stake.timestamp = block.timestamp;
            balances[_tokenId][msg.sender] += reward;
            
            emit RewardsClaimed(_tokenId, msg.sender, reward);
        }
    }
    
    /**
     * @dev Function 6: Calculate pending rewards
     */
    function calculateRewards(uint256 _tokenId, address _user) public view returns (uint256) {
        StakeInfo memory stake = stakes[_tokenId][_user];
        
        if (stake.amount == 0) {
            return 0;
        }
        
        uint256 timeStaked = block.timestamp - stake.timestamp;
        uint256 reward = (stake.amount * timeStaked * rewardRate) / 1e18;
        
        return reward;
    }
    
    /**
     * @dev Function 7: Get token balance
     */
    function getBalance(uint256 _tokenId, address _user) public view returns (uint256) {
        return balances[_tokenId][_user];
    }
    
    /**
     * @dev Function 8: Get staked amount
     */
    function getStakedAmount(uint256 _tokenId, address _user) public view returns (uint256) {
        return stakes[_tokenId][_user].amount;
    }
    
    /**
     * @dev Function 9: Verify creator
     */
    function verifyCreator(address _creator) public onlyOwner {
        verifiedCreators[_creator] = true;
        emit CreatorVerified(_creator);
    }
    
    /**
     * @dev Function 10: Update reward rate
     */
    function updateRewardRate(uint256 _newRate) public onlyOwner {
        require(_newRate > 0, "Rate must be greater than 0");
        rewardRate = _newRate;
    }
    
    /**
     * @dev Get token information
     */
    function getTokenInfo(uint256 _tokenId) public view tokenExists(_tokenId) returns (
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        address creator,
        bool isActive
    ) {
        Token memory token = tokens[_tokenId];
        return (token.name, token.symbol, token.totalSupply, token.creator, token.isActive);
    }
}