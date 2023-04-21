import { expect } from 'chai';
import { BigNumber, Contract } from 'ethers';
import { ethers, upgrades } from 'hardhat';

describe('VeExampleToken', () => {
  let exampleToken: Contract;
  let veExampleToken: Contract;
  beforeEach(async () => {
    const ExampleToken = await ethers.getContractFactory('ExampleToken');
    exampleToken = await upgrades.deployProxy(ExampleToken, []);
    await exampleToken.deployed();

    const VeExampleToken = await ethers.getContractFactory('VeExampleToken');
    veExampleToken = await upgrades.deployProxy(VeExampleToken, [
      exampleToken.address,
    ]);
    await veExampleToken.deployed();
  });
  it('should be deploy', async () => {
    expect(await exampleToken.name()).to.equal('ExampleToken');
    expect(await exampleToken.symbol()).to.equal('ETK');
    expect(await exampleToken.decimals()).to.equal(18);

    expect(await veExampleToken.name()).to.equal('veExampleToken');
    expect(await veExampleToken.symbol()).to.equal('veETK');
    expect(await veExampleToken.decimals()).to.equal(18);
  });

  describe('balanceOf', () => {
    it('should return 0', async () => {
      expect(await veExampleToken.name()).to.equal('veExampleToken');
      expect(await veExampleToken.symbol()).to.equal('veETK');
      expect(await veExampleToken.decimals()).to.equal(18);
      const [owner] = await ethers.getSigners();
      expect(await veExampleToken.balanceOf(owner.address)).to.equal(0);
    });
  });

  describe('createLock', () => {
    let amount: number = 100;
    beforeEach(async () => {
      const [owner] = await ethers.getSigners();
      //mint 100 token
      await exampleToken.mint(owner.address, amount);
    });
    it('should create lock', async () => {
      const [owner] = await ethers.getSigners();

      const week = 7 * 24 * 60 * 60;
      const lockTime = Math.floor(new Date().getTime() / 1000) + week;
      await exampleToken.approve(veExampleToken.address, amount);

      //get block timestamp
      const block = await ethers.provider.getBlock('latest');

      await expect(veExampleToken.createLock(amount, BigNumber.from(lockTime)))
        .to.emit(veExampleToken, 'Deposit')
        .withArgs(
          owner.address,
          amount,
          BigNumber.from(Math.floor(lockTime / week) * week),
          0,
          (x: BigNumber) => x.gt(block.timestamp)
        )
        .to.emit(veExampleToken, 'Supply')
        .withArgs(0, amount);

      const lockBalance = await veExampleToken.lockedBalanceOf(owner.address);
      expect(lockBalance.amount).to.equal(amount);
      expect(lockBalance.end).to.equal(
        BigNumber.from(Math.floor(lockTime / week) * week)
      );

      expect(await exampleToken.balanceOf(veExampleToken.address)).to.equal(
        amount
      );
      expect(await exampleToken.balanceOf(owner.address)).to.equal(0);
    });

    it('should create lock failed: already lock', async () => {
      const [owner] = await ethers.getSigners();

      const week = 7 * 24 * 60 * 60;
      const lockTime = Math.floor(new Date().getTime() / 1000) + week;
      await exampleToken.approve(veExampleToken.address, amount);

      await veExampleToken.createLock(amount / 2, BigNumber.from(lockTime));

      await expect(
        veExampleToken.createLock(amount / 2, BigNumber.from(lockTime))
      ).to.be.revertedWith('VeToken: already have a lock');
    });
  });

  describe('withdraw', () => {
    let amount: number = 100;
    beforeEach(async () => {
      const [owner] = await ethers.getSigners();
      //mint 100 token
      await exampleToken.mint(owner.address, amount);
    });
    it('should success', async () => {
      const [owner] = await ethers.getSigners();

      const week = 7 * 24 * 60 * 60;
      const lockTime = Math.floor(new Date().getTime() / 1000) + week;
      await exampleToken.approve(veExampleToken.address, amount);

      await veExampleToken.createLock(amount, BigNumber.from(lockTime));

      //check lock balance
      const lockBalance = await veExampleToken.lockedBalanceOf(owner.address);
      expect(lockBalance.amount).to.equal(amount);
      expect(lockBalance.end).to.equal(
        BigNumber.from(Math.floor(lockTime / week) * week)
      );

      //check token balance
      expect(await exampleToken.balanceOf(veExampleToken.address)).to.equal(
        amount
      );
      expect(await exampleToken.balanceOf(owner.address)).to.equal(0);

      //change block timestamp + 1 week
      await ethers.provider.send('evm_increaseTime', [week]);
      //get block timestamp
      let block = await ethers.provider.getBlock('latest');

      //withdraw
      await expect(veExampleToken.withdraw())
        .to.emit(veExampleToken, 'Withdraw')
        .withArgs(owner.address, amount, (x: BigNumber) =>
          x.gt(block.timestamp)
        )
        .to.emit(veExampleToken, 'Supply')
        .withArgs(amount, 0);

      //check lock balance
      const lockBalance2 = await veExampleToken.lockedBalanceOf(owner.address);
      expect(lockBalance2.amount).to.equal(0);
      expect(lockBalance2.end).to.equal(0);

      //check token balance
      expect(await exampleToken.balanceOf(veExampleToken.address)).to.equal(0);
      expect(await exampleToken.balanceOf(owner.address)).to.equal(amount);
    });
  });
});
