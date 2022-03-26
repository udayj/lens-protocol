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
import {ILensHub} from '../../../interfaces/ILensHub.sol';
import {IFollowModule} from '../../../interfaces/IFollowModule.sol';
import {IEcommReferenceModule} from '../../../interfaces/IEcommReferenceModule.sol';
import {IEcommFollowModule} from '../../../interfaces/IEcommFollowModule.sol';
/*
This struct is a remapping of profile publication data
profile => seller
publication => specific product
*/
struct SellerProductData {


    bool isDiscountedForFollowers; //followers can be early evangelists/members (prime like subscribers) for the seller
    bool isDiscounted; //discounts can be set according to market conditions
    bool isPlatformFeeEnabled; //incentive for front-end marketplace
    address sellerAccountAddress;
    address currency;
    uint256 currentPrice;
    uint256 discountGeneral;
    uint256 discountFollower;
    uint256 platformFee;
    uint256 feePerReferral; //referral fee given for this product by this seller
    uint256 memberDiscount;
    

}


contract EcommCollectModule is ICollectModule, FeeModuleBase, FollowValidationModuleBase {

    using SafeERC20 for IERC20;

    mapping(uint256 => mapping(uint256 => SellerProductData))
        internal _dataByProductBySeller; //_dataByPublicationByProfile
    
    //this mapping keeps track of whether an address is a buyer for a product/seller combination
    mapping(uint256 => mapping(uint256 => mapping(address => bool)))
        internal _isBuyerByProductBySeller;

    //this mapping keeps track of the total number of sales made by a referrer
    mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256)))
        internal _totalReferenceCountByProductBySeller;
    
    //this mapping keeps track of the total number of unpaid referrals for a referrer
    mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256)))
        internal _unpaidReferenceCountByProductBySeller;
    
    constructor(address hub, address moduleGlobals) FeeModuleBase(moduleGlobals) ModuleBase(hub) {}


    /**
    * @notice This modifier checks whether the msg.sender address is a profile NFT owner for the given profileId
      so essentially it means whether the msg.sender is the owner for this seller profile
     */
    modifier onlyProfileOwner(uint256 profileId) {

        address owner = IERC721(HUB).ownerOf(profileId);
        if (msg.sender != owner) revert Errors.NotProfileOwner();
        _;

    }

    /**
    * @notice - this modifier checks whether given seller/product combination has been initialised (published)
     */
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

    function setReferralFee(uint256 profileId, uint256 pubId, uint256 fee) 
    external onlyProfileOwner(profileId) isInitialized(profileId,pubId) {

         require(fee > 0 , "Fee should be more than 0");
        _dataByProductBySeller[profileId][pubId].feePerReferral=fee;
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

    function setMemberDiscount(uint256 profileId, uint256 pubId, uint256 discount) 
    external onlyProfileOwner(profileId) isInitialized(profileId,pubId) {

         require(discount < 100 && discount > 0, "Discount should be less than 100% and more than 0%");
        _dataByProductBySeller[profileId][pubId].memberDiscount=discount;
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
            //ideally the seller address should be found from owner of profileId NFT
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

            //only supporting direct buying of the product(publication) and not doing anything for collecting reviews
            if (referrerProfileId==profileId) {
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
      

        (address platform, uint256 referrerProfileId) = abi.decode(
            data,(address, uint256)
        );

       


        uint256 totalDiscount = 0;

        //Check an apply evangelist discount

        if(_dataByProductBySeller[profileId][pubId].isDiscountedForFollowers){
            if(_checkEvangelistFollowValidity(profileId, collector)) {

                totalDiscount += _dataByProductBySeller[profileId][pubId].discountFollower;
            }
        }

        //Check and apply general discount (users not evangelist or members get this discount if available)

        if(_dataByProductBySeller[profileId][pubId].isDiscounted) {

            totalDiscount += _dataByProductBySeller[profileId][pubId].discountGeneral;
        }

        // Check and apply membership discounts
        if(_checkMembership(profileId,collector)) {

            totalDiscount +=_dataByProductBySeller[profileId][pubId].memberDiscount;
        }

        require(totalDiscount < 100, "Total discount cannot exceed 100%");
        IERC20(currency).safeTransferFrom(collector,sellerAccountAddress,(currentPrice*(100-totalDiscount)/100));

        if(_dataByProductBySeller[profileId][pubId].isPlatformFeeEnabled) {

            //platform fee is paid on final product price charged after applicable discounts
            IERC20(currency).safeTransferFrom(
                collector,
                platform,
                (currentPrice*(100-totalDiscount)*_dataByProductBySeller[profileId][pubId].platformFee)/10000);
        }
        
        
        address referenceModule = ILensHub(HUB).getReferenceModule(profileId, pubId);

        if(IEcommReferenceModule(referenceModule).isReferrer(profileId, pubId, referrerProfileId)) {

            _totalReferenceCountByProductBySeller[profileId][pubId][referrerProfileId]++;
            _unpaidReferenceCountByProductBySeller[profileId][pubId][referrerProfileId]++;
        }
        
        
    }


    function _checkMembership(uint256 profileId, address user) internal view returns(bool){

        address followModule = ILensHub(HUB).getFollowModule(profileId);

        return IEcommFollowModule(followModule).isMember(profileId,user);
    }

    function _checkEvangelistFollowValidity(uint256 profileId, address user) internal view returns(bool){
        
        address followModule = ILensHub(HUB).getFollowModule(profileId);

        return IEcommFollowModule(followModule).isFollowerEvangelist(profileId,user);
        //address followNFT = ILensHub(HUB).getFollowNFT(profileId);
        /*if (followNFT == address(0)) return false;
        if (IERC721(followNFT).balanceOf(user) == 0) return false;
        

        return true;*/

    }

    function isBuyer(uint256 profileId, uint256 pubId, address buyer) external view returns(bool) {

        address collectNFT = ILensHub(HUB).getCollectNFT(profileId, pubId);

        if(collectNFT==address(0)) {
            return false;
        }

        uint256 numTokens = IERC721(collectNFT).balanceOf(buyer);
        if(numTokens == 0) {
            return false;
        }
        return true;
    }

    function withdrawReferralFees(uint256 profileId, uint256 pubId, uint256 referrerProfileId) external 
    isInitialized(profileId, pubId) {

        address referenceModule = ILensHub(HUB).getReferenceModule(profileId, pubId);
        address referrerProfile = IERC721(HUB).ownerOf(referrerProfileId);
        
        require(IEcommReferenceModule(referenceModule).isReferrer(profileId, pubId, referrerProfileId),"Not a referrer");
        require(referrerProfile == msg.sender, "Only referrer can withdraw funds");
         address currency = _dataByProductBySeller[profileId][pubId].currency;
         uint256 feePerReferral = _dataByProductBySeller[profileId][pubId].feePerReferral;
         uint256 numUnpaidReferrals = _unpaidReferenceCountByProductBySeller[profileId][pubId][referrerProfileId];
         require(numUnpaidReferrals > 0, "No referral fees to pay");
         _unpaidReferenceCountByProductBySeller[profileId][pubId][referrerProfileId]=0;
         address seller = IERC721(HUB).ownerOf(profileId);
         IERC20(currency).safeTransferFrom(seller, msg.sender, feePerReferral*numUnpaidReferrals);
    }

    function getProductData(uint256 profileId, uint256 pubId) external view returns (SellerProductData memory) {
        return _dataByProductBySeller[profileId][pubId];
    }
}


