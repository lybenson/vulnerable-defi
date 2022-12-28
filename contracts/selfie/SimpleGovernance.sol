// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../DamnValuableTokenSnapshot.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title SimpleGovernance
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract SimpleGovernance {

    using Address for address;

    struct GovernanceAction {
        address receiver;
        bytes data;
        uint256 weiAmount;
        uint256 proposedAt;
        uint256 executedAt;
    }
    // 治理 token
    DamnValuableTokenSnapshot public governanceToken;
    // 存储所有 action 的 mapping
    mapping(uint256 => GovernanceAction) public actions;
    // action 计数
    uint256 private actionCounter;
    uint256 private ACTION_DELAY_IN_SECONDS = 2 days;

    event ActionQueued(uint256 actionId, address indexed caller);
    event ActionExecuted(uint256 actionId, address indexed caller);

    // 构造函数, 传入治理 token 地址
    constructor(address governanceTokenAddress) {
        require(governanceTokenAddress != address(0), "Governance token cannot be zero address");
        governanceToken = DamnValuableTokenSnapshot(governanceTokenAddress);
        actionCounter = 1;
    }

    // 创建一个 action
    function queueAction(address receiver, bytes calldata data, uint256 weiAmount) external returns (uint256) {
        // 确保有足够的投票
        require(_hasEnoughVotes(msg.sender), "Not enough votes to propose an action");
        // 确保 reveiver 不能是该合约
        require(receiver != address(this), "Cannot queue actions that affect Governance");

        // 将 action 保存到 actions 中
        uint256 actionId = actionCounter;
        GovernanceAction storage actionToQueue = actions[actionId];
        actionToQueue.receiver = receiver;
        actionToQueue.weiAmount = weiAmount;
        actionToQueue.data = data;
        actionToQueue.proposedAt = block.timestamp;

        actionCounter++;

        emit ActionQueued(actionId, msg.sender);

        // 返回 actionId
        return actionId;
    }

    // 执行创建的 action
    function executeAction(uint256 actionId) external payable {
        // 创建的 action 是否可以被执行
        require(_canBeExecuted(actionId), "Cannot execute this action");
        
        // 取出当前最新的待执行的 action
        GovernanceAction storage actionToExecute = actions[actionId];
        // 设置执行时间为当前时间
        actionToExecute.executedAt = block.timestamp;

        // 执行 action.reveiver 的 data
        actionToExecute.receiver.functionCallWithValue(
            actionToExecute.data,
            actionToExecute.weiAmount
        );

        emit ActionExecuted(actionId, msg.sender);
    }

    function getActionDelay() public view returns (uint256) {
        return ACTION_DELAY_IN_SECONDS;
    }

    /**
     * @dev an action can only be executed if:
     * 1) it's never been executed before and
     * 2) enough time has passed since it was first proposed
     */
    //  判断一个 action 是否可以被执行
    // 1. 从来没有执行过
    // 2. 创建时间超过 2 days
    function _canBeExecuted(uint256 actionId) private view returns (bool) {
        GovernanceAction memory actionToExecute = actions[actionId];
        return (
            actionToExecute.executedAt == 0 &&
            (block.timestamp - actionToExecute.proposedAt >= ACTION_DELAY_IN_SECONDS)
        );
    }

    // 判断是否有足够的投票
    // 拥有的 governanceToken 数量大于总量的一半
    function _hasEnoughVotes(address account) private view returns (bool) {
        uint256 balance = governanceToken.getBalanceAtLastSnapshot(account);
        uint256 halfTotalSupply = governanceToken.getTotalSupplyAtLastSnapshot() / 2;
        return balance > halfTotalSupply;
    }
}
