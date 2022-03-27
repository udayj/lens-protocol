import { task } from 'hardhat/config';
import { LensHub__factory, CollectNFT__factory, Currency__factory, EcommCollectModule__factory, EcommFollowModule__factory } from '../typechain-types';
import { getAddrs, initEnv, waitForTx } from './helpers/utils';

task('buy-product', 'buy a product from a seller represented by a Lens publication').setAction(async ({}, hre) => {
  const [, , user] = await initEnv(hre);
  const addrs = getAddrs();

  const ethers = hre.ethers;
  const accounts = await ethers.getSigners();
  const buyer = accounts[4];
  const currencyContract = Currency__factory.connect(addrs['currency'],buyer);
  //give buyer some currency
  await currencyContract.mint(buyer.address,10000);

  let balanceSeller = await currencyContract.balanceOf(user.address); 
  console.log("Initial Seller Balance:",balanceSeller);

  let balanceBuyer = await currencyContract.balanceOf(buyer.address);
  console.log("Initial Buyer Balance:",balanceBuyer);

  const abiCoder = new ethers.utils.AbiCoder();
  //pass zero address for platform and no referrer
  const dataBuyHex = abiCoder.encode(['address','uint256'],[ethers.constants.AddressZero,0]);
  const dataBuyBytes = ethers.utils.arrayify(dataBuyHex);

  const lensHub = LensHub__factory.connect(addrs['lensHub proxy'], buyer);

  const ecommCollectAddress = await lensHub.getCollectModule(1,1);
  console.log("Ecomm collect module address:",ecommCollectAddress);
  //approve the Ecomm Collect Module to transfer currency from buyer (to seller)
  await currencyContract.approve(ecommCollectAddress,10000);

  await waitForTx(lensHub.collect(1, 1, dataBuyBytes));

  const collectNFTAddr = await lensHub.getCollectNFT(1, 1);
  const collectNFT = CollectNFT__factory.connect(collectNFTAddr, user);

  const publicationContentURI = await lensHub.getContentURI(1, 1);
  const totalSupply = await collectNFT.totalSupply();
  const ownerOf = await collectNFT.ownerOf(1);
  const collectNFTURI = await collectNFT.tokenURI(1);

  console.log(`Ecomm Collect NFT total supply (should be 1): ${totalSupply}`);
  console.log(
    `Ecomm Collect NFT owner of ID 1: ${ownerOf}, user address (should be the same): ${buyer.address}`
  );
  console.log(
    `Ecomm Collect NFT URI: ${collectNFTURI}, product content URI (should be the same): ${publicationContentURI}`
  );

  balanceBuyer = await currencyContract.balanceOf(buyer.address);
  console.log("Updated Buyer Balance:",balanceBuyer);

  balanceSeller = await currencyContract.balanceOf(user.address);
  console.log("Updated Seller Balance:",balanceSeller);

  
  const EcommCollectModule = EcommCollectModule__factory.connect(ecommCollectAddress,user);

  const isBuyer = await EcommCollectModule.isBuyer(1,1,buyer.address);

  console.log("Is Buyer Status:",isBuyer);


});