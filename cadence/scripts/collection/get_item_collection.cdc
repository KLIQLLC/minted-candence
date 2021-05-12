import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import GGItemsCollection from "../../contracts/GGItemsCollection.cdc"

// This script returns the metadata for an NFT in an account's collection.

pub fun main(address: Address, itemID: UInt64): &GGItemsCollection.NFT? {

 let account = getAccount(address)

     let collectionRef = account.getCapability(GGItemsCollection.CollectionPublicPath)!
        .borrow<&{GGItemsCollection.GGItemsCollectionPublic}>()
        ?? panic("Could not borrow capability from public collection")
    
    return collectionRef.borrowGGItem(id: itemID)
}