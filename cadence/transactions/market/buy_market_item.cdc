import FungibleToken from "../../contracts/FungibleToken.cdc"
import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import GGCoin from "../../contracts/GGCoin.cdc"
import GGItemsCollection from "../../contracts/GGItemsCollection.cdc"
import GGItemsMarket from "../../contracts/GGItemsMarket.cdc"

transaction(saleItemID: UInt64, marketCollectionAddress: Address) {
    let paymentVault: @FungibleToken.Vault
    let ggItemsCollection: &GGItemsCollection.Collection{NonFungibleToken.Receiver}
    let marketCollection: &GGItemsMarket.Collection{GGItemsMarket.CollectionPublic}

    prepare(signer: AuthAccount) {
        self.marketCollection = getAccount(marketCollectionAddress)
            .getCapability<&GGItemsMarket.Collection{GGItemsMarket.CollectionPublic}>(
                GGItemsMarket.CollectionPublicPath
            )!
            .borrow()
            ?? panic("Could not borrow market collection from market address")

        let saleItem = self.marketCollection.borrowSaleItem(saleItemID: saleItemID)
                    ?? panic("No item with that ID")
        let price = saleItem.salePrice

        let mainKibbleVault = signer.borrow<&GGCoin.Vault>(from: GGCoin.VaultStoragePath)
            ?? panic("Cannot borrow GGCoin vault from acct storage")
        self.paymentVault <- mainKibbleVault.withdraw(amount: price)

        self.ggItemsCollection = signer.borrow<&GGItemsCollection.Collection{NonFungibleToken.Receiver}>(
            from: GGItemsCollection.CollectionStoragePath
        ) ?? panic("Cannot borrow GGItemsCollection collection receiver from acct")
    }

    execute {
        self.marketCollection.purchase(
            saleItemID: saleItemID,
            buyerCollection: self.ggItemsCollection,
            buyerPayment: <- self.paymentVault
        )
    }
}
