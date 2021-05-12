import NonFungibleToken from "./NonFungibleToken.cdc"

pub contract GGItemsCollection: NonFungibleToken {

    // Events
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, name: String, asset: String)

    // Named Paths
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    // The total number of GGItemsCollection that have been minted
    pub var totalSupply: UInt64

    pub resource NFT: NonFungibleToken.INFT {
        pub let id: UInt64
        pub let name: String
        pub let description: String
        pub let teams: String
        pub let players: String
        pub let contentCreator: String
        pub let game: String
        pub let event: String
        pub let date: String
        pub let asset: String
        pub let editionId: UInt64
        pub let editionsTotal: UInt64

        init(id: UInt64, name: String, description: String, teams: String, players: String, contentCreator: String, game: String, event: String, date: String, asset: String, editionId: UInt64, editionsTotal: UInt64 ) {
            self.id = id
            self.name = name
            self.description = description
            self.teams = teams
            self.players = players
            self.contentCreator = contentCreator
            self.game = game
            self.event = event
            self.date = date
            self.asset = asset
            self.editionId = editionId
            self.editionsTotal = editionsTotal
        }
    }

    // This is the interface that users can cast their GGItemsCollection Collection as
    // to allow others to deposit GGItemsCollection into their Collection. It also allows for reading
    // the details of GGItemsCollection in the Collection.
    pub resource interface GGItemsCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowGGItem(id: UInt64): &GGItemsCollection.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow GGItem reference: The ID of the returned reference is incorrect"
            }
        }
    }

    // Collection
    // A collection of GGItem NFTs owned by an account
    //
    pub resource Collection: GGItemsCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <-token
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @GGItemsCollection.NFT
            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token
            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT Gets a reference to an NFT in the collection so that the caller can read its metadata and call its methods
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return &self.ownedNFTs[id] as &NonFungibleToken.NFT
        }

        // borrowGGItem Gets a reference to an NFT in the collection as a KittyItem, exposing all of its fields (including the typeID). This is safe as there are no functions that can be called on the KittyItem.
        pub fun borrowGGItem(id: UInt64): &GGItemsCollection.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
                return ref as! &GGItemsCollection.NFT
            } else {
                return nil
            }
        }

        destroy() {
            destroy self.ownedNFTs
        }

        init () {
            self.ownedNFTs <- {}
        }
    }

    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

	pub resource NFTMinter {

		pub fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}, name: String, description: String, teams: String, players: String, contentCreator: String, game: String, event: String, date: String, asset: String, editionId: UInt64, editionsTotal: UInt64) {

            emit Minted(id: GGItemsCollection.totalSupply, name: name, asset: asset)

			// deposit it in the recipient's account using their reference
			recipient.deposit(token: <-create GGItemsCollection.NFT(id: GGItemsCollection.totalSupply, name: name, description: description, teams: teams, players: players, contentCreator: contentCreator, game: game, event: event, date: date, asset: asset, editionId: editionId, editionsTotal: editionsTotal ))

            GGItemsCollection.totalSupply = GGItemsCollection.totalSupply + (1 as UInt64)
		}
	}

    // fetch
    // Get a reference to a GGItem from an account's Collection, if available.
    // If an account does not have a GGItemsCollection.Collection, panic.
    // If it has a collection but does not contain the itemId, return nil.
    // If it has a collection and that collection contains the itemId, return a reference to that.
    //
    pub fun fetch(_ from: Address, itemID: UInt64): &GGItemsCollection.NFT? {
        let collection = getAccount(from)
            .getCapability(GGItemsCollection.CollectionPublicPath)!
            .borrow<&GGItemsCollection.Collection{GGItemsCollection.GGItemsCollectionPublic}>()
            ?? panic("Couldn't get collection")
        // We trust GGItemsCollection.Collection.borowKittyItem to get the correct itemID
        // (it checks it before returning it).
        return collection.borrowGGItem(id: itemID)
    }

	init() {
        // Set our named paths
        self.CollectionStoragePath = /storage/GGItemsCollection001
        self.CollectionPublicPath = /public/GGItemsCollection001
        self.MinterStoragePath = /storage/GGItemsMinter001

        // Initialize the total supply
        self.totalSupply = 0

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)

        emit ContractInitialized()
	}
}
