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


contract EcommCollectModule is ICollectModule, FeeModuleBase {

    using SafeERC20 for IERC20;

    mapping(uint256 => mapping(uint256 => SellerProductData))
        internal _dataByProductBySeller; //_dataByPublicationByProfile
    
    //this mapping keeps track of whether an address is a buyer for a product/seller combination
    mapping(uint256 => mapping(uint256 => mapping (address => bool)))
        internal _isBuyerByProductBySeller;

    //this mapping keeps track of the total number of sales made by a referrer
    mapping(uint256 => mapping(uint256 => mapping (address => uint256)))
        internal _totalReferenceCountByProductBySeller;
    
    //this mapping keeps track of the total number of unpaid referrals for a referrer
    mapping(uint256 => mapping(uint256 => mapping (address => uint256)))
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
      

        (address dataCurrency, address platform, address referrer, uint256 dataCurrentPrice) = abi.decode(
            data,(address,address, address, uint256)
        );

        require(dataCurrency == currency, "Currency mismatch");
        require(dataCurrentPrice == currentPrice, "Price Mismatch");


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
        IERC20(currency).safeTransferFrom(collector,sellerAccountAddress,(currentPrice*totalDiscount)/100);

        if(_dataByProductBySeller[profileId][pubId].isPlatformFeeEnabled) {

            //platform fee is paid on final product price charged after applicable discounts
            IERC20(currency).safeTransferFrom(
                collector,
                platform,
                (currentPrice*totalDiscount*_dataByProductBySeller[profileId][pubId].platformFee)/10000);
        }
        
        //record that collector is a buyer - will be necessary for checking if collector can review(comment) on the product
        _isBuyerByProductBySeller[profileId][pubId][collector]=true;
        address referenceModule = ILensHub(HUB).getReferenceModule(profileId, pubId);

        if(IEcommReferenceModule(referenceModule).isReferrer(profileId, pubId, referrer)) {

            _totalReferenceCountByProductBySeller[profileId][pubId][referrer]++;
            _unpaidReferenceCountByProductBySeller[profileId][pubId][referrer]++;
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

        return _isBuyerByProductBySeller[profileId][pubId][buyer];
    }

    function withdrawReferralFees(uint256 profileId, uint256 pubId, address referrer) external 
    isInitialized(profileId, pubId) {

        address referenceModule = ILensHub(HUB).getReferenceModule(profileId, pubId);
        require(IReviewAndReferralModule(referenceModule).isReferrer(profileId, pubId, msg.sender),"Not a referrer");

         address currency = _dataByProductBySeller[profileId][pubId].currency;
         uint256 feePerReferral = _dataByProductBySeller[profileId][pubId].feePerReferral;
         uint256 numUnpaidReferrals = _unpaidReferenceCountByProductBySeller[profileId][pubId][msg.sender];
         require(numUnpaidReferrals > 0, "No referral fees to pay");
         _unpaidReferenceCountByProductBySeller[profileId][pubId][msg.sender]=0;
         address seller = IERC721(HUB).ownerOf(profileId);
         IERC20(currency).safeTransferFrom(seller, msg.sender, feePerReferral*numUnpaidReferrals);
    }


}