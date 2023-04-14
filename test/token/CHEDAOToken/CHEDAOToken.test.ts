import { expect } from 'chai';
import { ethers, upgrades } from 'hardhat';

describe('CHEDAOToken', () => {
  it('should be deploy', async () => {
    const CHEDAOToken = await ethers.getContractFactory('CHEDAOToken');
    const cheDAOToken = await upgrades.deployProxy(CHEDAOToken, []);
    await cheDAOToken.deployed();

    expect(await cheDAOToken.name()).to.equal('CHEDAOToken');
  });
});
