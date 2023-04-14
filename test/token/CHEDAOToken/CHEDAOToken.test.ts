import { expect } from 'chai';
import { ethers, upgrades } from 'hardhat';

describe('CHEDAOToken', () => {
  it('should be deploy', async () => {
    const WelcomeEvenOne = await ethers.getContractFactory('CHEDAOToken');
    const welcomeEvenOne = await upgrades.deployProxy(WelcomeEvenOne, []);
    await welcomeEvenOne.deployed();

    expect(await welcomeEvenOne.name()).to.equal('CHEDAOToken');
  });
});
