import GGItemsMarket from "../../contracts/GGItemsMarket.cdc"

transaction(saleItemID: UInt64) {
    let marketCollection: &GGItemsMarket.Collection

    prepare(signer: AuthAccount) {
        self.marketCollection = signer.borrow<&GGItemsMarket.Collection>(from: GGItemsMarket.CollectionStoragePath)
            ?? panic("Missing or mis-typed GGItemsMarket Collection")
    }

    execute {
        let offer <-self.marketCollection.remove(saleItemID: saleItemID)
        destroy offer
    }
}
