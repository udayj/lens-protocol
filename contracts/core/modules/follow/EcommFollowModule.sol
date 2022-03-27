// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.10;

import {IFollowModule} from '../../../interfaces/IFollowModule.sol';
import {ILensHub} from '../../../interfaces/ILensHub.sol';
import {Errors} from '../../../libraries/Errors.sol';
import {FeeModuleBase} from '../FeeModuleBase.sol';
import {ModuleBase} from '../ModuleBase.sol';
import {FollowValidatorFollowModuleBase} from './FollowValidatorFollowModuleBase.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {IERC721Enumerable} from '@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol';

/**
 * @notice A struct containing the necessary data to execute evangelist / membership actions for a given seller
           this remaps semantic meaning of profile => seller and follow => evangelise/ subscribe to membership
 *
 * @param currency The currency associated with this profile.
 * @param recipient The recipient address associated with this profile.
 * @param evangelistFee The fee associated with this seller to become an evangelist and qualify for additional product discounts
 * @param membershipFee The fee for subscribing to a Amazon prime like membership for 1 year (for addition discounts)
 */
struct ProfileData {
    address currency;
    address recipient;
    uint256 evangelistFee;
    uint256 membershipFee;
    
}

/**
 * @title FeeFollowModule
 * @author Lens Protocol
 *
 * @notice This is a simple Lens FollowModule implementation, inheriting from the IFollowModule interface, but with additional
 * variables that help in implementing ecommerce features like subscribing to a seller
 */
