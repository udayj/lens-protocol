// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.10;

import {ICollectModule} from '../../../interfaces/ICollectModule.sol';
import {Errors} from '../../../libraries/Errors.sol';
import {ModuleBase} from '../ModuleBase.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {FeeModuleBase} from '../FeeModuleBase.sol';
import {ModuleBase} from '../ModuleBase.sol';
import {FollowValidationModuleBase} from '../FollowValidationModuleBase.sol';
import {ILensHub} from '../../interfaces/ILensHub.sol';
import {IFollowModule} from '../../../interfaces/IFollowModule.sol';

/*
This struct is a remapping of profile publication data
profile => seller
publication => specific product
*/
struct SellerProductData {


    bool isDiscountedForFollowers; //followers can be early evangelists/crowdfunders/prime subscriber for the seller
    bool isDiscounted; //discounts can be set according to market conditions
    bool isPlatformFeeEnabled; //incentive for front-end marketplace
    address sellerAccountAddress;
    address currency;
    uint256 currentPrice;
    uint256 discountGeneral;
    uint256 discountFollower;
    uint256 platformFee;

}


contract BuyCollectModule is ICollectModule, FeeModuleBase {

    using SafeERC20 for IERC20;

    mapping(uint256 => mapping(uint256 => SellerProductData))
        internal _dataByProductBySeller; //_dataByPublicationByProfile

    
    constructor(address hub, address moduleGlobals) FeeModuleBase(moduleGlobals) ModuleBase(hub) {}

    modifier onlyProfileOwner(uint256 profileId) {

        address owner = IERC721(HUB).ownerOf(profileId);
        if (msg.sender != owner) revert Errors.NotProfileOwner();
        _;

    }

    modifier isInitialized(uint256 profileId, uint256 pubId) {

         require(_dataByProductBySeller[profileId][pubId].sellerAccountAddress!=address(0),"Not initialized");
         _;
    }

    function modifyDiscountSettingForFollower(uint256 profileId, uint256 pubId, bool setting) 
    external onlyProfileOwner(profileId) isInitialized(profileId,pubId) {

        

         _dataByProductBySeller[profileId][pubId].isDiscountedForFollowers=setting;
    }

   

    function modifyGeneralDiscountSetting(uint256 profileId, uint256 pubId, bool setting) 
    external onlyProfileOwner(profileId) isInitialized(profileId,pubId) {

        _dataByProductBySeller[profileId][pubId].isDiscounted=setting;
    }

    


    function modifyPlatformFeeSetting(uint256 profileId,uint256 pubId, bool setting)
    external onlyProfileOwner(profileId) isInitialized(profileId,pubId) {

        _dataByProductBySeller[profileId][pubId].isPlatformFeeEnabled=setting;
    }

   
    function setFollowerDiscount(uint256 profileId, uint256 pubId, uint256 discount) 
    external onlyProfileOwner(profileId) isInitialized(profileId,pubId) {

         require(discount < 100 && discount > 0, "Discount should be less than 100% and more than 0%");
        _dataByProductBySeller[profileId][pubId].discountFollower=discount;
    }

    function setGeneralDiscount(uint256 profileId, uint256 pubId, uint256 discount) 
    external onlyProfileOwner(profileId) isInitialized(profileId,pubId) {

         require(discount < 100 && discount > 0, "Discount should be less than 100% and more than 0%");
        _dataByProductBySeller[profileId][pubId].discountGeneral=discount;
    }


    function setPlatformFee(uint256 profileId, uint256 pubId, uint256 fee) 
    external onlyProfileOwner(profileId) isInitialized(profileId,pubId) {

         require(fee < 100 && fee > 0, "Fees should be less than 100% and more than 0%");
        _dataByProductBySeller[profileId][pubId].platformFee=fee;
    }


    function initializePublicationCollectModule(
        uint256 profileId,
        uint256 pubId,
        bytes calldata data
    ) external returns (bytes memory) {

        (address sellerAccountAddress, address currency, uint256 currentPrice) = abi.decode(
            data, (address,address,uint256)
        );

          if (
            !_currencyWhitelisted(currency) ||
            sellerAccountAddress == address(0) ||
            currentPrice ==0) {
                revert Errors.InitParamsInvalid();
            }
            // profileId is seller Id, publicationId is product Id
            _dataByProductBySeller[profileId][pubId].sellerAccountAddress=sellerAccountAddress;
            _dataByProductBySeller[profileId][pubId].currency = currency;
            _dataByProductBySeller[profileId][pubId].currentPrice = currentPrice ;


            return data;
    }

    function processCollect(
        uint256 referrerProfileId,
        address collector,
        uint256 profileId,
        uint256 pubId,
        bytes calldata data
    ) external virtual override onlyHub {

            if (reffererProfileId==profileId) {
                _processCollect(collector, profileId, pubId, data);
            }

    }

    function _processCollect(
        address collector,
        uint256 profileId,
        uint256 pubId,
        bytes calldata data
    ) internal {

        address currency = _dataByProductBySeller[profileId][pubId].currency;
        uint256 currentPrice = _dataByProductBySeller[profileId][pubId].currentPrice;
        address sellerAccountAddress = _dataByProductBySeller[profileId][pubId].sellerAccountAddress;
      

        (address dataCurrency, address platform, uint256 dataCurrentPrice) = abi.decode(
            data,(address,address,dataCurrentPrice)
        );

        uint256 totalDiscount = 0;
        if(_dataByProductBySeller[profileId][pubId].isDiscountedForFollowers){
            if(_checkFollowValidity(profileId, collector)) {

                totalDiscount += _dataByProductBySeller[profileId][pubId].discountFollower;
            }
        }

        if(_dataByProductBySeller[profileId][pubId].isDiscounted) {

            totalDiscount += _dataByProductBySeller[profileId][pubId].discountGeneral;
        }

        require(totalDiscount < 100, "Total discount cannot exceed 100%");
        IERC20(currency).safeTransferFrom(collector,sellerAccountAddress,(currentPrice*totalDiscount)/100);

        if(_dataByProductBySeller[profileId][pubId].isPlatformFeeEnabled) {

            IERC20(currency).safeTransferFrom(
                collector,
                platform,
                (currentPrice*totalDiscount*_dataByProductBySeller[profileId][pubId].platformFee)/10000);
        }
        
        require(dataCurrency == currency, "Currency mismatch");
        require(dataCurrentPrice == currentPrice, "Price Mismatch");

        
        
    }

    function _checkFollowValidity(uint256 profileId, address user) internal view returns(bool){
        
        address followNFT = ILensHub(HUB).getFollowNFT(profileId);
        if (followNFT == address(0)) return false;
        if (IERC721(followNFT).balanceOf(user) == 0) return false;
        

        return true;

    }


}