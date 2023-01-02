// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./TrustfulOracle.sol";
import "../DamnValuableNFT.sol";

/**
 * @title Exchange
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract Exchange is ReentrancyGuard {

    using Address for address payable;

    // NFT token
    DamnValuableNFT public immutable token;
    // 预言机合约
    TrustfulOracle public immutable oracle;

    event TokenBought(address indexed buyer, uint256 tokenId, uint256 price);
    event TokenSold(address indexed seller, uint256 tokenId, uint256 price);

    constructor(address oracleAddress) payable {
        token = new DamnValuableNFT();
        oracle = TrustfulOracle(oracleAddress);
    }

    // 购买NFT
    function buyOne() external payable nonReentrant returns (uint256) {
        // 获取支付的金额
        uint256 amountPaidInWei = msg.value;
        require(amountPaidInWei > 0, "Amount paid must be greater than zero");

        // 获取当前价格
        uint256 currentPriceInWei = oracle.getMedianPrice(token.symbol());

        // 要求支付的金额不小于当前价格
        require(amountPaidInWei >= currentPriceInWei, "Amount paid is not enough");

        // 铸造一个 NFT 发送给 msg.sender
        uint256 tokenId = token.safeMint(msg.sender);

        // 找零, 将支付多余的金额还给 msg.sender
        payable(msg.sender).sendValue(amountPaidInWei - currentPriceInWei);

        emit TokenBought(msg.sender, tokenId, currentPriceInWei);

        return tokenId;
    }

    // 出售NFT
    function sellOne(uint256 tokenId) external nonReentrant {
        // 确认调用者是持有人
        require(msg.sender == token.ownerOf(tokenId), "Seller must be the owner");
        // 确保出售的NFT已经授权给该合约
        require(token.getApproved(tokenId) == address(this), "Seller must have approved transfer");

        // Price should be in [wei / NFT]
        uint256 currentPriceInWei = oracle.getMedianPrice(token.symbol());
        // 确保该合约的余额不小于当前价格
        require(address(this).balance >= currentPriceInWei, "Not enough ETH in balance");

        // 将 NFT 从 msg.sender 转移到该合约
        token.transferFrom(msg.sender, address(this), tokenId);

        // 销毁 tokenId 对应的NFT
        token.burn(tokenId);

        // 从合约付款给 msg.sender
        payable(msg.sender).sendValue(currentPriceInWei);

        emit TokenSold(msg.sender, tokenId, currentPriceInWei);
    }

    receive() external payable {}
}
