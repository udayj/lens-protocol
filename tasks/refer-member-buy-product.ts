import { task } from 'hardhat/config';
import { LensHub__factory, CollectNFT__factory, Currency__factory, FollowNFT__factory,
     EcommCollectModule__factory, EcommFollowModule__factory, EcommReferenceModule__factory,
     } from '../typechain-types';
import { CreateProfileDataStruct,MirrorDataStruct } from '../typechain-types/LensHub';
import { getAddrs, initEnv, waitForTx, ZERO_ADDRESS } from './helpers/utils';

task('refer-member-buy-product', 'user1 refers a product, user2 becomes member and buys product').setAction(async ({}, hre) => {
  const [governance, , user] = await initEnv(hre);
  const addrs = getAddrs();

  const lensHub = LensHub__factory.connect(addrs['lensHub proxy'], governance);

 
  const ethers = hre.ethers;
  const accounts = await ethers.getSigners();
  const buyer = accounts[5];
  const referrer = accounts[6];
  const currencyContract = Currency__factory.connect(addrs['currency'],user);

  //give buyer some currency for paying subscription fees and buying the product
  await currencyContract.mint(buyer.address,100000);

  let balanceSeller = await currencyContract.balanceOf(user.address); 
  console.log("Initial Seller Balance:",balanceSeller);

  let balanceBuyer = await currencyContract.balanceOf(buyer.address);
  console.log("Initial Buyer Balance:",balanceBuyer);

  let balanceReferrer = await currencyContract.balanceOf(referrer.address);
  console.log("Initial referrer balance:",balanceReferrer);

  await waitForTx(lensHub.whitelistProfileCreator(referrer.address, true));

  const inputStruct: CreateProfileDataStruct = {
    to: referrer.address,
    handle: 'referrer',
    imageURI:
      'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan',
    followModule: ZERO_ADDRESS,
    followModuleData: [],
    followNFTURI:
      'https://ipfs.fleek.co/ipfs/ghostplantghostplantghostplantghostplantghostplantghostplan',
  };

  //const lensHub = LensHub__factory.connect(addrs['lensHub proxy'], buyer);
  //create profile for referrer so that it can mirror a publication
  await waitForTx(lensHub.connect(referrer).createProfile(inputStruct));
  
  console.log(`Total supply (should be 2): ${await lensHub.totalSupply()}`);
  console.log(
    `Profile owner: ${await lensHub.ownerOf(2)}, user address (should be the same): ${referrer.address}`
  );
  console.log(`Profile ID by handle: ${await lensHub.getProfileIdByHandle('referrer')}`);

  const mirrorStruct: MirrorDataStruct = {
    profileId: 2,
    profileIdPointed: 1,
    pubIdPointed: 1,
    referenceModule: ZERO_ADDRESS,
    referenceModuleData: []
  }


  //refer a product
  await waitForTx(lensHub.connect(referrer).mirror(mirrorStruct));


  const ecommReferenceModuleAddress = await lensHub.getReferenceModule(1,1);
  const ecommFollowModuleAddress = await lensHub.getFollowModule(1);
  const ecommReferenceModule = EcommReferenceModule__factory.connect(ecommReferenceModuleAddress,referrer);
  const isReferrer = await ecommReferenceModule.isReferrer(1,1,2);
  console.log("Is Referrer status for ",referrer.address," :",isReferrer);

  const ecommFollowModule = EcommFollowModule__factory.connect(ecommFollowModuleAddress,buyer);
  

  const abiCoder = new ethers.utils.AbiCoder();
  //1 in the follow module data represents a membership type follow
  const dataFollowHex = abiCoder.encode(['uint256'],[1]);
  const dataFollowBytes = ethers.utils.arrayify(dataFollowHex);

  await currencyContract.connect(buyer).approve(ecommFollowModuleAddress,10000);
  await lensHub.connect(buyer).follow([1],[dataFollowBytes]);


  const followNFTAddr = await lensHub.connect(buyer).getFollowNFT(1);
  const followNFT = FollowNFT__factory.connect(followNFTAddr, buyer);

  const totalSupplyFollowNFT = await followNFT.totalSupply();
  const ownerOfFollowNFT = await followNFT.ownerOf(1);

  console.log(`Follow NFT total supply (should be 1): ${totalSupplyFollowNFT}`);
  console.log(
    `Follow NFT owner of ID 1: ${ownerOfFollowNFT}, user address (should be the same): ${buyer.address}`
  );

  const isMemberStatus = await ecommFollowModule.isMember(1,buyer.address);
  console.log("Membership status of ",buyer.address," :",isMemberStatus);


  const ecommCollectAddress = await lensHub.getCollectModule(1,1);
  await currencyContract.connect(buyer).approve(ecommCollectAddress,10000);

  //here we pass zero address for the platform address and the referrer profile Id which is 2
  const dataBuyHex = abiCoder.encode(['address','uint256'],[ethers.constants.AddressZero,2]);
  const dataBuyBytes = ethers.utils.arrayify(dataBuyHex);
  await waitForTx(lensHub.connect(buyer).collect(1, 1, dataBuyBytes));

  const collectNFTAddr = await lensHub.getCollectNFT(1, 1);
  const collectNFT = CollectNFT__factory.connect(collectNFTAddr, user);

  const publicationContentURI = await lensHub.getContentURI(1, 1);
  const totalSupply = await collectNFT.totalSupply();
  const ownerOf = await collectNFT.ownerOf(2);
  const collectNFTURI = await collectNFT.tokenURI(2);

  console.log(`Ecomm Collect NFT total supply (should be 2): ${totalSupply}`);
  console.log(
    `Ecomm Collect NFT owner of ID 2: ${ownerOf}, user address (should be the same): ${buyer.address}`
  );
  console.log(
    `Ecomm Collect NFT URI: ${collectNFTURI}, publication content URI (should be the same): ${publicationContentURI}`
  );

  const EcommCollectModule = EcommCollectModule__factory.connect(ecommCollectAddress,user);

  const isBuyer = await EcommCollectModule.isBuyer(1,1,buyer.address);

  console.log("Is Buyer Status:",isBuyer);

  await currencyContract.connect(user).approve(ecommCollectAddress,1000);
  await EcommCollectModule.connect(referrer).withdrawReferralFees(1,1,2);

  //check that balance of buyer is reduced
  balanceBuyer = await currencyContract.balanceOf(buyer.address);
  console.log("Updated Buyer Balance:",balanceBuyer);

  //balance of seller is increased by membership fees amount + selling price - referral fees
  balanceSeller = await currencyContract.balanceOf(user.address);
  console.log("Updated Seller Balance:",balanceSeller);

  //balance of referrer should be increased by the referral fees amount 
  balanceReferrer = await currencyContract.balanceOf(referrer.address);
  console.log("Updated referrer balance:",balanceReferrer);
  
  


});