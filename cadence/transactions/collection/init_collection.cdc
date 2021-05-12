import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import GGItemsCollection from "../../contracts/GGItemsCollection.cdc"


transaction {
    prepare(signer: AuthAccount) {
        // if the account doesn't already have a collection
        if signer.borrow<&GGItemsCollection.Collection>(from: GGItemsCollection.CollectionStoragePath) == nil {

            // create a new empty collection
            let collection <- GGItemsCollection.createEmptyCollection()
            
            // save it to the account
            signer.save(<-collection, to: GGItemsCollection.CollectionStoragePath)

            // create a public capability for the collection
            signer.link<&GGItemsCollection.Collection{NonFungibleToken.CollectionPublic, GGItemsCollection.GGItemsCollectionPublic}>(GGItemsCollection.CollectionPublicPath, target: GGItemsCollection.CollectionStoragePath)
        }
    }
}