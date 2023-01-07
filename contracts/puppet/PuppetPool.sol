// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../DamnValuableToken.sol";

/**
 * @title PuppetPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract PuppetPool is ReentrancyGuard {

    using Address for address payable;

    // 记录地址存入的金额
    mapping(address => uint256) public deposits;
    // ETH-DVT 配对合约的地址
    address public immutable uniswapPair;
    // DVT token 实例
    DamnValuableToken public immutable token;
    
    event Borrowed(address indexed account, uint256 depositRequired, uint256 borrowAmount);

    constructor (address tokenAddress, address uniswapPairAddress) {
        token = DamnValuableToken(tokenAddress);
        uniswapPair = uniswapPairAddress;
    }

    // 借出 DVT，但前提是存入两倍价值的等额 ETH
    function borrow(uint256 borrowAmount) public payable nonReentrant {
        // 计算需要存入的ETH数量
        uint256 depositRequired = calculateDepositRequired(borrowAmount);
        
        require(msg.value >= depositRequired, "Not depositing enough collateral");

        // 返还多存的ETH
        if (msg.value > depositRequired) {
            payable(msg.sender).sendValue(msg.value - depositRequired);
        }

        // 保存 msg.sender 存入的ETH数量
        deposits[msg.sender] = deposits[msg.sender] + depositRequired;

        // 将DVT token 转给 msg.sender
        require(token.transfer(msg.sender, borrowAmount), "Transfer failed");

        emit Borrowed(msg.sender, depositRequired, borrowAmount);
    }

    // 计算需要存入的 eth 数量
    function calculateDepositRequired(uint256 amount) public view returns (uint256) {
        // 抵押的价值 = 借出的数量 * 价格 * 2
        return amount * _computeOraclePrice() * 2 / 10 ** 18;
    }

    // 计算每个token的价值等同于多少eth
    // 初始 uniswapPair 中有 100ETH 和 10 DVT => 每个DVT的价值 = 10 eth
    // 每个token的价值 = eth余额 / token余额
    function _computeOraclePrice() private view returns (uint256) {
        // calculates the price of the token in wei according to Uniswap pair
        return uniswapPair.balance * (10 ** 18) / token.balanceOf(uniswapPair);
    }

    /**
    ... functions to deposit, redeem, repay, calculate interest, and so on ...
    */
}
