// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

/**
 * @title TrustfulOracle
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 * @notice A price oracle with a number of trusted sources that individually report prices for symbols.
 *         The oracle's price for a given symbol is the median price of the symbol over all sources.
 */
contract TrustfulOracle is AccessControlEnumerable {

    // 定义两种角色
    // INITIALIZER_ROLE 可以设置初始价格，并且只能调用一次
    // 只有 TRUSTED_SOURCE_ROLE 可以设置价格
    bytes32 public constant TRUSTED_SOURCE_ROLE = keccak256("TRUSTED_SOURCE_ROLE");
    bytes32 public constant INITIALIZER_ROLE = keccak256("INITIALIZER_ROLE");

    // 记录价格: 由哪个地址设置的哪个token价格是多少
    mapping(address => mapping (string => uint256)) private pricesBySource;

    modifier onlyTrustedSource() {
        require(hasRole(TRUSTED_SOURCE_ROLE, msg.sender));
        _;
    }

    modifier onlyInitializer() {
        require(hasRole(INITIALIZER_ROLE, msg.sender));
        _;
    }

    event UpdatedPrice(
        address indexed source,
        string indexed symbol,
        uint256 oldPrice,
        uint256 newPrice
    );

    constructor(address[] memory sources, bool enableInitialization) {
        require(sources.length > 0);
        // 分别给 sources 赋予 TRUSTED_SOURCE_ROLE
        for(uint256 i = 0; i < sources.length; i++) {
            _setupRole(TRUSTED_SOURCE_ROLE, sources[i]);
        }

        // 给 msg.sender 赋予 INITIALIZER_ROLE
        if (enableInitialization) {
            _setupRole(INITIALIZER_ROLE, msg.sender);
        }
    }

    // 设置初始价格, 只会调用一次，只有 INITIALIZER_ROLE 可以调用
    function setupInitialPrices(
        address[] memory sources,
        string[] memory symbols,
        uint256[] memory prices
    ) 
        public
        onlyInitializer
    {
        // Only allow one (symbol, price) per source
        require(sources.length == symbols.length && symbols.length == prices.length);

        // 设置价格
        for(uint256 i = 0; i < sources.length; i++) {
            _setPrice(sources[i], symbols[i], prices[i]);
        }
        // 取消 msg.sender 的 INITIALIZER_ROLE 权限
        renounceRole(INITIALIZER_ROLE, msg.sender);
    }

    // 设置 token 的价格，只有 TRUSTED_SOURCE_ROLE 角色可以设置价格
    function postPrice(string calldata symbol, uint256 newPrice) external onlyTrustedSource {
        _setPrice(msg.sender, symbol, newPrice);
    }

    // 获取中位数价格
    function getMedianPrice(string calldata symbol) external view returns (uint256) {
        return _computeMedianPrice(symbol);
    }

    // 获取某个 token 所有的价格列表
    function getAllPricesForSymbol(string memory symbol) public view returns (uint256[] memory) {
        // 获取 TRUSTED_SOURCE_ROLE 角色有多少
        uint256 numberOfSources = getNumberOfSources();
        // 定义定长数组 存储价格列表
        uint256[] memory prices = new uint256[](numberOfSources);

        // 遍历 TRUSTED_SOURCE_ROLE 角色下的所有地址
        for (uint256 i = 0; i < numberOfSources; i++) {
            // 获取 source
            address source = getRoleMember(TRUSTED_SOURCE_ROLE, i);
            // 获取价格
            prices[i] = getPriceBySource(symbol, source);
        }
        return prices;
    }

    // 获取价格
    function getPriceBySource(string memory symbol, address source) public view returns (uint256) {
        return pricesBySource[source][symbol];
    }

    // 获取 TRUSTED_SOURCE_ROLE 角色有多少地址
    function getNumberOfSources() public view returns (uint256) {
        return getRoleMemberCount(TRUSTED_SOURCE_ROLE);
    }

    // 设置价格 更新 pricesBySource 变量
    function _setPrice(address source, string memory symbol, uint256 newPrice) private {
        uint256 oldPrice = pricesBySource[source][symbol];
        pricesBySource[source][symbol] = newPrice;
        emit UpdatedPrice(source, symbol, oldPrice, newPrice);
    }

    // 计算中位数价格
    function _computeMedianPrice(string memory symbol) private view returns (uint256) {
        // 获取 TRUSTED_SOURCE_ROLE 角色有多少地址
        // 遍历这些角色，获取价格列表
        // 对价格排序
        uint256[] memory prices = _sort(getAllPricesForSymbol(symbol));

        // 计算中位数价格，如果是列表长度是偶数，则计算中间的两数的平均值，奇数则取中间值
        if (prices.length % 2 == 0) {
            uint256 leftPrice = prices[(prices.length / 2) - 1];
            uint256 rightPrice = prices[prices.length / 2];
            return (leftPrice + rightPrice) / 2;
        } else {
            return prices[prices.length / 2];
        }
    }

    // 使用 选择排序 对价格列表进行排序
    function _sort(uint256[] memory arrayOfNumbers) private pure returns (uint256[] memory) {
        for (uint256 i = 0; i < arrayOfNumbers.length; i++) {
            for (uint256 j = i + 1; j < arrayOfNumbers.length; j++) {
                if (arrayOfNumbers[i] > arrayOfNumbers[j]) {
                    uint256 tmp = arrayOfNumbers[i];
                    arrayOfNumbers[i] = arrayOfNumbers[j];
                    arrayOfNumbers[j] = tmp;
                }
            }
        }        
        return arrayOfNumbers;
    }
}