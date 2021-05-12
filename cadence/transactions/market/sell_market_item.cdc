import FungibleToken from "../../contracts/FungibleToken.cdc"
import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import GGCoin from "../../contracts/GGCoin.cdc"
import GGItemsCollection from "../../contracts/GGItemsCollection.cdc"
import GGItemsMarket from "../../contracts/GGItemsMarket.cdc"

transaction(saleItemID: UInt64, saleItemPrice: UFix64) {
    let GGVault: Capability<&GGCoin.Vault{FungibleToken.Receiver}>
    let GGItemsCollection: Capability<&GGItemsCollection.Collection{NonFungibleToken.Provider}>
    let marketCollection: &GGItemsMarket.Collection

    prepare(signer: AuthAccount) {
        // we need a provider capability, but one is not provided by default so we create one.
        let GGItemsCollectionProviderPrivatePath = /private/GGItemsCollectionProvider

        self.GGVault = signer.getCapability<&GGCoin.Vault{FungibleToken.Receiver}>(GGCoin.ReceiverPublicPath)!
        assert(self.GGVault.borrow() != nil, message: "Missing or mis-typed GGCoin receiver")

        if !signer.getCapability<&GGItemsCollection.Collection{NonFungibleToken.Provider}>(GGItemsCollectionProviderPrivatePath)!.check() {
            signer.link<&GGItemsCollection.Collection{NonFungibleToken.Provider}>(GGItemsCollectionProviderPrivatePath, target: GGItemsCollection.CollectionStoragePath)
        }

        self.GGItemsCollection = signer.getCapability<&GGItemsCollection.Collection{NonFungibleToken.Provider}>(GGItemsCollectionProviderPrivatePath)!
        assert(self.GGItemsCollection.borrow() != nil, message: "Missing or mis-typed GGItemsCollection provider")

        self.marketCollection = signer.borrow<&GGItemsMarket.Collection>(from: GGItemsMarket.CollectionStoragePath)
            ?? panic("Missing or mis-typed GGItemsMarket Collection")
    }

    execute {
        let offer <- GGItemsMarket.createSaleOffer (
            sellerItemProvider: self.GGItemsCollection,
            saleItemID: saleItemID,
            sellerPaymentReceiver: self.GGVault,
            salePrice: saleItemPrice
        )
        self.marketCollection.insert(offer: <-offer)
    }
}
