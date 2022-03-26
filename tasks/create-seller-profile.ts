import { task } from 'hardhat/config';
import { LensHub__factory, EcommFollowModule__factory } from '../typechain-types';
import { CreateProfileDataStruct } from '../typechain-types/LensHub';
import { waitForTx, initEnv, getAddrs, ZERO_ADDRESS } from './helpers/utils';

import '@nomiclabs/hardhat-ethers';

task('create-seller-profile', 'creates a seller profile').setAction(async ({}, hre) => {
  const [governance, , user] = await initEnv(hre);
  const addrs = getAddrs();
  const lensHub = LensHub__factory.connect(addrs['lensHub proxy'], governance);

  await waitForTx(lensHub.whitelistProfileCreator(user.address, true));

  const ethers = hre.ethers;
  const abiCoder = new ethers.utils.AbiCoder();

  const dataHex = abiCoder.encode(["address","address"],[addrs['currency'],user.address]);
  const dataBytes = ethers.utils.arrayify(dataHex);
  console.log(dataHex);
  const inputStruct: CreateProfileDataStruct = {
    to: user.address,
    handle: 'seller',
    imageURI:
      'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan',
    followModule: addrs['ecommerce follow module'],
    followModuleData: dataBytes,
    followNFTURI:
      'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan',
  };

  await waitForTx(lensHub.connect(user).createProfile(inputStruct));

  console.log(`Total supply (should be 1): ${await lensHub.totalSupply()}`);
  console.log(
    `Profile owner: ${await lensHub.ownerOf(1)}, user address (should be the same): ${user.address}`
  );
  console.log(`Profile ID by handle: ${await lensHub.getProfileIdByHandle('seller')}`);
  const followModule=await lensHub.getFollowModule(1);
  console.log('Profile Follow Module:', followModule);

  const EcommFollowModule = EcommFollowModule__factory.connect(followModule,user);

  let sellerData = await EcommFollowModule.getProfileData(1);

  console.log('Seller Profile Data:',sellerData);

  await EcommFollowModule.setEvangelistFee(1, 1000);
  await EcommFollowModule.setMembershipFee(1,10000);

  sellerData = await EcommFollowModule.getProfileData(1);


  console.log('Updated Seller Profile Data:',sellerData);
});
