import FungibleToken from "../../contracts/FungibleToken.cdc"
import GGCoin from "../../contracts/GGCoin.cdc"

pub fun hasGGCoin(_ address: Address): Bool {
    let receiver = getAccount(address)
        .getCapability<&GGCoin.Vault{FungibleToken.Receiver}>(GGCoin.ReceiverPublicPath)
        .check()

    let balance = getAccount(address)
        .getCapability<&GGCoin.Vault{FungibleToken.Balance}>(GGCoin.BalancePublicPath)
        .check()

    return receiver && balance
}

transaction {
    prepare(acct: AuthAccount) {
        if !hasGGCoin(acct.address) {
            if acct.borrow<&GGCoin.Vault>(from: GGCoin.VaultStoragePath) == nil {
                acct.save(<-GGCoin.createEmptyVault(), to: GGCoin.VaultStoragePath)
            }
            acct.unlink(GGCoin.ReceiverPublicPath)
            acct.unlink(GGCoin.BalancePublicPath)
            acct.link<&GGCoin.Vault{FungibleToken.Receiver}>(GGCoin.ReceiverPublicPath, target: GGCoin.VaultStoragePath)
            acct.link<&GGCoin.Vault{FungibleToken.Balance}>(GGCoin.BalancePublicPath, target: GGCoin.VaultStoragePath)
        }
    }
}