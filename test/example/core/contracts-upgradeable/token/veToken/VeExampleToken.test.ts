import { expect } from 'chai';
import { Contract } from 'ethers';
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
});
