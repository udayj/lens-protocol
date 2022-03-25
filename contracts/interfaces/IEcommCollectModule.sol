// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.10;

interface IBuyCollectModule {


    function isBuyer(uint256 profileId, uint256 pubId, address buyer) external view returns(bool);
}