// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "@uniswap/v2-periphery/contracts/libraries/SafeMath.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external returns (uint256);
}

/**
 * @title PuppetV2Pool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract PuppetV2Pool {
    using SafeMath for uint256;

    address private _uniswapPair;
    address private _uniswapFactory;
    IERC20 private _token;
    IERC20 private _weth;
    
    mapping(address => uint256) public deposits;
        
    event Borrowed(address indexed borrower, uint256 depositRequired, uint256 borrowAmount, uint256 timestamp);

    constructor (
        address wethAddress,
        address tokenAddress,
        address uniswapPairAddress,
        address uniswapFactoryAddress
    ) public {
        _weth = IERC20(wethAddress);
        _token = IERC20(tokenAddress);
        _uniswapPair = uniswapPairAddress;
        _uniswapFactory = uniswapFactoryAddress;
    }

    /**
     * @notice Allows borrowing `borrowAmount` of tokens by first depositing three times their value in WETH
     *         Sender must have approved enough WETH in advance.
     *         Calculations assume that WETH and borrowed token have same amount of decimals.
     */
    function borrow(uint256 borrowAmount) external {
        require(_token.balanceOf(address(this)) >= borrowAmount, "Not enough token balance");

        // 计算需要存多少WETH
        uint256 depositOfWETHRequired = calculateDepositOfWETHRequired(borrowAmount);
        
        // 转WETH到该合约中
        _weth.transferFrom(msg.sender, address(this), depositOfWETHRequired);

        // 记录存入的WETH
        deposits[msg.sender] += depositOfWETHRequired;

        // 将 DVT token 转给 msg.sender
        require(_token.transfer(msg.sender, borrowAmount));

        emit Borrowed(msg.sender, depositOfWETHRequired, borrowAmount, block.timestamp);
    }

    function calculateDepositOfWETHRequired(uint256 tokenAmount) public view returns (uint256) {
        // 抵押物的价值是3倍于借出的DVT
        return _getOracleQuote(tokenAmount).mul(3) / (10 ** 18);
    }

    function _getOracleQuote(uint256 amount) private view returns (uint256) {
        // 获取 WETH 和 DVT 的储备量
        // getReserves 内部计算配对合约的地址，并返回配对的 Token 的储备量
        (uint256 reservesWETH, uint256 reservesToken) = UniswapV2Library.getReserves(
            _uniswapFactory, address(_weth), address(_token)
        );
        // 计算DVT的价值
        // amount / x = reservesToken / reservesWETH
        // x = (amount * reservesWETH) / reservesToken
        return UniswapV2Library.quote(amount.mul(10 ** 18), reservesToken, reservesWETH);
    }
}
