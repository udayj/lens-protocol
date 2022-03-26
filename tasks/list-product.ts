import { task } from 'hardhat/config';
import { LensHub__factory, EcommCollectModule__factory } from '../typechain-types';
import { PostDataStruct } from '../typechain-types/LensHub';
import { getAddrs, initEnv, waitForTx, ZERO_ADDRESS } from './helpers/utils';

task('list-product', 'publishes a post').setAction(async ({}, hre) => {
  const [governance, , user] = await initEnv(hre);
  const addrs = getAddrs();
  const lensHub = LensHub__factory.connect(addrs['lensHub proxy'], governance);
  const collectModuleAddress = addrs['ecommerce collect module'];
  const referenceModuleAddress = addrs['ecommerce reference module'];

 

  const ethers = hre.ethers;
  const accounts = ethers.getSigners();
  const abiCoder = new ethers.utils.AbiCoder();
  const currency = addrs['currency'];
  const dataCollectHex = abiCoder.encode(['address','address','uint256'],[user.address,currency,10000]);
  const dataCollectBytes = ethers.utils.arrayify(dataCollectHex);
 const EcommCollectModule = EcommCollectModule__factory.connect(collectModuleAddress,user);
  
  const inputStruct: PostDataStruct = {
    profileId: 1,
    contentURI:
      'https://ipfs.fleek.co/ipfs/product_1',
    collectModule: collectModuleAddress,
    collectModuleData: dataCollectBytes,
    referenceModule: referenceModuleAddress,
    referenceModuleData: [],
  };

  await waitForTx(lensHub.connect(user).post(inputStruct));
  console.log(await lensHub.getPub(1, 1));

  let productData = await EcommCollectModule.getProductData(1,1);
  console.log("Initial Product Data:",productData);

  await EcommCollectModule.modifyGeneralDiscountSetting(1,1,true);
  await EcommCollectModule.setGeneralDiscount(1,1,10);
  await EcommCollectModule.setMemberDiscount(1,1,10);
  await EcommCollectModule.setReferralFee(1,1,100);

  productData = await EcommCollectModule.getProductData(1,1);

  console.log("Updated Product Data:",productData);
});
