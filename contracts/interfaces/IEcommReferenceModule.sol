// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.10;

interface IEcommReferenceModule {


    function isReferrer(uint256 profileId, uint256 pubId, address referrer) external view returns(bool);
}