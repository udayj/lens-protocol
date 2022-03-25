// SPDX-License-Identifier: AGPL-3.0-only

Notes

/*
1. Allow seller to whitelist profile
2. Allow seller to create profile
3. Allow seller to publish something/ list something for sale
    collect module responsible for collecting payment for item,
    what if the item details have to be ipfs hash because we want content based addressing to avoid change of item post buying
4. Allow buyer to review/comment on a publication only if they have collected the item
5. Follow module supports creating a seller specific wallet -> give discount/royalty  if you are a follower / crowdfund
6. Referral marketing and direct marketing (direct collection of publication, collecting based on mirror,  )
7. marketplace maintains a mapping of user -> publications/products reviewed
8. Reference module with processComment and processMirror -> reviews restricted only to buyers, mirrors get referral bonus
9. follow module with option to give royalty to every funder, maintain membership of a user
10. testing code

crowdfunder discount, prime membership discount/ subscription discount, general discount, platform fees, reviews, referral bonus


Concerns
physical fulfillment
privacy

processMirror -> store that user mirrored a pub in ref module
when collecting -> if referrer address is available then increase refer count profile,pub,ref addr +1 total count
                   update unpaid refer count+1
create function in collect module that referrer can call to get paid for the number of refers for a product
reinitialise unpaid refer count, pay in currency approved for product

for follow module ->
membership function
evangelist - simple discount - done

buy module
enables evangelist discount , simple discount, member discount, platform fees, referral fees
membership can be transferred (we could issue an NFT for members)

review, document and test code
*/

EcommCollectModule.sol
EcommFollowModule.sol
ECommReferenceModule.sol
IEcommCollectModule.sol
IEcommFollowModule.sol
IEcommReferenceModule.sol