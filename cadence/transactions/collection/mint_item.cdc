import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import GGItemsCollection from "../../contracts/GGItemsCollection.cdc"

transaction(recipient: Address, name: String, description: String, teams: String, players: String, contentCreator: String, game: String, event: String, date: String, asset: String, editionId: UInt64, editionsTotal: UInt64 ) {
    
    // local variable for storing the minter reference
    let minter: &GGItemsCollection.NFTMinter

    prepare(signer: AuthAccount) {

        // borrow a reference to the NFTMinter resource in storage
        self.minter = signer.borrow<&GGItemsCollection.NFTMinter>(from: GGItemsCollection.MinterStoragePath)
            ?? panic("Could not borrow a reference to the NFT minter")
    }

    execute {

        // borrow the recipient's public NFT collection reference
        let receiver = getAccount(recipient)
            .getCapability(GGItemsCollection.CollectionPublicPath)!
            .borrow<&{NonFungibleToken.CollectionPublic}>()
            ?? panic("Could not get receiver reference to the NFT Collection")

        // mint the NFT and deposit it to the recipient's collection
        self.minter.mintNFT(recipient: receiver, name: name, description: description, teams: teams, players: players, contentCreator: contentCreator, game: game, event: event, date: date, asset: asset, editionId: editionId, editionsTotal: editionsTotal)
    }
}
