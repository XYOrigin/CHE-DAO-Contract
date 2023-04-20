import { expect } from 'chai';
import { Contract } from 'ethers';
import { ethers, upgrades } from 'hardhat';

describe('veCHEDAOToken', () => {
  let cheDAOToken: Contract;
  let veCHEDAOToken: Contract;
  beforeEach(async () => {
    const CHEDAOToken = await ethers.getContractFactory('CHEDAOToken');
    cheDAOToken = await upgrades.deployProxy(CHEDAOToken, []);
    await cheDAOToken.deployed();

    const VeCHEDAOToken = await ethers.getContractFactory('VeCHEDAOToken');
    veCHEDAOToken = await upgrades.deployProxy(VeCHEDAOToken, [
      cheDAOToken.address,
    ]);
    await veCHEDAOToken.deployed();
  });
  it('should be deploy', async () => {
    expect(await cheDAOToken.name()).to.equal('CHEDAOToken');
    expect(await cheDAOToken.symbol()).to.equal('CHE');
    expect(await cheDAOToken.decimals()).to.equal(18);

    expect(await veCHEDAOToken.name()).to.equal('veCHEDAOToken');
    expect(await veCHEDAOToken.symbol()).to.equal('veCHE');
    expect(await veCHEDAOToken.decimals()).to.equal(18);
  });
});
