// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./SimpleGovernance.sol";

/**
 * @title SelfiePool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract SelfiePool is ReentrancyGuard {

    using Address for address;

    ERC20Snapshot public token;

    // governance 合约
    SimpleGovernance public governance;

    event FundsDrained(address indexed receiver, uint256 amount);

    // 确保函数的执行者是 governance 合约
    modifier onlyGovernance() {
        require(msg.sender == address(governance), "Only governance can execute this action");
        _;
    }

    constructor(address tokenAddress, address governanceAddress) {
        token = ERC20Snapshot(tokenAddress);
        governance = SimpleGovernance(governanceAddress);
    }

    // 闪电贷函数
    function flashLoan(uint256 borrowAmount) external nonReentrant {
        // 确保余额充足
        uint256 balanceBefore = token.balanceOf(address(this));
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");
        
        // 将 borrowAmount 数量的 token 转给 msg.sender
        token.transfer(msg.sender, borrowAmount);        
        
        // 确保 msg.sender 是合约地址
        require(msg.sender.isContract(), "Sender must be a deployed contract");

        // 调用 msg.sender 的 receiveTokens 方法
        msg.sender.functionCall(
            abi.encodeWithSignature(
                "receiveTokens(address,uint256)",
                address(token),
                borrowAmount
            )
        );

        // 确保已返还借出的token
        uint256 balanceAfter = token.balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "Flash loan hasn't been paid back");
    }

    // 提取该合约中的全部token, 并且智能由 governance 调用
    function drainAllFunds(address receiver) external onlyGovernance {
        // 获取余额
        uint256 amount = token.balanceOf(address(this));
        // 将 token 转给 receiver
        token.transfer(receiver, amount);
        
        emit FundsDrained(receiver, amount);
    }
}
