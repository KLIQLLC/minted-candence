import GGItemsMarket from "../../contracts/GGItemsMarket.cdc"

pub fun hasGGItemsMarket(_ address: Address): Bool {
    let collection = getAccount(address)
        .getCapability<&GGItemsMarket.Collection{GGItemsMarket.CollectionPublic}>(GGItemsMarket.CollectionPublicPath)
        .check()

    return collection && true
}

transaction {
    prepare(acct: AuthAccount) {
        if !hasGGItemsMarket(acct.address) {
            if acct.borrow<&GGItemsMarket.Collection>(from: GGItemsMarket.CollectionStoragePath) == nil {
                acct.save(<-GGItemsMarket.createEmptyCollection(), to: GGItemsMarket.CollectionStoragePath)
            }
            acct.unlink(GGItemsMarket.CollectionPublicPath)
            acct.link<&GGItemsMarket.Collection{GGItemsMarket.CollectionPublic}>(GGItemsMarket.CollectionPublicPath, target: GGItemsMarket.CollectionStoragePath)
       
        }
    }
}