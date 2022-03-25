// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.10;

import {IReferenceModule} from '../../../interfaces/IReferenceModule.sol';
import {ModuleBase} from '../ModuleBase.sol';
import {FollowValidationModuleBase} from '../FollowValidationModuleBase.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {ILensHub} from '../../../interfaces/ILensHub.sol';
import {IEcommCollectModule} from '../../../interfaces/IEcommCollectModule.sol';



/**
 * @title Reference Module for Ecommerce infrastructure
 * @author udayj
 *
 * @notice A reference module for ecommerce implementation that support reviews, product referrals
 * reviews are enabled by checking that a given address has bought(collected) a given product(publication)
 * referrals are enabled by recording every mirror action and providing a function to confirm whether an address is a referrer
 */
contract EcommReferenceModule is IReferenceModule, ModuleBase{

    //simple mapping to record whether a given address is a referrer for a seller/product combination
     mapping(uint256 => mapping(uint256 => mapping(address => bool)))
         internal _isReferrerByProductBySeller;



    constructor(address hub) ModuleBase(hub) {}

    /**
     * @dev There is nothing needed at initialization.
     */
    
    function initializeReferenceModule(
        uint256 profileId,
        uint256 pubId,
        bytes calldata data
    ) external pure override returns (bytes memory) {
        return new bytes(0);
    }

    /**
     * @notice Validates that the commenting profile's owner is an existing buyer of the product.
     * comment is semantically remapped to review - so only buyers can review
     * 
     */
    function processComment(
        uint256 profileId,
        uint256 profileIdPointed,
        uint256 pubIdPointed
    ) external view override {
        address commentCreator = IERC721(HUB).ownerOf(profileId);
        address collectModule =  ILensHub(HUB).getCollectModule(profileIdPointed, pubIdPointed);
        //check whether the commenter/reviewer has bought(collected) the product(publication)
        require(IEcommCollectModule(collectModule).isBuyer(profileIdPointed, pubIdPointed, commentCreator),
            "Not authorised to review");
    }

    /** 
     * @notice Records that the referrer for the product/seller combination
     * mirror is semantically remapped to refer (this is what will power the referral marketing for any seller)
     * 
     */
    function processMirror(
        uint256 profileId,
        uint256 profileIdPointed,
        uint256 pubIdPointed
    ) external override {
        address mirrorCreator = IERC721(HUB).ownerOf(profileId);
        _isReferrerByProductBySeller[profileIdPointed][pubIdPointed][mirrorCreator]=true;
    }

    /**
    * @notice Checks whether given address is a referrer for the product/seller combination
     */
    function isReferrer(uint256 profileId, uint256 pubId, address referrer) external view returns(bool) {

        return _isReferrerByProductBySeller[profileId][pubId][referrer];
    }
}
