// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.10;

interface IEcommFollowModule {


   function isFollowerEvangelist(uint256 profileId, address follower) external view returns(bool);

   

   function isMember(uint256 profileId, address follower) external view returns(bool);
}