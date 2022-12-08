const { ethers } = require('hardhat')
const { expect } = require('chai')

describe('[Challenge] Truster', function () {
  let deployer, attacker

  // eth 转换为 wei 乘以 1000000 * 10^18
  const TOKENS_IN_POOL = ethers.utils.parseEther('1000000')
  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, attacker] = await ethers.getSigners()

    const DamnValuableToken = await ethers.getContractFactory('DamnValuableToken', deployer)
    const TrusterLenderPool = await ethers.getContractFactory('TrusterLenderPool', deployer)

    this.token = await DamnValuableToken.deploy()
    this.pool = await TrusterLenderPool.deploy(this.token.address)

    // 向 pool 合约地址转入 1000000 eth
    await this.token.transfer(this.pool.address, TOKENS_IN_POOL)

    expect(
      await this.token.balanceOf(this.pool.address)
    ).to.equal(TOKENS_IN_POOL)

    expect(
      await this.token.balanceOf(attacker.address)
    ).to.equal('0')
  })

  it('Exploit', async function () {
    const TrusterAttack = await ethers.getContractFactory('TrusterAttack', deployer)
    const trusterAttack = await TrusterAttack.deploy(this.pool.address, this.token.address)

    await trusterAttack.connect(attacker).attack(deployer.address)
  })

  after(async function () {
    /** SUCCESS CONDITIONS */

    // Attacker has taken all tokens from the pool
    expect(
      await this.token.balanceOf(attacker.address)
    ).to.equal(TOKENS_IN_POOL)
    expect(
      await this.token.balanceOf(this.pool.address)
    ).to.equal('0')
  })
})
