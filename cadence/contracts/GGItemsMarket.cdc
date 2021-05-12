import GGCoin from "./GGCoin.cdc"
import GGItemsCollection from "./GGItemsCollection.cdc"
import FungibleToken from "./FungibleToken.cdc"
import NonFungibleToken from "./NonFungibleToken.cdc"


pub contract GGItemsMarket {

    // Events
    pub event SaleOfferCreated(itemID: UInt64, price: UFix64)
    pub event SaleOfferAccepted(itemID: UInt64)
    pub event SaleOfferFinished(itemID: UInt64)
    pub event CollectionInsertedSaleOffer(saleItemID: UInt64, saleItemCollection: Address)
    pub event CollectionRemovedSaleOffer(saleItemID: UInt64, saleItemCollection: Address)

    // Named paths
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    pub resource interface SaleOfferPublicView {
        pub var saleCompleted: Bool
        pub let saleItemID: UInt64
        pub let salePrice: UFix64
    }

    // A GGItemsCollection NFT being offered to sale for a set fee paid in GGCoin.
    pub resource SaleOffer: SaleOfferPublicView {
        // Whether the sale has completed with someone purchasing the item.
        pub var saleCompleted: Bool

        // The GGItemsCollection NFT ID for sale.
        pub let saleItemID: UInt64
        // The collection containing that ID.
        access(self) let sellerItemProvider: Capability<&GGItemsCollection.Collection{NonFungibleToken.Provider}>

        // The sale payment price.
        pub let salePrice: UFix64
        // The GGCoin vault that will receive that payment if teh sale completes successfully.
        access(self) let sellerPaymentReceiver: Capability<&GGCoin.Vault{FungibleToken.Receiver}>

        // Called by a purchaser to accept the sale offer.
        // If they send the correct payment in GGCoin, and if the item is still available,
        // the GGItemsCollection NFT will be placed in their GGItemsCollection.Collection .
        //
        pub fun accept(
            buyerCollection: &GGItemsCollection.Collection{NonFungibleToken.Receiver},
            buyerPayment: @FungibleToken.Vault
        ) {
            pre {
                buyerPayment.balance == self.salePrice: "payment does not equal offer price"
                self.saleCompleted == false: "the sale offer has already been accepted"
            }

            self.saleCompleted = true

            self.sellerPaymentReceiver.borrow()!.deposit(from: <-buyerPayment)

            let nft <- self.sellerItemProvider.borrow()!.withdraw(withdrawID: self.saleItemID)
            buyerCollection.deposit(token: <-nft)

            emit SaleOfferAccepted(itemID: self.saleItemID)
        }

        destroy() {
            emit SaleOfferFinished(itemID: self.saleItemID)
        }

        // initializer
        // Take the information required to create a sale offer, notably the capability
        // to transfer the GGItemsCollection NFT and the capability to receive GGCoin in payment.
        //
        init(
            sellerItemProvider: Capability<&GGItemsCollection.Collection{NonFungibleToken.Provider}>,
            saleItemID: UInt64,
            sellerPaymentReceiver: Capability<&GGCoin.Vault{FungibleToken.Receiver}>,
            salePrice: UFix64
        ) {
            pre {
                sellerItemProvider.borrow() != nil: "Cannot borrow seller"
                sellerPaymentReceiver.borrow() != nil: "Cannot borrow sellerPaymentReceiver"
            }

            self.saleCompleted = false

            self.sellerItemProvider = sellerItemProvider
            self.saleItemID = saleItemID

            self.sellerPaymentReceiver = sellerPaymentReceiver
            self.salePrice = salePrice

            emit SaleOfferCreated(itemID: self.saleItemID, price: self.salePrice)
        }
    }

    // Make creating a SaleOffer publicly accessible.
    pub fun createSaleOffer (
        sellerItemProvider: Capability<&GGItemsCollection.Collection{NonFungibleToken.Provider}>,
        saleItemID: UInt64,
        sellerPaymentReceiver: Capability<&GGCoin.Vault{FungibleToken.Receiver}>,
        salePrice: UFix64
    ): @SaleOffer {
        return <-create SaleOffer(
            sellerItemProvider: sellerItemProvider,
            saleItemID: saleItemID,
            sellerPaymentReceiver: sellerPaymentReceiver,
            salePrice: salePrice
        )
    }

    // An interface for adding and removing SaleOffers to a collection, intended for use by the collection's owner.
    pub resource interface CollectionManager {
        pub fun insert(offer: @GGItemsMarket.SaleOffer)
        pub fun remove(saleItemID: UInt64): @SaleOffer 
    }

        // CollectionPurchaser
    // An interface to allow purchasing items via SaleOffers in a collection.
    // This function is also provided by CollectionPublic, it is here to support
    // more fine-grained access to the collection for as yet unspecified future use cases.
    //
    pub resource interface CollectionPurchaser {
        pub fun purchase(
            saleItemID: UInt64,
            buyerCollection: &GGItemsCollection.Collection{NonFungibleToken.Receiver},
            buyerPayment: @FungibleToken.Vault
        )
    }

    // An interface to allow listing and borrowing SaleOffers, and purchasing items via SaleOffers in a collection.
    pub resource interface CollectionPublic {
        pub fun getSaleOfferIDs(): [UInt64]
        pub fun borrowSaleItem(saleItemID: UInt64): &SaleOffer{SaleOfferPublicView}?
        pub fun purchase(
            saleItemID: UInt64,
            buyerCollection: &GGItemsCollection.Collection{NonFungibleToken.Receiver},
            buyerPayment: @FungibleToken.Vault
        )
   }

    // A resource that allows its owner to manage a list of SaleOffers, and purchasers to interact with them.
    pub resource Collection : CollectionManager, CollectionPurchaser, CollectionPublic {
        pub var saleOffers: @{UInt64: SaleOffer}

        // Insert a SaleOffer into the collection, replacing one with the same saleItemID if present.
         pub fun insert(offer: @GGItemsMarket.SaleOffer) {
            let id: UInt64 = offer.saleItemID

            // add the new offer to the dictionary which removes the old one
            let oldOffer <- self.saleOffers[id] <- offer
            destroy oldOffer

            emit CollectionInsertedSaleOffer(saleItemID: id, saleItemCollection: self.owner?.address!)
        }

        // Remove and return a SaleOffer from the collection.
        pub fun remove(saleItemID: UInt64): @SaleOffer {
            emit CollectionRemovedSaleOffer(saleItemID: saleItemID, saleItemCollection: self.owner?.address!)
            return <-(self.saleOffers.remove(key: saleItemID) ?? panic("missing SaleOffer"))
        }
 
        // purchase
        // If the caller passes a valid saleItemID and the item is still for sale, and passes a GGCoin vault
        // typed as a FungibleToken.Vault (GGCoin.deposit() handles the type safety of this)
        // containing the correct payment amount, this will transfer the GGItem to the caller's
        // GGItemsCollection collection.
        // It will then remove and destroy the offer.
        // Note that is means that events will be emitted in this order:
        //   1. Collection.CollectionRemovedSaleOffer
        //   2. GGItemsCollection.Withdraw
        //   3. GGItemsCollection.Deposit
        //   4. SaleOffer.SaleOfferFinished
        //
        pub fun purchase(
            saleItemID: UInt64,
            buyerCollection: &GGItemsCollection.Collection{NonFungibleToken.Receiver},
            buyerPayment: @FungibleToken.Vault
        ) {
            pre {
                self.saleOffers[saleItemID] != nil: "SaleOffer does not exist in the collection!"
            }
            let offer <- self.remove(saleItemID: saleItemID)
            offer.accept(buyerCollection: buyerCollection, buyerPayment: <-buyerPayment)
            //FIXME: Is this correct? Or should we return it to the caller to dispose of?
            destroy offer
        }

        // Returns an array of the IDs that are in the collection
        pub fun getSaleOfferIDs(): [UInt64] {
            return self.saleOffers.keys
        }

        // Returns an Optional read-only view of the SaleItem for the given saleItemID if it is contained by this collection. The optional will be nil if the provided saleItemID is not present in the collection.
        pub fun borrowSaleItem(saleItemID: UInt64): &SaleOffer{SaleOfferPublicView}? {
            if self.saleOffers[saleItemID] == nil {
                return nil
            } else {
                return &self.saleOffers[saleItemID] as &SaleOffer{SaleOfferPublicView}
            }
        }

        destroy () {
            destroy self.saleOffers
        }

        init () {
            self.saleOffers <- {}
        }
    }

    pub fun createEmptyCollection(): @Collection {
        return <-create Collection()
    }

    init () {
        self.CollectionStoragePath = /storage/GItemsMarketCollection001
        self.CollectionPublicPath = /public/GGItemsMarketCollections001
    }
}
