This project is about reimagining the ecommerce infrastructure that we are familiar with using the decentralized social components of the Lens protocol. What this enables is a more modular approach towards ecommerce making it decentralized without giving any centralized marketplace disproportionate control over third party buyers and sellers. By separating the front-end of a marketplace from the actual seller-product policies and physical delivery of the products, each of these players in the system will be incentivized to provide the best possible terms to the others and lead to healthy competition instead of exploitation of smaller players.

To achieve this, we do a semantic remapping of the basic pieces of the Lens protocol system. Specifically,

**Profile => Seller Profile**

**Post Publication => List Product**

**Collect Post => Buy Product**

**Comment on Post => Review Product**

**Mirror Post => Refer Product (Referral Marketing)**


The combination of the custom Ecommerce Follow, Collect and Reference modules that we have developed support the following infrastructural components of ecommerce that are generally handled by a centralized authority.

1. Membership subscription (like Amazon prime but transferable since they are represented by a Follow NFT)
2. General Dynamic Product Discounts
3. Member only discounts
4. Platform fees that a seller can offer to a front-end/fulfillment service/marketplace on their own discretion (instead of being decided by the marketplace).
5. Referral Fees that enable referral marketing
And more features like royalties, crowdfunding, advertisements etc. could easily be developed along similar lines.

We only used the Lens protocol to create our system/protocol that enables basic decentralized ecommerce. 3 custom modules were developed:- 

[EcommFollowModule](https://github.com/udayj/lens-protocol/blob/main/contracts/core/modules/follow/EcommFollowModule.sol)  - Enables a seller to offer membership/evangelism based discounts

[EcommCollectModule](https://github.com/udayj/lens-protocol/blob/main/contracts/core/modules/collect/EcommCollectModule.sol)  - Enables seller to give general dynamic discounts, membership specific discounts by pulling membership data from the EcommFollowModule, platform fees and referral fees (by checking with the Reference Module if a user is a referrer for a product)

[EcommReferenceModule](https://github.com/udayj/lens-protocol/blob/main/contracts/core/modules/reference/EcommReferenceModule.sol) - Enables referral marketing (by recording who is mirroring a post) and authentic product reviews (by restricting comments on a post to legitimate holders of the Collect NFT i.e. buyers)

All the 3 modules above have been plugged into the forked Lens protocol codebase to enable faster testing.

The following hardhat tasks were written (with modifications to the full-deploy task) to enable basic testing & demonstration of the protocol. They can be run after setting up the environment and unpausing the protocol following the guide here -> https://docs.lens.dev/docs/primer

[create-seller-profile.ts](https://github.com/udayj/lens-protocol/blob/main/tasks/create-seller-profile.ts)

[list-product.ts](https://github.com/udayj/lens-protocol/blob/main/tasks/list-product.ts)

[buy-product.ts](https://github.com/udayj/lens-protocol/blob/main/tasks/buy-product.ts)

[refer-member-buy-product.ts](https://github.com/udayj/lens-protocol/blob/main/tasks/refer-member-buy-product.ts)