contract EcommFollowModule is IFollowModule, FeeModuleBase, FollowValidatorFollowModuleBase {
    using SafeERC20 for IERC20;

    mapping(uint256 => ProfileData) internal _dataByProfile;
    
    mapping(uint256 => mapping(uint256 => bool)) internal _isEvangelist;
    mapping(uint256 => mapping(uint256 => uint256)) internal _membershipExpiry;


    /**
    @notice This modifier checks whether the msg.sender is the owner of the Profile NFT (profileId)
    @param profileId Represents the Lens protocol profile ID 
     */
    modifier onlyProfileOwner(uint256 profileId) {

        address owner = IERC721(HUB).ownerOf(profileId);
        if (msg.sender != owner) revert Errors.NotProfileOwner();
        _;

    }
    constructor(address hub, address moduleGlobals) FeeModuleBase(moduleGlobals) ModuleBase(hub) {}

    /**
     * @notice This follow module levies a fee on follows.
     *
     * @param data The arbitrary data parameter, decoded into:
     *      address currency: The currency address, must be internally whitelisted.
     *      uint256 amount: The currency total amount to levy.
     *      address recipient: The custom recipient address to direct earnings to.
     *
     * @return An abi encoded bytes parameter, which is the same as the passed data parameter.
     */
    function initializeFollowModule(uint256 profileId, bytes calldata data)
        external
        override
        onlyHub
        returns (bytes memory)
    {
        (address currency, address recipient) = abi.decode(
            data,
            (address, address)
        );
        if (!_currencyWhitelisted(currency) || recipient == address(0))
            revert Errors.InitParamsInvalid();

       // _dataByProfile[profileId].amount = amount;
        _dataByProfile[profileId].currency = currency;
        _dataByProfile[profileId].recipient = recipient;
        return data;
    }

    /**
     * @dev Processes a follow by:
     *  1. Checking if follower wants to become an evangelist or subscribe to a membership
     */
    function processFollow(
        address follower,
        uint256 profileId,
        bytes calldata data
    ) external override onlyHub {
       
        address currency = _dataByProfile[profileId].currency;
        address recipient = _dataByProfile[profileId].recipient;
       
        (uint256 typeOfFollower) = abi.decode(data,(uint256));

        //simple evangelist entitled to a limited time discount on purchase
        require(typeOfFollower < 2, "Invalid follower type");
        if(typeOfFollower==0) {

            IERC20(currency).safeTransferFrom(follower, recipient, _dataByProfile[profileId].evangelistFee);
            uint256 tokenId = _getTokenId(profileId,follower);
            _isEvangelist[profileId][tokenId]=true;
            return;
        }
        // prime like member entitled to discounts for 1 year
        if(typeOfFollower==1) {

            IERC20(currency).safeTransferFrom(follower, recipient, _dataByProfile[profileId].membershipFee);
             uint256 tokenId = _getTokenId(profileId,follower);
            _membershipExpiry[profileId][tokenId]=block.timestamp + 365*24*60*60; // membership time period is configurable

        }
   
    }
    /**
    *@notice - this function gives the Follow NFT token Id whose owner is follower
     */

    function _getTokenId(uint256 profileId, address follower) internal view returns(uint256) {

        address followNFT = ILensHub(HUB).getFollowNFT(profileId);
        uint256 numTokens = IERC721Enumerable(followNFT).balanceOf(follower);
        require(numTokens>0,"Error in issuing Follow NFT");

        //return the last tokenId issued to the follower address
        return IERC721Enumerable(followNFT).tokenOfOwnerByIndex(follower,numTokens-1);
    }

    /**
     * @dev We don't need to execute any additional logic on transfers in this follow module.
     */
    function followModuleTransferHook(
        uint256 profileId,
        address from,
        address to,
        uint256 followNFTTokenId
    ) external override {}

    /**
     * @notice Returns the profile data for a given profile, or an empty struct if that profile was not initialized
     * with this module.
     *
     * @param profileId The token ID of the profile to query.
     *
     * @return The ProfileData struct mapped to that profile.
     */
    function getProfileData(uint256 profileId) external view returns (ProfileData memory) {
        return _dataByProfile[profileId];
    }

    /**
    * @notice Returns whether given address is an evangelist for this seller
    */
    function isFollowerEvangelist(uint256 profileId, address follower) external view returns(bool) {

        address followNFT = ILensHub(HUB).getFollowNFT(profileId);
        //If follow NFT Implementation has not been initialized then clearly no address has followed this profile
        if(followNFT==address(0)) {
            return false;
        }
        uint256 numTokens = IERC721Enumerable(followNFT).balanceOf(follower);

        if(numTokens==0) {
            return false;
        }
        for(uint256 i=0;i<numTokens;i++) {
            uint256 tokenId = IERC721Enumerable(followNFT).tokenOfOwnerByIndex(follower,i);
            if(_isEvangelist[profileId][tokenId]) {
                return true;
            }
        }

        return false;
    }

    /**
    *  @notice Returns whether given address has subscribed to the seller's membership program
     */

    function isMember(uint256 profileId, address follower) public view returns(bool) {

        address followNFT = ILensHub(HUB).getFollowNFT(profileId);

        if(followNFT==address(0)) {
            return false;
        }


        uint256 numTokens = IERC721Enumerable(followNFT).balanceOf(follower);

        if(numTokens==0) {
            return false;
        }


        for(uint256 i=0;i<numTokens;i++) {
            uint256 tokenId = IERC721Enumerable(followNFT).tokenOfOwnerByIndex(follower,i);
            if(_membershipExpiry[profileId][tokenId]!=0 && _membershipExpiry[profileId][tokenId] > block.timestamp) {
                return true;
            }
        }
        

        return false;
    }

    /**
    * @notice Renews the membership for function caller if they are already a member and subscription has expired
     */

    function renewMembership(uint256 profileId) external {

        uint256 tokenId = _getTokenId(profileId, msg.sender);
        //require(_membershipExpiry[profileId][tokenId]!=0, "Cannot renew non-existant membership");
        require(!isMember(profileId,msg.sender),"Membership still valid");

         address currency = _dataByProfile[profileId].currency;
         uint256 amount = _dataByProfile[profileId].membershipFee;
         address recipient = _dataByProfile[profileId].recipient;

         IERC20(currency).safeTransferFrom(msg.sender, recipient, _dataByProfile[profileId].membershipFee);

         _membershipExpiry[profileId][tokenId]=block.timestamp + 365*24*60*60; // this is again configurable

    }

    /**
    @notice This sets the evangelist fee for the seller - only callable by the profile NFT owner representing the seller
     */
    function setEvangelistFee(uint256 profileId,uint256 amount) external onlyProfileOwner(profileId) {

        _dataByProfile[profileId].evangelistFee=amount;
    }

    /**
    @notice This sets the membership fee for a seller - only callable by the profile NFT owner representing the seller
     */

    function setMembershipFee(uint256 profileId,uint256 amount) external onlyProfileOwner(profileId) {

        _dataByProfile[profileId].membershipFee=amount;
    }

   
}
